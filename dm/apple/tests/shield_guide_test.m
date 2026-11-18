#import "../shield_guide_save.h"
#import "../shield_guide_card_backgrounds.h"
#import "../shield_guide_uniforms.h"
#include "../shield_guide_live.h"
#include "../../games/01008DB008C2C000/guide_live_profile.h"
#include <assert.h>
#include <fcntl.h>
#include <unistd.h>

static NSString *snapshotPath;
static NSData *replacementOnRecheck;
static unsigned opensUntilReplacement;

@interface DMGuideSavedContext (LocationTest)
- (void)resolveMap:(uint64_t)map zone:(uint64_t)zone;
@end

static uint64_t primaryObject[12], mirrorRoot[64], mirrorObject[14];
static BOOL tearPair;
static BOOL syntheticHeapRead(uint64_t address, void *out, size_t count) {
    uint64_t *objects[] = {primaryObject, mirrorRoot, mirrorObject};
    size_t lengths[] = {sizeof(primaryObject), sizeof(mirrorRoot), sizeof(mirrorObject)};
    for (NSUInteger i = 0; i < 3; i++) {
        uintptr_t start = (uintptr_t)objects[i];
        if (address < start || count > lengths[i] || address - start > lengths[i] - count) continue;
        memcpy(out, (const void *)(uintptr_t)address, count);
        if (tearPair && address == start + dmShieldLocationPair && i == 0)
            primaryObject[dmShieldLocationPair / 8 + 1] ^= 1;
        return true;
    }
    return false;
}

static void testLiveLocation(void) {
    size_t size = dmShieldLocationRoot + sizeof(uint64_t);
    NSMutableData *image = [NSMutableData dataWithLength:size];
    uint8_t *base = image.mutableBytes;
    *(uint64_t *)(base + dmShieldLocationRoot) = (uintptr_t)primaryObject;
    *(uint64_t *)(base + dmShieldMirrorRoot) = (uintptr_t)mirrorRoot;
    mirrorRoot[dmShieldMirrorPointer / 8] = (uintptr_t)mirrorObject;
    primaryObject[0] = (uintptr_t)base + dmShieldLocationVtable;
    mirrorObject[dmShieldMirrorVtableField / 8] = (uintptr_t)base + dmShieldMirrorVtable;
    uint64_t *pair = &primaryObject[dmShieldLocationPair / 8];
    uint64_t *mirrorZone = &mirrorObject[dmShieldMirrorZone / 8];

    dm_shield_guide_configure_live("unsupported", base, size, syntheticHeapRead);
    assert(!DMGuideLiveLocation.currentLocation);
    dm_shield_guide_configure_live(DM_SHIELD_GUIDE_BUILD, base, size - 1, syntheticHeapRead);
    assert(!DMGuideLiveLocation.currentLocation);
    dm_shield_guide_configure_live(DM_SHIELD_GUIDE_BUILD, base, size, syntheticHeapRead);
    pair[0] = 0x9A3DF7D37DB70B41;
    *mirrorZone = 0x078BC1FF1A657844;
    assert(!DMGuideLiveLocation.currentLocation); // title screen mirror already populated
    pair[1] = *mirrorZone;
    assert(DMGuideLiveLocation.currentLocation.area == DMGuideAreaRoute1);
    pair[1] = 0xE80BCEC03B7D6E23;
    assert(!DMGuideLiveLocation.currentLocation);
    *mirrorZone = pair[1];
    assert(DMGuideLiveLocation.currentLocation.area == DMGuideAreaWedgehurst);
    tearPair = YES;
    assert(!DMGuideLiveLocation.currentLocation);
    tearPair = NO;
    pair[0] = 0x92DABAD379E43890;
    pair[1] = *mirrorZone = 0xE0D6E5E78C91F4A7;
    DMGuideLiveLocation *location = DMGuideLiveLocation.currentLocation;
    assert(location.area == DMGuideAreaMotostoke && location.placementBased);
    assert(!location.wildSubarea);
    pair[0] = 0x5742865396E549D0;
    const uint64_t zones[] = {
        0x776776717EA4483E, 0x776777717EA449F1, 0x776778717EA44BA4, 0x776779717EA44D57,
        0x77677A717EA44F0A, 0x77677B717EA450BD, 0x77676C717EA43740, 0x77676D717EA438F3,
        0x776AFA717EA75E61, 0x776E81717EAA799D, 0x776E7E717EAA7484, 0x7771E5717EAD5960,
        0x7771E8717EAD5E79, 0x7771E7717EAD5CC6, 0x7771EA717EAD61DF, 0x7771E9717EAD602C,
        0x7771EC717EAD6545,
    };
    DMGuideSavedContext *saved = [DMGuideSavedContext new];
    for (NSUInteger i = 0; i < sizeof(zones) / sizeof(zones[0]); i++) {
        pair[1] = zones[i];
        assert(!DMGuideLiveLocation.currentLocation); // The mirror has not caught up.
        *mirrorZone = pair[1];
        DMGuideArea area = i < 9 ? DMGuideAreaWildArea : DMGuideAreaNorthWild;
        NSUInteger index = i < 9 ? i : i - 9;
        NSString *name = [DMShieldGuide wildSubareasInArea:area][index];
        location = DMGuideLiveLocation.currentLocation;
        assert(location.area == area && location.placementBased);
        assert([location.wildSubarea isEqualToNumber:@(index)] && [location.name isEqualToString:name]);
        [saved resolveMap:pair[0] zone:pair[1]];
        assert(saved.area == area && saved.placementBasedLocation);
        assert([saved.wildSubarea isEqualToNumber:@(index)] && [saved.location isEqualToString:name]);
    }
    assert([location.name isEqualToString:@"Lake of Outrage"]);
    [saved resolveMap:0x9A3DF7D37DB70B41 zone:pair[1]];
    assert(saved.area == DMGuideAreaUnknown && !saved.wildSubarea);
    pair[1] = *mirrorZone = 0x776775717EA4468B; // Meetup Spot has no encounter selector entry.
    location = DMGuideLiveLocation.currentLocation;
    assert(location.area == DMGuideAreaWildArea && !location.wildSubarea);
    pair[0] = 0xD08668201CEB598B;
    pair[1] = *mirrorZone = 0xA9AB2DAA935ABA5E;
    location = DMGuideLiveLocation.currentLocation;
    assert(location.area == DMGuideAreaPostwick && [location.name isEqualToString:@"Leon’s room · Postwick"]);
    primaryObject[0]++;
    assert(!DMGuideLiveLocation.currentLocation);
    dm_shield_guide_configure_live("", NULL, 0, NULL);
}
static int openTestSave(void) {
    if (opensUntilReplacement && !--opensUntilReplacement) {
        assert([replacementOnRecheck writeToFile:snapshotPath atomically:YES]);
        replacementOnRecheck = nil;
    }
    return open(snapshotPath.fileSystemRepresentation, O_RDONLY | O_CLOEXEC);
}

static void testActivityEvidence(void) {
    DMGuideSavedContext *save = [DMGuideSavedContext new];
    [save setValue:@{@0x6701AF09: @1, @0x697D1E29: @0} forKey:@"activityWork"];
    assert([save activityEvidenceForKey:@"motostoke.ball-guy"]);
    assert([save activityCompletionForKey:@"motostoke.ball-guy"]);
    assert(![save activityEvidenceForKey:@"motostoke.ball-guy-card"]);
    assert(![save activityEvidenceForKey:@"battle-tower.type-null"]);
    [save setValue:@{@0x6701AF09: @2, @0x697D1E29: @1, @0x0CF6D916: @3} forKey:@"activityWork"];
    assert([save activityEvidenceForKey:@"motostoke.ball-guy"]);
    assert([save activityEvidenceForKey:@"motostoke.ball-guy-card"]);
    assert([save activityEvidenceForKey:@"battle-tower.type-null"]);
    assert([[save activityEvidenceForKey:@"hammerlocke.weather-gifts"] hasSuffix:@"Next lesson is Sandstorm"]);
    assert(![save activityCompletionForKey:@"hammerlocke.weather-gifts"]);
    [save setValue:[NSIndexSet indexSetWithIndex:0xA6BF731D] forKey:@"savedFlags"];
    assert([[save activityEvidenceForKey:@"hammerlocke.weather-gifts"] hasSuffix:@"Bonus visit recorded"]);
    assert(![save activityCompletionForKey:@"hammerlocke.weather-gifts"]);
    [save setValue:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(282, 4)] forKey:@"recordedBagItems"];
    assert(![save activityCompletionForKey:@"hammerlocke.weather-gifts"]);
    [save setValue:@{@1123: @1} forKey:@"heldItemQuantities"];
    assert([save activityCompletionForKey:@"hammerlocke.weather-gifts"]);
    assert(![save activityEvidenceForKey:@"hammerlocke.applin"]);
    [save setValue:[NSIndexSet indexSetWithIndex:632] forKey:@"giftItems"];
    [save setValue:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 400)] forKey:@"galarDexCaught"];
    assert([[save activityEvidenceForKey:@"circhester.shiny-charm"] hasPrefix:@"Galar Pokédex complete"]);
    assert(![save activityCompletionForKey:@"circhester.shiny-charm"]);
    [save setValue:[NSIndexSet indexSetWithIndex:0x813B1361] forKey:@"savedFlags"];
    assert([save activityCompletionForKey:@"circhester.shiny-charm"]);
    [save setValue:@{@0x38548020: @20001} forKey:@"activityWork"];
    [save setValue:[NSIndexSet indexSetWithIndex:407] forKey:@"giftItems"];
    assert([[save activityEvidenceForKey:@"north-wild.rally-volt-switch"] hasSuffix:@"point target reached"]);
    assert(![save activityCompletionForKey:@"north-wild.rally-volt-switch"]);
    [save setValue:[NSIndexSet indexSetWithIndex:0xB2D0CAF5] forKey:@"savedFlags"];
    assert([save activityCompletionForKey:@"north-wild.rally-volt-switch"]);
    NSMutableIndexSet *market = [NSMutableIndexSet indexSetWithIndex:0xD902B576];
    [market addIndex:0x29F6FFF4];
    [save setValue:market forKey:@"savedFlags"];
    assert(![save activityEvidenceForKey:@"stow.buyer"]);
    [save setValue:@YES forKey:@"marketRequestOutstanding"];
    assert(![save activityEvidenceForKey:@"stow.buyer"]);
    [save setValue:@{@0x6C3B5E62: @9} forKey:@"activityWork"];
    assert([[save activityEvidenceForKey:@"stow.buyer"] hasPrefix:@"Buyer request open"]);
    [save setValue:@NO forKey:@"marketRequestOutstanding"];
    assert([[save activityEvidenceForKey:@"stow.buyer"] hasPrefix:@"Sale recorded"]);
    assert([save activityEvidenceForKey:@"stow.bargain"]);
    assert(![save activityCompletionForKey:@"stow.buyer"]);
    assert(![save activityCompletionForKey:@"stow.bargain"]);
}

static void testAutomaticCompletion(void) {
    DMGuideSavedContext *save = [DMGuideSavedContext new];
    NSUInteger observed[] = {0xA6C76681, 0x7F119613, 0x4F18C58F, 0x3E2EF9CC};
    NSMutableIndexSet *flags = [NSMutableIndexSet indexSet];
    for (NSUInteger i = 0; i < sizeof(observed) / sizeof(observed[0]); i++) [flags addIndex:observed[i]];
    [save setValue:flags forKey:@"savedFlags"];
    assert([[save activityCompletionForKey:@"route1.potion"] isEqualToString:@"Collected · recorded in save"]);
    assert([[save activityCompletionForKey:@"wedgehurst.rare-candy"] isEqualToString:@"Collected · estimated from save"]);
    assert(![save activityCompletionForKey:@"wedgehurst.poke-doll"]);
    assert(![save activityCompletionForKey:@"route2.potion"]);
    assert([save activityCompletionForKey:@"stow.trade"]);
    assert(![save activityCompletionForKey:@"hammerlocke.trade"]);
    assert([save activityEvidenceForKey:@"motostoke.battle-cafe"]);
    assert(![save activityEvidenceForKey:@"hammerlocke.cafe"]);
    assert(![save activityCompletionForKey:@"motostoke.battle-cafe"]);
    [save setValue:@1 forKey:@"minccinoStage"];
    assert(![save activityCompletionForKey:@"motostoke.minccino-return"]);
    [save setValue:@2 forKey:@"minccinoStage"];
    assert([save activityCompletionForKey:@"motostoke.minccino-return"]);
    assert(![save activityCompletionForKey:@"motostoke.minccino-reward"]);
    assert(![save activityCompletionForKey:@"motostoke.fountain"]);
    [save setValue:@3 forKey:@"minccinoStage"];
    assert([save activityCompletionForKey:@"motostoke.minccino-reward"]);
    assert(![save activityCompletionForKey:@"motostoke.fountain"]);
    [save setValue:@YES forKey:@"motostokeFountain"];
    assert([save activityCompletionForKey:@"motostoke.fountain"]);
    DMGuideSavedContext *olderSave = [DMGuideSavedContext new];
    assert(![olderSave activityCompletionForKey:@"route1.potion"]);
}

static void testQuestCompletion(void) {
    DMGuideSavedContext *save = [DMGuideSavedContext new];
    for (NSString *key in @[@"hammerlocke.letter", @"ballonlea.letter", @"hammerlocke.letter-return"])
        assert(![save activityCompletionForKey:key]);
    for (NSNumber *stage in @[@0, @1, @5, @100]) {
        [save setValue:@{@0x4584784A: stage} forKey:@"activityWork"];
        for (NSString *key in @[@"hammerlocke.letter", @"ballonlea.letter", @"hammerlocke.letter-return"])
            assert(![save activityCompletionForKey:key]);
    }
    NSArray<NSString *> *deliveries = @[@"hulbury.delivery-station", @"hulbury.delivery-swirlix", @"hulbury.delivery-market"];
    for (NSInteger stage = 0; stage <= 11; stage++) {
        [save setValue:@(stage) forKey:@"hulburyDelivery"];
        for (NSUInteger order = 0; order < deliveries.count; order++) {
            BOOL completed = stage >= 4 + 3 * (NSInteger)order && stage <= 10;
            assert(!![save activityCompletionForKey:deliveries[order]] == completed);
        }
    }
    [save setValue:@3 forKey:@"hulburyDelivery"];
    assert(![save activityCompletionForKey:deliveries[0]]);

    [save setValue:@{@0x4584784A: @2, @0xAF0E8346: @4, @0x4C54B0CF: @10, @0x0E85795E: @3, @0x67A659C4: @1,
                     @0x0D987D50: @4, @0x355C8314: @31, @0x38548020: @0, @0x0123EA7A: @1}
            forKey:@"activityWork"];
    assert([save activityCompletionForKey:@"hammerlocke.letter"]);
    for (NSString *key in @[@"ballonlea.letter", @"hammerlocke.letter-return", @"circhester.detective",
                            @"motostoke.marnie-smile", @"wedgehurst.birthday", @"north-wild.rally", @"north-wild.digging-duo",
                            @"turffield.riddle", @"ballonlea.fire-outfit"])
        assert(![save activityCompletionForKey:key]);

    [save setValue:@{@0x4584784A: @3, @0xAF0E8346: @5, @0x4C54B0CF: @20, @0x0D987D50: @2, @0x0E85795E: @4, @0x67A659C4: @2,
                     @0x355C8314: @29, @0x38548020: @250, @0x066F38F5: @1} forKey:@"activityWork"];
    for (NSString *key in @[@"ballonlea.letter", @"circhester.detective", @"motostoke.marnie-smile",
                            @"wedgehurst.birthday", @"north-wild.rally", @"north-wild.digging-duo",
                            @"turffield.riddle", @"ballonlea.fire-outfit"])
        assert([save activityCompletionForKey:key]);
    assert(![save activityCompletionForKey:@"hammerlocke.letter-return"]);

    [save setValue:@{@0x4584784A: @4, @0xA0F49CFB: @1} forKey:@"activityWork"];
    assert([save activityCompletionForKey:@"ballonlea.letter"]);
    assert([save activityCompletionForKey:@"hammerlocke.letter-return"]);
    assert([save activityCompletionForKey:@"north-wild.digging-duo"]);
    assert(![save activityCompletionForKey:@"wedgehurst.birthday"]);
    assert(![save activityCompletionForKey:@"north-wild.rally"]);

    NSMutableIndexSet *flags = [NSMutableIndexSet indexSetWithIndex:0x87C05A15];
    [flags addIndex:0xBF9C3942];
    [flags addIndex:0x92269668];
    [flags addIndex:0x9D95E9CA];
    [save setValue:flags forKey:@"savedFlags"];
    assert([save activityCompletionForKey:@"spikemuth.marnie"]);
    assert([save activityCompletionForKey:@"circhester.morimoto"]);
    assert(![save activityCompletionForKey:@"spikemuth.marnie-daily"]);
    assert(![save activityCompletionForKey:@"circhester.morimoto-rematch"]);
    assert([save activityCompletionForKey:@"wild-area.lets-go-pikachu"]);
    assert(![save activityCompletionForKey:@"wild-area.lets-go-eevee"]);
    assert([save activityEvidenceForKey:@"turffield.loto-id"]);
    assert(![save activityCompletionForKey:@"turffield.loto-id"]);
    [flags addIndex:0x855235FF];
    [save setValue:flags forKey:@"savedFlags"];
    assert([save activityCompletionForKey:@"wild-area.lets-go-eevee"]);

    [save setValue:[NSIndexSet indexSetWithIndex:43] forKey:@"positiveActivityRecords"];
    [save setValue:@1 forKey:@"raidBattles"];
    assert([[save activityCompletionForKey:@"wild-area.raid-battle"] isEqualToString:@"1 Max Raid battle recorded"]);
    for (NSString *key in @[@"wild-area.first-raid", @"route6.fossil-revival", @"motostoke.poke-jobs", @"battle-tower.first-win"])
        assert(![save activityCompletionForKey:key]);
    NSMutableIndexSet *records = [NSMutableIndexSet indexSetWithIndex:3];
    [records addIndex:15];
    [records addIndex:35];
    [records addIndex:48];
    [save setValue:records forKey:@"positiveActivityRecords"];
    [save setValue:@2 forKey:@"raidCaptures"];
    assert([[save activityCompletionForKey:@"wild-area.first-raid"] isEqualToString:@"2 Max Raid catches recorded"]);
    for (NSString *key in @[@"wild-area.first-raid", @"route6.fossil-revival", @"motostoke.poke-jobs", @"battle-tower.first-win"])
        assert([save activityCompletionForKey:key]);

    [save setValue:[NSIndexSet indexSetWithIndex:39] forKey:@"positiveActivityRecords"];
    assert(![save activityCompletionForKey:@"wild-area.first-berries"]);
    [save setValue:[NSIndexSet indexSetWithIndex:40] forKey:@"positiveActivityRecords"];
    assert([save activityCompletionForKey:@"wild-area.first-berries"]);

    flags = [NSMutableIndexSet indexSetWithIndex:0xC5244701];
    [flags addIndex:0x178159E5];
    [save setValue:flags forKey:@"savedFlags"];
    [save setValue:@{@0x15E9A7B6: @1, @0x26FE3CCB: @2} forKey:@"activityWork"];
    assert(![save activityCompletionForKey:@"wyndon.champion-tournament"]);
    assert([save activityEvidenceForKey:@"wyndon.tournament-reward"]);
    assert(![save activityCompletionForKey:@"wyndon.tournament-reward"]);
    assert(![save activityCompletionForKey:@"postwick.charmander"]);
    [save setValue:@{@0x26FE3E7E: @1} forKey:@"activityWork"];
    assert([save activityCompletionForKey:@"wyndon.champion-tournament"]);
    [flags addIndex:0x4DBE8A87];
    [save setValue:flags forKey:@"savedFlags"];
    assert([save activityCompletionForKey:@"postwick.charmander"]);
    [flags removeIndex:0x178159E5];
    [save setValue:flags forKey:@"savedFlags"];
    assert(![save activityCompletionForKey:@"postwick.charmander"]);
}

static void testPickupArchives(const char *before, const char *after, const char *resaved, const char *arrival) {
    DMGuideSavedContext *beforeSave = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:@(before)]];
    assert(beforeSave && ![beforeSave activityCompletionForKey:@"route1.potion"]);
    for (NSString *path in @[@(after), @(resaved)]) {
        DMGuideSavedContext *save = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:path]];
        assert([[save activityCompletionForKey:@"route1.potion"] isEqualToString:@"Collected · recorded in save"]);
        assert(![save activityCompletionForKey:@"route1.paralyze-heals"]);
        assert(![save activityCompletionForKey:@"route2.potion"]);
    }
    DMGuideSavedContext *arrivalSave = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:@(arrival)]];
    assert([[arrivalSave activityCompletionForKey:@"route1.potion"] isEqualToString:@"Collected · recorded in save"]);
    assert([[arrivalSave activityCompletionForKey:@"route1.paralyze-heals"] isEqualToString:@"Collected · recorded in save"]);
    puts("PASS: object-specific Route 1 completion across four archived saves");
}

static void testQuestArchive(const char *archive, const char *fixture) {
    NSArray<NSString *> *completed = @[@"wild-area.first-raid", @"route6.fossil-revival", @"motostoke.poke-jobs",
        @"battle-tower.first-win", @"hulbury.delivery-station", @"hulbury.delivery-swirlix", @"motostoke.marnie-smile",
        @"wild-area.first-berries", @"wyndon.champion-tournament"];
    DMGuideSavedContext *before = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:@(archive)]];
    DMGuideSavedContext *after = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:@(fixture)]];
    assert(before && after);
    for (NSString *key in completed) {
        assert(![before activityCompletionForKey:key]);
        assert([after activityCompletionForKey:key]);
    }
    assert(![after activityCompletionForKey:@"hulbury.delivery-market"]);
    puts("PASS: archived save and synthetic quest outcomes through the decoder");
}

static void testWildBattles(const char *fixtureDirectory) {
    NSString *directory = @(fixtureDirectory);
    NSString *chloe = @"wild-area.chloe", *battle = @"wild-area.raid-battle", *clear = @"wild-area.first-raid";
    NSArray<NSArray<NSString *> *> *cases = @[
        @[@"opening", @"Opening team · Lv. 13 Grookey, Scorbunny and Sobble", @"", @""],
        @[@"fire", @"Fire Badge team · Lv. 30 Raboot, Drizzile and Thwackey", @"3 Max Raid battles recorded", @""],
        @[@"champion", @"Champion team · Lv. 60 Inteleon, Rillaboom and Cinderace", @"4 Max Raid battles recorded", @"1 Max Raid catch recorded"],
        @[@"older", @"Opening team · Lv. 13 Grookey, Scorbunny and Sobble", @"", @""],
    ];
    for (NSArray<NSString *> *entry in cases) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:entry[0]]];
        DMGuideSavedContext *saved = [DMGuideSavedContext decode:data];
        assert(saved);
        assert([[saved activityEvidenceForKey:chloe] isEqualToString:entry[1]]);
        assert(![saved activityCompletionForKey:chloe]);
        assert([([saved activityCompletionForKey:battle] ?: @"") isEqualToString:entry[2]]);
        assert([([saved activityCompletionForKey:clear] ?: @"") isEqualToString:entry[3]]);
    }
    puts("PASS: independent raid battle and catch counts, Chloe’s badge and Champion teams, and an older save");
}

static void testFossilRecipes(const char *fixtureDirectory) {
    NSString *directory = @(fixtureDirectory);
    NSString *dracozolt = @"route6.fossil.dracozolt", *arctozolt = @"route6.fossil.arctozolt";
    NSString *dracovish = @"route6.fossil.dracovish", *arctovish = @"route6.fossil.arctovish";
    NSString *gift = @"stow.fossils", *revival = @"route6.fossil-revival";
    for (NSString *fixture in @[@"items-only", @"ready", @"revived", @"traded-away"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *saved = [DMGuideSavedContext decode:data];
        assert(saved);
        BOOL restored = [fixture isEqualToString:@"revived"];
        BOOL tradedAway = [fixture isEqualToString:@"traded-away"];
        assert(!![saved activityCompletionForKey:revival] == (restored || tradedAway));
        assert(!![saved activityCompletionForKey:gift] == [fixture isEqualToString:@"ready"]);
        assert(![saved activityCompletionForKey:dracovish] && ![saved activityCompletionForKey:arctovish]);
        if (restored || tradedAway) {
            assert([[saved activityCompletionForKey:arctozolt] isEqualToString:@"Registered in your Galar Pokédex"]);
            assert([[saved activityCompletionForKey:dracozolt] isEqualToString:
                restored ? @"Route 6 revival in your collection" : @"Registered in your Galar Pokédex"]);
        } else {
            assert(![saved activityCompletionForKey:dracozolt] && ![saved activityCompletionForKey:arctozolt]);
            assert([[saved activityEvidenceForKey:dracozolt] hasPrefix:@"Enough for this recipe"]);
            assert([[saved activityEvidenceForKey:arctozolt] hasSuffix:@"Fossilized Dino ×0"]);
            if ([fixture isEqualToString:@"ready"])
                assert([[saved activityEvidenceForKey:dracovish] hasPrefix:@"Enough for this recipe"]);
            else
                assert([[saved activityEvidenceForKey:dracovish] hasPrefix:@"In your Bag · Fossilized Fish ×0"]);
        }
    }
    puts("PASS: four fossil recipes, Bag quantities, held gift pieces, revival provenance and persistent dex registration");
}

static void testStationAndBallGifts(const char *fixtureDirectory) {
    NSString *directory = @(fixtureDirectory);
    NSString *dolls = @"wild-area.poke-dolls", *master = @"postwick.master-ball", *beast = @"stow.beast-ball";
    NSString *applin = @"hammerlocke.applin";
    for (NSString *fixture in @[@"items-only", @"partial", @"owned", @"used"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *saved = [DMGuideSavedContext decode:data];
        assert(saved);
        BOOL owned = [fixture isEqualToString:@"owned"], used = [fixture isEqualToString:@"used"];
        BOOL pastBeastBall = [fixture isEqualToString:@"partial"];
        assert(!![saved activityCompletionForKey:dolls] == owned);
        assert(!![saved activityCompletionForKey:master] == (owned || used));
        assert(!![saved activityCompletionForKey:beast] == (owned || used || pastBeastBall));
        if (pastBeastBall)
            assert([[saved activityCompletionForKey:beast] hasPrefix:@"Past Beast Ball recorded in Bag"]);
        NSString *applinStatus = [saved activityEvidenceForKey:applin];
        assert(![saved activityCompletionForKey:applin]);
        if ([fixture isEqualToString:@"items-only"])
            assert([applinStatus isEqualToString:@"Party slot 1 · Applin available"]);
        else if (owned)
            assert([applinStatus isEqualToString:@"Box 2, slot 2 · Applin available"]);
        else
            assert(!applinStatus);
        if (used) {
            assert([[saved activityCompletionForKey:master] hasPrefix:@"Master Ball catch"]);
            assert([[saved activityCompletionForKey:beast] hasPrefix:@"Beast Ball catch"]);
        }
    }
    puts("PASS: gift visits, counted and held items, ball use, provenance controls and Applin slot readiness");
}

static void testCampsiteProgress(const char *fixtureDirectory) {
    NSString *directory = @(fixtureDirectory);
    NSString *potion = @"wedgehurst.lab-potion", *berry = @"route3.berry-gift";
    for (NSString *fixture in @[@"inside-lab", @"after-exit", @"center", @"send-off", @"route2",
                                @"items-only", @"gift-only", @"alternating", @"gift-and-stops"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *saved = [DMGuideSavedContext decode:data];
        assert(saved);
        BOOL potionExpected = [@[@"after-exit", @"center", @"send-off", @"route2"] containsObject:fixture];
        BOOL allStops = [fixture isEqualToString:@"gift-and-stops"];
        BOOL alternating = [fixture isEqualToString:@"alternating"];
        assert(!![saved activityCompletionForKey:potion] == potionExpected);
        assert(!![saved activityCompletionForKey:berry] == (allStops || alternating || [fixture isEqualToString:@"gift-only"]));
        if (alternating)
            assert([[saved activityCompletionForKey:berry] containsString:@"past Bag entry recorded"]);
        for (NSUInteger route = 3; route <= 10; route++) {
            NSString *key = [NSString stringWithFormat:@"route%lu.campsite-taxi", route];
            BOOL expected = allStops || (alternating && route % 2 == 0);
            assert(!![saved activityCompletionForKey:key] == expected);
        }
    }
    puts("PASS: archived Wedgehurst Potion transition, eight campsite flags and Route 3 gift independence");
}

static void testLeagueCards(const char *fixtureDirectory) {
    NSArray<NSString *> *keys = @[
        @"motostoke.hop-card", @"weald.hop-rare-card", @"ballonlea.marnie-card", @"spikemuth.marnie-rare-card",
        @"turffield.milo-card", @"turffield.milo-rare-card", @"hulbury.nessa-card", @"hulbury.nessa-rare-card",
        @"motostoke.kabu-card", @"motostoke.kabu-rare-card", @"", @"",
        @"stow.allister-card", @"stow.allister-rare-card", @"route6.opal-card", @"ballonlea.opal-rare-card",
        @"", @"", @"circhester.melony-card", @"circhester.melony-rare-card", @"spikemuth.piers-card",
        @"power-plant.piers-rare-card", @"hammerlocke.raihan-card", @"hammerlocke.raihan-rare-card",
        @"motostoke.leon-card", @"battle-tower.leon-card", @"hulbury.rose-card", @"galar-mine.rose-card",
        @"mine2.bede-card", @"ballonlea.bede-rare-card", @"motostoke.ball-guy-card"
    ];
    NSString *directory = @(fixtureDirectory);
    for (NSUInteger slot = 0; slot < keys.count; slot++) {
        NSString *file = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"slot-%lu", slot]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:file]];
        assert(save);
        NSString *expectedTitle = keys[slot].length ? @"League Card album · 1 of 27 owned" : @"League Card album · 0 of 27 owned";
        assert([[DMGuideSavedContext leagueCardAlbumTitleWithSavedContext:save] isEqualToString:expectedTitle]);
        for (NSUInteger index = 0; index < keys.count; index++)
            assert(!![save activityCompletionForKey:keys[index]] == (index == slot && keys[index].length));
        assert(![save activityCompletionForKey:@"spikemuth.marnie"]);
    }
    DMGuideSavedContext *full = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:
        [directory stringByAppendingPathComponent:@"full"]]];
    assert(full);
    assert([[DMGuideSavedContext leagueCardAlbumTitleWithSavedContext:full] isEqualToString:@"League Card album · 27 of 27 owned"]);
    NSArray<NSString *> *rows = [DMGuideSavedContext leagueCardAlbumRowsWithSavedContext:full];
    assert(rows.count == 27);
    for (NSString *row in rows) assert([row containsString:@" · Owned\n"]);
    DMGuideSavedContext *battle = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:
        [directory stringByAppendingPathComponent:@"battle-only"]]];
    assert([battle activityCompletionForKey:@"spikemuth.marnie"]);
    assert(![battle activityCompletionForKey:@"spikemuth.marnie-rare-card"]);
    NSArray<NSString *> *offlineRows = [DMGuideSavedContext leagueCardAlbumRowsWithSavedContext:nil];
    assert(offlineRows.count == 27 && [offlineRows.firstObject hasPrefix:@"Hop’s League Card\nMotostoke"]);
    assert([[DMGuideSavedContext leagueCardAlbumTitleWithSavedContext:nil] isEqualToString:@"League Card album"]);
    puts("PASS: all 31 album controls, Shield’s 27 card slots, and independent rematch and card records");
}

static void testPostgameProgress(const char *fixtureDirectory) {
    NSArray<NSString *> *keys = @[@"turffield.postgame-stadium", @"hulbury.postgame-stadium", @"motostoke.postgame-stadium",
        @"hammerlocke.postgame-stadium", @"stow.postgame-stadium", @"ballonlea.postgame-stadium", @"circhester.postgame-stadium"];
    NSString *epilogue = @"weald.postgame-epilogue", *eternatus = @"power-plant.eternatus", *zamazenta = @"power-plant.zamazenta";
    NSString *directory = @(fixtureDirectory);
    for (NSString *fixture in @[@"counter-and-cards", @"in-progress", @"resolved", @"restored"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL resolved = [fixture isEqualToString:@"resolved"];
        BOOL inProgress = [fixture isEqualToString:@"in-progress"];
        for (NSUInteger index = 0; index < keys.count; index++)
            assert(!![save activityCompletionForKey:keys[index]] == (resolved || (inProgress && index == 1)));
        NSUInteger count = resolved ? 7 : inProgress ? 1 : 0;
        NSString *expectedTitle = [NSString stringWithFormat:@"Postgame stadiums · %lu of 7 recorded", count];
        assert([[DMGuideSavedContext postgameStadiumTitleWithSavedContext:save] isEqualToString:expectedTitle]);
        assert([DMGuideSavedContext postgameStadiumRowsWithSavedContext:save].count == 7);
        assert(!![save activityCompletionForKey:epilogue] == resolved);
        if (inProgress) {
            assert([[save activityEvidenceForKey:keys[0]] isEqualToString:@"Finish the stadium debrief"]);
            assert([[save activityEvidenceForKey:keys[2]] isEqualToString:@"Incident ready"]);
            assert(![save activityEvidenceForKey:keys[3]]);
        }
        if (resolved) {
            assert([[save activityCompletionForKey:eternatus] hasPrefix:@"Your Energy Plant Eternatus"]);
            assert([[save activityCompletionForKey:zamazenta] hasPrefix:@"Your Energy Plant Zamazenta"]);
        } else if ([fixture isEqualToString:@"restored"]) {
            assert([[save activityEvidenceForKey:keys[0]] isEqualToString:@"Incident ready"]);
            assert([[save activityCompletionForKey:eternatus] isEqualToString:@"Registered in your Galar Pokédex"]);
            assert([[save activityCompletionForKey:zamazenta] isEqualToString:@"Registered in your Galar Pokédex"]);
        } else {
            assert(![save activityCompletionForKey:eternatus] && ![save activityCompletionForKey:zamazenta]);
        }
    }
    assert([[DMGuideSavedContext postgameStadiumTitleWithSavedContext:nil] isEqualToString:@"Postgame stadiums"]);
    assert([DMGuideSavedContext postgameStadiumRowsWithSavedContext:nil].count == 7);
    puts("PASS: exact stadium records, debrief and replay controls, legendary provenance, and independent epilogue");
}

static void testBoutiqueStock(const char *fixtureDirectory) {
    DMGuideArea shops[] = {DMGuideAreaWedgehurst, DMGuideAreaMotostoke, DMGuideAreaHammerlocke, DMGuideAreaCirchester, DMGuideAreaWyndon};
    assert([[DMGuideSavedContext boutiqueTitleInArea:DMGuideAreaWedgehurst savedContext:nil] isEqualToString:@"Boutique"]);
    assert(![DMGuideSavedContext boutiqueTitleInArea:DMGuideAreaRoute2 savedContext:nil]);
    for (NSString *fixture in @[@"base", @"style-card", @"wrong-pocket", @"other-avatar", @"other-avatar-all", @"restored"]) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL style = [fixture isEqualToString:@"style-card"];
        BOOL otherAvatar = [fixture hasPrefix:@"other-avatar"];
        BOOL all = [fixture isEqualToString:@"other-avatar-all"];
        BOOL restored = [fixture isEqualToString:@"restored"];
        NSUInteger avatar0Total[] = {144, 98, 80, 60, 110}, styleTotal[] = {148, 105, 84, 89, 159};
        NSUInteger avatar1Total[] = {174, 99, 107, 93, 137}, allTotal[] = {186, 109, 115, 114, 180};
        const NSUInteger *totals = all ? allTotal : otherAvatar ? avatar1Total : style ? styleTotal : avatar0Total;
        for (NSUInteger shop = 0; shop < sizeof(shops) / sizeof(shops[0]); shop++) {
            NSUInteger owned = all ? totals[shop] : 0;
            if (!restored && !otherAvatar && shop == 0) owned = style ? 3 : 2;
            if (!restored && !otherAvatar && shop == 1) owned = 1;
            NSString *title = [NSString stringWithFormat:@"Boutique · %lu of %lu owned", owned, totals[shop]];
            assert([[DMGuideSavedContext boutiqueTitleInArea:shops[shop] savedContext:save] isEqualToString:title]);
            NSMutableArray<NSString *> *rows = [NSMutableArray array];
            for (DMGuideBoutiqueCategory *category in [DMGuideSavedContext boutiqueCategoriesInArea:shops[shop] savedContext:save])
                [rows addObjectsFromArray:category.items];
            assert(rows.count == totals[shop]);
            assert([NSSet setWithArray:rows].count == rows.count);
            NSUInteger available = 0;
            for (NSString *row in rows) available += [row hasSuffix:@" · Owned"];
            assert(available == owned);
            if (shop == 0 && !otherAvatar) {
                assert([rows containsObject:@"Sport Cap · Stuff Cheeks · Owned"] == style);
                assert([rows containsObject:@"Loose Top · Black · Owned"] == !restored);
                assert([rows containsObject:@"Striped Top · Black · Owned"] == !restored);
                assert([rows containsObject:@"Loose Top · Black · 990 Pokédollars"] == restored);
            }
        }
    }
    puts("PASS: five boutique inventories, distinct pieces and colors, prices, both avatars, Style Card and restore");
}

static void testTMReference(void) {
    NSArray<NSString *> *rows = [DMGuideSavedContext tmRowsInArea:DMGuideAreaUnknown savedContext:nil];
    assert(rows.count == 100);
    assert([[DMGuideSavedContext tmTitleInArea:DMGuideAreaUnknown savedContext:nil] isEqualToString:@"TM case"]);
    assert(![DMGuideSavedContext tmTitleInArea:DMGuideAreaPostwick savedContext:nil]);
    assert(![DMGuideSavedContext tmRowsInArea:DMGuideAreaPostwick savedContext:nil].count);
    NSUInteger shopRows = 0, localRows = 0;
    for (NSUInteger number = 0; number < rows.count; number++) {
        NSString *prefix = [NSString stringWithFormat:@"TM%02lu ", number];
        assert([rows[number] hasPrefix:prefix]);
        assert(![rows[number] containsString:@" · Owned"] && ![rows[number] containsString:@" · Missing"]);
        shopRows += [rows[number] containsString:@" Pokédollars"];
    }
    assert(shopRows == 45);
    for (NSUInteger area = 0; area < DMShieldGuide.areaNames.count; area++)
        localRows += [DMGuideSavedContext tmRowsInArea:(DMGuideArea)area savedContext:nil].count;
    assert(localRows == 100);
    NSArray<NSString *> *hammerlocke = [DMGuideSavedContext tmRowsInArea:DMGuideAreaHammerlocke savedContext:nil];
    assert(hammerlocke.count == 20);
    assert([hammerlocke[0] hasPrefix:@"TM00 Mega Punch"]);
    assert([hammerlocke[0] containsString:@"east Pokémon Center after defeating Opal"]);
    assert([hammerlocke[2] containsString:@"west Pokémon Center"]);
    assert([rows[20] containsString:@"after becoming Champion"]);
    puts("PASS: TM00–TM99 reference, town placement, 45 prices and acquisition gates");
}

static void testTMCase(const char *fixtureDirectory) {
    NSMutableIndexSet *expectedPartial = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 3)];
    [expectedPartial addIndex:4];
    [expectedPartial addIndexesInRange:NSMakeRange(92, 5)];
    [expectedPartial addIndex:99];
    for (NSString *fixture in @[@"partial", @"all", @"restored", @"no-bag"]) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL all = [fixture isEqualToString:@"all"];
        BOOL selected = [fixture isEqualToString:@"partial"];
        BOOL known = ![fixture isEqualToString:@"no-bag"];
        NSUInteger count = all ? 100 : selected ? expectedPartial.count : 0;
        NSString *title = known ? [NSString stringWithFormat:@"TM case · %lu of 100 owned", count] : @"TM case";
        assert([[DMGuideSavedContext tmTitleInArea:DMGuideAreaUnknown savedContext:save] isEqualToString:title]);
        NSArray<NSString *> *rows = [DMGuideSavedContext tmRowsInArea:DMGuideAreaUnknown savedContext:save];
        assert(rows.count == 100);
        for (NSUInteger number = 0; number < rows.count; number++) {
            BOOL owned = all || (selected && [expectedPartial containsIndex:number]);
            assert([rows[number] containsString:@" · Owned"] == (known && owned));
            assert([rows[number] containsString:@" · Missing"] == (known && !owned));
        }
        NSString *motostoke = known ?
            [NSString stringWithFormat:@"Local TMs · %d of 9 owned", all ? 9 : selected ? 2 : 0] : @"Local TMs";
        assert([[DMGuideSavedContext tmTitleInArea:DMGuideAreaMotostoke savedContext:save] isEqualToString:motostoke]);
        assert(![save activityCompletionForKey:@"motostoke.pay-day"]);
    }
    puts("PASS: TM Bag boundaries, invalid pockets, TRs, zero quantity, duplicates, missing Bag and restore");
}

static void testTRReference(void) {
    assert([[DMGuideSavedContext trTitleWithSavedContext:nil] isEqualToString:@"Technical Records"]);
    NSArray<NSString *> *rows = [DMGuideSavedContext trRowsWithSavedContext:nil];
    assert(rows.count == 100);
    for (NSUInteger number = 0; number < rows.count; number++) {
        NSString *prefix = [NSString stringWithFormat:@"TR%02lu ", number];
        assert([rows[number] hasPrefix:prefix] && [rows[number] hasSuffix:@" W"]);
    }
    assert([rows[5] hasPrefix:@"TR05 Ice Beam · Ice"]);
    assert([rows[99] hasPrefix:@"TR99 Body Press · Fighting"]);
    assert([[DMGuideSavedContext trSourcesInArea:DMGuideAreaWildArea] containsString:@"Meetup Spot"]);
    assert([[DMGuideSavedContext trSourcesInArea:DMGuideAreaNorthWild] containsString:@"Bridge Field Nursery"]);
    assert(![DMGuideSavedContext trSourcesInArea:DMGuideAreaRoute2]);
    puts("PASS: TR00–TR99 reference, move types, Watt prices and local trader stops");
}

static void testTRInventory(const char *fixtureDirectory) {
    for (NSString *fixture in @[@"stocked", @"spent", @"all", @"restored", @"no-bag"]) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL stocked = [fixture isEqualToString:@"stocked"];
        BOOL spent = [fixture isEqualToString:@"spent"];
        BOOL all = [fixture isEqualToString:@"all"];
        BOOL known = ![fixture isEqualToString:@"no-bag"];
        NSString *title = known ? [NSString stringWithFormat:@"Technical Records · %d of 100 obtained",
            all ? 100 : (stocked || spent) ? 4 : 0] : @"Technical Records";
        assert([[DMGuideSavedContext trTitleWithSavedContext:save] isEqualToString:title]);
        NSArray<NSString *> *rows = [DMGuideSavedContext trRowsWithSavedContext:save];
        for (NSUInteger number = 0; number < rows.count; number++) {
            NSUInteger quantity = all ? 1 : 0;
            if (number == 0 && (stocked || spent)) quantity = 7;
            if (number == 13 && stocked) quantity = 1;
            if (number == 99 && (stocked || spent)) quantity = 9;
            NSString *suffix = known ? [NSString stringWithFormat:@" · %lu in Bag", quantity] : @" W";
            if (((stocked || spent) && number == 2) || (spent && number == 13))
                suffix = [suffix stringByAppendingString:@" · Previously obtained"];
            assert([rows[number] hasSuffix:suffix]);
        }
        assert(![save activityCompletionForKey:@"motostoke.focus-energy"]);
    }
    puts("PASS: TR quantities and acquisition records, use of a copy, wrong pockets, duplicate entries and restore");
}

static void testPastRewards(const char *fixtureDirectory) {
    NSArray<NSString *> *gifts = @[@"hammerlocke.soothe-bell", @"hammerlocke.mr-focus", @"ballonlea.eviolite",
        @"motostoke.focus-energy", @"motostoke.star-piece", @"route3.berry-gift"];
    for (NSString *fixture in @[@"past-rewards", @"past-items-only", @"past-flags-only", @"past-wrong-pockets"]) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL complete = [fixture isEqualToString:@"past-rewards"];
        for (NSString *gift in gifts) {
            NSString *status = [save activityCompletionForKey:gift];
            assert(!!status == complete);
            if (complete) assert([status containsString:@"past Bag entry recorded"]);
        }
        assert(!![save activityCompletionForKey:@"postwick.master-ball"] == complete);
        assert(!![save activityCompletionForKey:@"stow.beast-ball"] == complete);
        assert(!![save activityCompletionForKey:@"hammerlocke.weather-gifts"] == complete);
        assert(![save activityCompletionForKey:@"wild-area.poke-dolls"]);
        assert(![save activityCompletionForKey:@"stow.fossils"]);
        assert(![save activityCompletionForKey:@"stow.fly"]);
        assert([[DMGuideSavedContext tmTitleInArea:DMGuideAreaUnknown savedContext:save] hasSuffix:@"0 of 100 owned"]);
    }
    puts("PASS: saved gift flags plus prior Bag records, wrong pockets, quantity gates and prior items alone");
}

static void testUniformWardrobe(const char *fixtureDirectory) {
    NSString *directory = @(fixtureDirectory);
    assert([DMGuideSavedContext uniformWardrobeRowsWithSavedContext:nil].count == shieldUniformCount);
    assert([[DMGuideSavedContext uniformWardrobeTitleWithSavedContext:nil] isEqualToString:@"Uniform wardrobe"]);
    for (NSUInteger gender = 0; gender < 2; gender++) {
        for (NSUInteger index = 0; index < shieldUniformCount; index++) {
            const ShieldUniform *uniform = &shieldUniforms[index];
            NSString *fixture = [NSString stringWithFormat:@"%lu-%lu", gender, index];
            NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:fixture]];
            DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
            assert(save);
            assert([[DMGuideSavedContext uniformWardrobeTitleWithSavedContext:save]
                isEqualToString:@"Uniform wardrobe · 1 of 22 owned"]);
            assert([save activityCompletionForKey:uniform->key]);
            NSArray<NSString *> *rows = [DMGuideSavedContext uniformWardrobeRowsWithSavedContext:save];
            assert([rows[index] hasPrefix:[uniform->name stringByAppendingString:@" · Owned\n"]]);
            for (NSUInteger other = 0; other < shieldUniformCount; other++) {
                if (other != index) assert(![save activityCompletionForKey:shieldUniforms[other].key]);
            }
        }
    }
    for (NSString *fixture in @[@"partial", @"badge-only", @"restored", @"invalid-avatar", @"salon"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL unknown = [fixture isEqualToString:@"invalid-avatar"];
        NSString *title = unknown ? @"Uniform wardrobe" : @"Uniform wardrobe · 0 of 22 owned";
        assert([[DMGuideSavedContext uniformWardrobeTitleWithSavedContext:save] isEqualToString:title]);
        assert(![save activityCompletionForKey:@"uniform.grass"]);
        assert(!![save activityCompletionForKey:@"fashion.hairstyle"] == [fixture isEqualToString:@"salon"]);
        assert(![save activityCompletionForKey:@"motostoke.card-hairstyles"]);
    }
    puts("PASS: 22 complete uniform presets for both avatars, partial pieces and badge controls, salon and restore");
}

static void testCardMakerOverview(void) {
    NSArray<NSString *> *offline = [DMGuideSavedContext cardMakerRowsWithSavedContext:nil];
    assert(offline.count == 7);
    assert([offline[1] isEqualToString:@"Backgrounds · 66 options"]);
    assert([offline[2] isEqualToString:@"Effects · 20 options"]);
    assert([offline[3] isEqualToString:@"Frames · 20 options"]);
    assert([offline[4] isEqualToString:@"Expressions · 30 options"]);
    assert([offline[5] isEqualToString:@"Poses · 20 options"]);
    assert([offline[6] isEqualToString:@"Coatings · 9 options"]);

    DMGuideSavedContext *save = [DMGuideSavedContext new];
    [save setValue:[NSIndexSet indexSetWithIndex:cardStarterFlag] forKey:@"savedFlags"];
    NSArray<NSString *> *starter = [DMGuideSavedContext cardMakerRowsWithSavedContext:save];
    assert([starter[1] isEqualToString:@"Backgrounds · 9 of 66 available"]);
    assert([starter[2] isEqualToString:@"Effects · 4 of 20 available"]);
    assert([starter[3] isEqualToString:@"Frames · 3 of 20 available"]);
    assert([starter[4] isEqualToString:@"Expressions · 23 of 30 available"]);
    assert([starter[5] isEqualToString:@"Poses · 7 of 20 available"]);
    assert([starter[6] isEqualToString:@"Coatings · 2 of 9 available"]);
    assert(![save activityCompletionForKey:@"turffield.card-badge"]);

    NSMutableIndexSet *flags = [NSMutableIndexSet indexSetWithIndex:cardStarterFlag];
    [flags addIndex:0x299E4801];
    [flags addIndex:0x4DBE8A87];
    [save setValue:flags forKey:@"savedFlags"];
    [save setValue:@30 forKey:@"towerSinglesWins"];
    [save setValue:@100 forKey:@"towerDoublesWins"];
    NSArray<NSString *> *progress = [DMGuideSavedContext cardMakerRowsWithSavedContext:save];
    assert([progress[1] isEqualToString:@"Backgrounds · 16 of 66 available"]);
    assert([progress[2] isEqualToString:@"Effects · 8 of 20 available"]);
    assert([progress[4] isEqualToString:@"Expressions · 30 of 30 available"]);
    assert([progress[6] isEqualToString:@"Coatings · 5 of 9 available"]);
    NSString *grass = [save activityCompletionForKey:@"turffield.card-badge"];
    assert([grass hasSuffix:@"1 effect, 2 frames, 1 pose, 1 coating"]);
    assert(![save activityCompletionForKey:@"weald.card-epilogue-end"]);
    NSArray<DMGuideActivity *> *activities = [DMShieldGuide activitiesInArea:DMGuideAreaTurffield];
    for (DMGuideActivity *activity in activities) {
        if ([activity.key isEqualToString:@"turffield.card-badge"])
            assert([activity.directions containsString:@"Checkered Foil costs 500 Pokédollars"]);
    }
    puts("PASS: Card Maker overview, starter options, combined badge unlocks and coating price");
}

static void testCardBackgrounds(const char *fixtureDirectory) {
    for (NSUInteger index = 0; index < sizeof(shieldCardBackgrounds) / sizeof(shieldCardBackgrounds[0]); index++) {
        const ShieldCardBackground *background = &shieldCardBackgrounds[index];
        NSString *fixture = [NSString stringWithFormat:@"flag-%08X", background->flag];
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        NSString *label = [save activityCompletionForKey:background->key];
        assert(label.integerValue == background->count);
        for (NSUInteger other = 0; other < sizeof(shieldCardBackgrounds) / sizeof(shieldCardBackgrounds[0]); other++) {
            if (other != index) assert(![save activityCompletionForKey:shieldCardBackgrounds[other].key]);
        }
    }
    NSDictionary<NSString *, NSArray<NSNumber *> *> *unlockedRecords = @{
        @"below-targets": @[], @"card-designs": @[@45], @"salon-and-money": @[@44, @46],
        @"wild-area": @[@42, @43], @"restored": @[],
    };
    for (NSString *fixture in unlockedRecords) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        for (NSUInteger index = 0; index < sizeof(shieldCardBackgroundTargets) / sizeof(shieldCardBackgroundTargets[0]); index++) {
            const ShieldCardBackgroundTarget *target = &shieldCardBackgroundTargets[index];
            BOOL unlocked = [unlockedRecords[fixture] containsObject:@(target->record)];
            assert(!![save activityCompletionForKey:target->key] == unlocked);
            BOOL countValid = target->record != 45 || ![fixture isEqualToString:@"restored"];
            assert(!![save activityEvidenceForKey:target->key] == (countValid && !unlocked));
        }
        if ([fixture isEqualToString:@"below-targets"]) {
            assert([[save activityEvidenceForKey:@"motostoke.card-creator"] isEqualToString:@"9 of 10"]);
            assert([[save activityEvidenceForKey:@"wild-area.card-curry"] isEqualToString:@"14 of 15"]);
        }
    }
    puts("PASS: individual Card Maker flag gates and five counter thresholds");
}

static void testNurseries(const char *fixtureDirectory) {
    NSString *route = @"route5.nursery-deposit", *bridge = @"north-wild.nursery-deposit", *hatch = @"nursery.hatch-egg";
    NSString *charm = @"circhester.oval-charm", *routeTaxi = @"route5.nursery-taxi", *bridgeTaxi = @"north-wild.nursery-taxi";
    for (NSString *fixture in @[@"route-pair", @"bridge-pair", @"claim", @"restored", @"invalid"]) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL routePair = [fixture isEqualToString:@"route-pair"];
        BOOL bridgePair = [fixture isEqualToString:@"bridge-pair"];
        BOOL claimed = [fixture isEqualToString:@"claim"];
        assert(!![save activityCompletionForKey:route] == routePair);
        assert(!![save activityCompletionForKey:bridge] == bridgePair);
        assert(!![save activityCompletionForKey:routeTaxi] == (routePair || claimed));
        assert(!![save activityCompletionForKey:bridgeTaxi] == bridgePair);
        assert(!![save activityCompletionForKey:charm] == claimed);
        assert(!![save activityCompletionForKey:@"circhester.morimoto"] == (routePair || claimed));
        if (routePair) {
            assert([[save activityCompletionForKey:route] isEqualToString:@"2 Pokémon at the Nursery · Egg ready to collect"]);
            assert([[save activityEvidenceForKey:bridge] isEqualToString:@"1 of 2 Pokémon at the Nursery"]);
        } else if (bridgePair) {
            assert([[save activityCompletionForKey:bridge] isEqualToString:@"2 Pokémon at the Nursery"]);
            assert([[save activityEvidenceForKey:route] isEqualToString:@"Egg ready to collect"]);
        } else {
            assert(![save activityEvidenceForKey:route] && ![save activityEvidenceForKey:bridge]);
        }
        NSString *hatched = [save activityCompletionForKey:hatch];
        if (bridgePair) assert([hatched isEqualToString:@"1 Egg hatched"]);
        else if (claimed) assert([hatched isEqualToString:@"7 Eggs hatched"]);
        else assert(!hatched);
    }
    puts("PASS: independent Nursery deposits, waiting Eggs and Taxi stops, hatch counts, Oval Charm, and restore");
}

static void testRotomBikeUnlocks(const char *fixtureDirectory) {
    NSString *bike = @"route5.rotom-bike", *water = @"route9.bike-water-mode", *outfit = @"wild-area.bike-outfit";
    NSPredicate *psychoCut = [NSPredicate predicateWithFormat:@"key == %@", @"route2.psycho-cut"];
    DMGuideActivity *detour = [[DMShieldGuide activitiesInArea:DMGuideAreaRoute2] filteredArrayUsingPredicate:psychoCut].firstObject;
    assert(detour.waterModeHint.length && ![detour.hint isEqualToString:detour.waterModeHint]);
    for (NSString *fixture in @[@"phase-only", @"flag-only", @"land", @"water-item", @"water-mode", @"default-outfit", @"restored"]) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL land = [fixture isEqualToString:@"land"], waterMode = [fixture isEqualToString:@"water-mode"];
        BOOL upgraded = waterMode || [fixture isEqualToString:@"default-outfit"];
        BOOL ownsBike = land || upgraded || [fixture isEqualToString:@"water-item"];
        assert(!![save activityCompletionForKey:bike] == ownsBike);
        assert(!![save activityCompletionForKey:water] == upgraded);
        assert(!![save activityCompletionForKey:@"mine2.mud-shot"] == [fixture isEqualToString:@"default-outfit"]);
        assert([[save hintForActivity:detour] isEqualToString:upgraded ? detour.waterModeHint : detour.hint]);
        NSString *color = [save activityCompletionForKey:outfit];
        if (land) assert([color isEqualToString:@"Fire-type cycling outfit equipped"]);
        else if (waterMode) assert([color isEqualToString:@"Ice-type cycling outfit equipped"]);
        else assert(!color);
    }
    puts("PASS: Rotom Bike subtypes, Water Mode access and detour hints, and saved cycling outfit");
}

static void testSoniaAndApplin(const char *fixtureDirectory) {
    NSString *lock = @"hammerlocke.sonia-lock", *book = @"weald.sonia-book", *shrine = @"weald.sonia-shrine";
    NSString *applin = @"hammerlocke.applin", *epilogue = @"weald.postgame-epilogue";
    for (NSString *fixture in @[@"phase-only", @"lock-only", @"shrine-only", @"book-only", @"restored"]) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL lockOnly = [fixture isEqualToString:@"lock-only"];
        BOOL shrineOnly = [fixture isEqualToString:@"shrine-only"];
        assert(!![save activityCompletionForKey:lock] == lockOnly);
        assert(!![save activityCompletionForKey:book] == [fixture isEqualToString:@"book-only"]);
        assert(!![save activityCompletionForKey:shrine] == shrineOnly);
        assert(!![save activityCompletionForKey:epilogue] == [fixture isEqualToString:@"phase-only"]);
        assert(![save activityCompletionForKey:applin]);
        NSString *evidence = [save activityEvidenceForKey:applin];
        if (lockOnly) assert([evidence isEqualToString:@"Request discussed"]);
        else if (shrineOnly)
            assert([evidence isEqualToString:@"Party slot 1 · Applin available · Request discussed"]);
        else assert(!evidence);
    }
    puts("PASS: independent Sonia conversations and Key Items, Applin request progress, and restore");
}

static void testGymChallenge(const char *fixtureDirectory) {
    NSArray<NSString *> *areas = @[@"turffield", @"hulbury", @"motostoke", @"stow", @"ballonlea",
                                  @"circhester", @"spikemuth", @"hammerlocke"];
    NSString *fire = @"motostoke.gym-mission", *cup = @"wyndon.champion-cup";
    NSString *directory = @(fixtureDirectory);
    for (NSString *fixture in @[@"missions", @"badges", @"mixed", @"fire-score", @"fire-target", @"champion", @"tournament"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL champion = [fixture isEqualToString:@"champion"];
        BOOL mixed = [fixture isEqualToString:@"mixed"];
        NSUInteger badgeCount = 0;
        for (NSUInteger index = 0; index < areas.count; index++) {
            BOOL mission = champion || [fixture isEqualToString:@"missions"] || (mixed && index % 2 == 0);
            BOOL badge = champion || [fixture isEqualToString:@"badges"] || (mixed && index % 2 != 0);
            assert(!![save activityCompletionForKey:[areas[index] stringByAppendingString:@".gym-mission"]] == mission);
            assert(!![save activityCompletionForKey:[areas[index] stringByAppendingString:@".gym-badge"]] == badge);
            if (badge) badgeCount++;
        }
        NSString *title = [NSString stringWithFormat:@"Gym Challenge · %lu of 8 badges", badgeCount];
        assert([[DMGuideSavedContext gymChallengeTitleWithSavedContext:save] isEqualToString:title]);
        NSArray<NSString *> *rows = [DMGuideSavedContext gymChallengeRowsWithSavedContext:save];
        assert(rows.count == 8);
        if (mixed) {
            assert([rows[0] hasSuffix:@"Mission cleared · Badge pending"]);
            assert([rows[1] hasSuffix:@"Mission pending · Badge earned"]);
            assert(![save activityEvidenceForKey:fire]);
        }
        assert(!![save activityCompletionForKey:cup] == champion);
        assert(!![save activityCompletionForKey:@"wyndon.champion-tournament"] == [fixture isEqualToString:@"tournament"]);
        if ([fixture isEqualToString:@"fire-score"])
            assert([[save activityEvidenceForKey:fire] isEqualToString:@"3 of 5 mission points"]);
        if ([fixture isEqualToString:@"fire-target"])
            assert([[save activityEvidenceForKey:fire] isEqualToString:@"5-point target reached · 6 points recorded"]);
    }
    assert([[DMGuideSavedContext gymChallengeTitleWithSavedContext:nil] isEqualToString:@"Gym Challenge"]);
    assert([[DMGuideSavedContext gymChallengeRowsWithSavedContext:nil].firstObject isEqualToString:@"Turffield · Milo · Grass Badge"]);
    puts("PASS: independent Gym missions and badges, Fire score controls, Champion Cup and tournament distinction");
}

static void testPokemonProvenance(const char *fixtureDirectory) {
    NSString *directory = @(fixtureDirectory);
    NSArray<NSString *> *activities = @[@"route1.first-catch", @"route2.first-catch",
        @"route5.toxel", @"battle-tower.type-null"];
    for (NSUInteger order = 0; order < 32; order++) {
        for (NSNumber *expected in @[@NO, @YES]) {
            NSString *filename = [NSString stringWithFormat:@"%@-%02lu", expected.boolValue ? @"include" : @"exclude", order];
            NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:filename]];
            DMGuideSavedContext *context = [DMGuideSavedContext decode:data];
            assert(context);
            for (NSString *activity in activities)
                assert(!![context activityCompletionForKey:activity] == expected.boolValue);
        }
    }
    puts("PASS: trainer, origin, egg, checksum and gift provenance across all PK8 chunk orders");
}

static void testGiftBag(const char *fixtureDirectory) {
    NSArray<NSString *> *gifts = @[@"motostoke.earbuds", @"stow.fly", @"ballonlea.revenge",
        @"circhester.rock-tomb", @"circhester.screech", @"circhester.fake-tears", @"circhester.catching-charm",
        @"circhester.shiny-charm", @"route9.dive", @"wyndon.rotom-catalog"];
    for (NSString *fixture in @[@"interaction-only", @"bag-only", @"interaction-and-bag"]) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *context = [DMGuideSavedContext decode:data];
        assert(context);
        for (NSString *gift in gifts) {
            assert(!![context activityCompletionForKey:gift] == [fixture isEqualToString:@"interaction-and-bag"]);
            NSString *evidence = [context activityEvidenceForKey:gift];
            if ([gift isEqualToString:@"circhester.shiny-charm"] && [fixture isEqualToString:@"bag-only"])
                assert([evidence hasSuffix:@"Galar Pokémon caught"]);
            else
                assert(!!evidence == ![fixture isEqualToString:@"bag-only"]);
        }
    }
    puts("PASS: TM and Key Item completion requires the interaction flag and a positive quantity");
}

static void testTownRewards(const char *fixtureDirectory) {
    NSString *directory = @(fixtureDirectory);
    NSArray<NSString *> *gifts = @[@"hammerlocke.soothe-bell", @"hammerlocke.mr-focus",
        @"ballonlea.eviolite", @"motostoke.focus-energy", @"motostoke.star-piece"];
    NSString *weather = @"hammerlocke.weather-gifts";
    for (NSString *fixture in @[@"items-only", @"wrong-pockets", @"partial", @"complete"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *saved = [DMGuideSavedContext decode:data];
        assert(saved);
        BOOL complete = [fixture isEqualToString:@"complete"];
        for (NSString *key in gifts) {
            NSString *status = [saved activityCompletionForKey:key];
            BOOL pastSootheBell = [fixture isEqualToString:@"wrong-pockets"] && [key isEqualToString:gifts[0]];
            assert(!!status == (complete || pastSootheBell));
            if (pastSootheBell) assert([status containsString:@"past Bag entry recorded"]);
            if (complete) {
                BOOL held = [key isEqualToString:gifts[1]] || [key isEqualToString:gifts[2]] || [key isEqualToString:gifts[3]];
                assert([status containsString:held ? @"held by a Pokémon" : @"in your Bag"]);
            }
        }
        assert(!![saved activityCompletionForKey:weather] == complete);
        if ([fixture isEqualToString:@"items-only"])
            assert([[saved activityEvidenceForKey:weather] containsString:@"5 of 5 weather rewards"]);
        if ([fixture isEqualToString:@"wrong-pockets"])
            assert([[saved activityEvidenceForKey:weather] isEqualToString:@"0 of 5 weather rewards recorded · Bonus visit recorded"]);
        if ([fixture isEqualToString:@"partial"])
            assert([[saved activityEvidenceForKey:weather] containsString:@"2 of 5 weather rewards recorded · Next lesson is Hail"]);
    }
    puts("PASS: gift records, Bag and held rewards, pocket and Pokémon validation, and weather bonus progress");
}

static void testRibbons(const char *fixtureDirectory) {
    NSString *directory = @(fixtureDirectory);
    NSString *friendship = @"hammerlocke.friendship-ribbon", *effort = @"hammerlocke.effort-ribbon",
        *tower = @"battle-tower.master-ribbon";
    for (NSString *name in @[@"ready", @"collected", @"controls"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:name]];
        DMGuideSavedContext *saved = [DMGuideSavedContext decode:data];
        assert(saved);
        BOOL collected = [name isEqualToString:@"collected"];
        for (NSString *key in @[friendship, effort, tower])
            assert(([saved activityCompletionForKey:key] != nil) == collected);
        if ([name isEqualToString:@"ready"]) {
            assert([[saved activityEvidenceForKey:friendship] isEqualToString:@"Party slot 2 · maximum friendship"]);
            assert([[saved activityEvidenceForKey:effort] isEqualToString:@"Box 2, slot 7 · 510 total base points"]);
        } else {
            assert(![saved activityEvidenceForKey:friendship] && ![saved activityEvidenceForKey:effort]);
        }
    }
    puts("PASS: independent Ribbon ownership, eligibility thresholds, traded friendship, and party and box controls");
}

static void testTutorMoves(const char *fixtureDirectory) {
    NSString *directory = @(fixtureDirectory);
    NSArray<NSString *> *keys = @[@"motostoke.steel-beam", @"hammerlocke.pledge-tutor",
                                  @"circhester.draco-meteor", @"wyndon.starter-tutor"];
    NSDictionary<NSString *, NSArray<NSString *> *> *expected = @{
        @"partial": @[@"Steel Beam known in your collection",
                      @"2 of 3 moves known in your collection · Grass Pledge, Fire Pledge",
                      @"", @"1 of 3 moves known in your collection · Blast Burn"],
        @"complete": @[@"Steel Beam known in your collection",
                       @"3 of 3 moves known in your collection · Grass Pledge, Fire Pledge, Water Pledge",
                       @"Draco Meteor known in your collection",
                       @"3 of 3 moves known in your collection · Frenzy Plant, Blast Burn, Hydro Cannon"],
        @"controls": @[@"", @"", @"", @""],
    };
    for (NSString *fixture in @[@"partial", @"complete", @"controls"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *saved = [DMGuideSavedContext decode:data];
        assert(saved);
        for (NSUInteger index = 0; index < keys.count; index++) {
            NSString *result = [saved activityCompletionForKey:keys[index]] ?: @"";
            assert([result isEqualToString:expected[fixture][index]]);
        }
        NSString *training = [saved activityCompletionForKey:@"battle-tower.hyper-training"];
        if ([fixture isEqualToString:@"complete"])
            assert([training isEqualToString:@"Hyper-Trained Pokémon in your collection"]);
        else
            assert(!training);
    }
    puts("PASS: all eight tutor moves, distinct move counts, Hyper Training, traded and boxed Pokémon, and record controls");
}

static void testCardsAndCamping(const char *fixtureDirectory) {
    NSString *directory = @(fixtureDirectory);
    NSArray<NSString *> *activities = @[@"battle-tower.leon-card", @"galar-mine.rose-card", @"motostoke.ball-guy-card",
        @"wild-area.first-curry", @"wild-area.camp-toys", @"wild-area.golden-cookware", @"stow.ball-guy", @"circhester.ball-guy"];
    NSData *before = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:@"before-collecting"]];
    NSData *after = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:@"after-collecting"]];
    DMGuideSavedContext *empty = [DMGuideSavedContext decode:before];
    DMGuideSavedContext *finished = [DMGuideSavedContext decode:after];
    assert(empty && finished);
    for (NSString *activity in activities) {
        assert(![empty activityCompletionForKey:activity]);
        assert([finished activityCompletionForKey:activity]);
    }
    assert([[empty activityEvidenceForKey:@"wild-area.camp-toys"] hasPrefix:@"1 of 6"]);
    puts("PASS: exact card indices, Shield stadium variants, camp toy count and cookware unlock");
}

static void testBattleTower(const char *archivePath, const char *fixturePath) {
    NSString *directory = @(fixturePath);
    NSString *judge = @"battle-tower.judge", *singles = @"battle-tower.singles-master",
        *doubles = @"battle-tower.doubles-master";
    DMGuideSavedContext *archive = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:@(archivePath)]];
    assert([[archive battleTowerProgressForDoubles:NO].firstObject isEqualToString:@"Rank 1 · Beginner Tier"]);
    assert(![archive activityCompletionForKey:judge]);
    for (NSString *name in @[@"split", @"singles-master", @"both-master", @"invalid-singles"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:name]];
        DMGuideSavedContext *saved = [DMGuideSavedContext decode:data];
        assert(saved);
        NSArray<NSString *> *singleRows = [saved battleTowerProgressForDoubles:NO];
        NSArray<NSString *> *doubleRows = [saved battleTowerProgressForDoubles:YES];
        if ([name isEqualToString:@"split"]) {
            assert([singleRows containsObject:@"Rank 4 · Poké Ball Tier"]);
            assert([singleRows containsObject:@"Highest reached · Rank 5 · Poké Ball Tier"]);
            assert([singleRows containsObject:@"29 total wins"]);
            assert([singleRows containsObject:@"League Card background · 30 wins · 1 win to go"]);
            assert([doubleRows containsObject:@"Rank 7 · Great Ball Tier"]);
            assert([doubleRows containsObject:@"League Card background · 50 wins · Target reached"]);
            assert(![saved activityCompletionForKey:judge] && ![saved activityCompletionForKey:singles] &&
                ![saved activityCompletionForKey:doubles]);
        } else {
            assert([saved activityCompletionForKey:judge]);
            assert(([saved activityCompletionForKey:singles] != nil) == ![name isEqualToString:@"invalid-singles"]);
            assert(([saved activityCompletionForKey:doubles] != nil) == ![name isEqualToString:@"singles-master"]);
            if ([name isEqualToString:@"invalid-singles"]) {
                assert(!singleRows.count);
                assert([doubleRows containsObject:@"MAX · Master Ball Tier"]);
            }
        }
    }
    puts("PASS: independent Battle Tower ranks and wins, invalid fields, background milestones and Judge flag");
}

static void testBattleTowerRewardReference(void) {
    NSArray<NSString *> *ranks = [DMGuideSavedContext battleTowerRankRewardsForDoubles:NO savedContext:nil];
    assert(ranks.count == 10);
    assert([ranks.firstObject isEqualToString:@"Rank 2 · Beginner Tier\nRare Candy · 3 BP"]);
    assert([ranks.lastObject hasSuffix:@"Ability Capsule · Gold Bottle Cap · 50 BP"]);
    NSArray<NSString *> *wins = [DMGuideSavedContext battleTowerWinRewardsForDoubles:NO repeating:NO savedContext:nil];
    assert(wins.count == 7 && [wins.lastObject isEqualToString:@"200 wins · Starf Berry"]);
    NSArray<NSString *> *repeat = [DMGuideSavedContext battleTowerWinRewardsForDoubles:NO repeating:YES savedContext:nil];
    assert(repeat.count == 7 && [repeat.firstObject isEqualToString:@"Cycle step 10 · Random mint"]);
    assert([repeat[5] isEqualToString:@"Cycle step 75 · Gold Bottle Cap"]);
}

static void testTeaEvolutionReference(void) {
    assert([[DMGuideSavedContext teaEvolutionTitleWithSavedContext:nil] isEqualToString:@"Sinistea evolutions"]);
    NSArray<NSString *> *rows = [DMGuideSavedContext teaEvolutionRowsWithSavedContext:nil];
    assert(rows.count == 3 && [rows[0] containsString:@"Glimwood Tangle"]);
    assert([rows[1] hasPrefix:@"Phony Form · Cracked Pot\n"] && [rows[1] containsString:@"ladder"]);
    assert([rows[2] hasPrefix:@"Antique Form · Chipped Pot\n"] && [rows[2] containsString:@"bargain stall"]);
}

static void testTeaEvolutions(const char *fixtureDirectory) {
    NSString *phony = @"stow.phony-polteageist", *antique = @"stow.antique-polteageist";
    NSArray<NSString *> *fixtures = @[@"dex-only", @"ready", @"no-bag", @"one-evolved", @"both-evolved", @"no-boxes", @"restored"];
    for (NSString *fixture in fixtures) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL both = [fixture isEqualToString:@"both-evolved"];
        BOOL one = [fixture isEqualToString:@"one-evolved"];
        BOOL noBoxes = [fixture isEqualToString:@"no-boxes"];
        NSString *title = noBoxes ? @"Sinistea evolutions" :
            [NSString stringWithFormat:@"Sinistea evolutions · %d of 2 owned", both ? 2 : one ? 1 : 0];
        assert([[DMGuideSavedContext teaEvolutionTitleWithSavedContext:save] isEqualToString:title]);
        assert(!![save activityCompletionForKey:phony] == (one || both));
        assert(!![save activityCompletionForKey:antique] == both);
        assert(![save activityCompletionForKey:@"stow.cracked-pot"]);
        if (one || both)
            assert([[save activityCompletionForKey:phony] isEqualToString:@"Phony Form Polteageist · Box 2, slot 3"]);
        if (both)
            assert([[save activityCompletionForKey:antique] isEqualToString:@"Antique Form Polteageist · Box 32, slot 30"]);
        NSArray<NSString *> *rows = [DMGuideSavedContext teaEvolutionRowsWithSavedContext:save];
        if ([fixture isEqualToString:@"ready"]) {
            assert([rows[1] containsString:@"0 in Bag\n1 held by Pokémon\nSinistea · Party slot 1"]);
            assert([rows[2] containsString:@"3 in Bag\nSinistea · Box 1, slot 1"]);
            assert([[save activityEvidenceForKey:phony] isEqualToString:@"Party slot 1 · Cracked Pot held by a Pokémon"]);
            assert([[save activityEvidenceForKey:antique] isEqualToString:@"Box 1, slot 1 · Chipped Pot in Bag"]);
        } else if ([fixture isEqualToString:@"no-bag"]) {
            assert([rows[1] containsString:@"1 held by Pokémon"]);
            assert(![rows[2] containsString:@"in Bag"]);
        } else if (noBoxes) {
            assert([rows[1] containsString:@"Sinistea · Party slot 1"]);
            assert(![rows[2] containsString:@"Missing"]);
        } else if ([fixture isEqualToString:@"dex-only"]) {
            assert([save.galarDexCaughtCount isEqual:@1]);
            assert([rows[1] hasSuffix:@"Polteageist · Missing"] && [rows[2] hasSuffix:@"Polteageist · Missing"]);
        }
    }
    puts("PASS: both Sinistea and Polteageist forms, correct Pots and quantities, independent checkoffs and restore");
}

static void testStowMarketReference(void) {
    NSArray<NSString *> *stock = DMGuideSavedContext.stowBargainStock;
    NSArray<NSString *> *prices = DMGuideSavedContext.stowBuyerPrices;
    assert(stock.count == 28 && prices.count == 10);
    NSUInteger total = 0;
    for (NSString *row in stock) total += [row componentsSeparatedByString:@" · "].lastObject.integerValue;
    assert(total == 100);
    assert([stock containsObject:@"Cracked Pot · 20%"]);
    assert([stock containsObject:@"Chipped Pot · 3%"]);
    assert([prices.lastObject hasPrefix:@"Rare Bone · "]);
    assert([DMGuideSavedContext stowMarketRowsWithSavedContext:nil].count == 2);
}

static void testStowMarket(const char *fixtureDirectory) {
    NSArray<NSString *> *fixtures = @[@"uninitialized", @"open", @"no-bag", @"rollover", @"settled", @"invalid", @"restored"];
    NSNumberFormatter *numbers = [NSNumberFormatter new];
    numbers.numberStyle = NSNumberFormatterDecimalStyle;
    NSString *current = [numbers stringFromNumber:@3000];
    NSString *previous = [numbers stringFromNumber:@5000];
    NSString *sale = [numbers stringFromNumber:@11111];
    for (NSString *fixture in fixtures) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        NSArray<NSString *> *rows = [DMGuideSavedContext stowMarketRowsWithSavedContext:save];
        NSString *today = [NSString stringWithFormat:@"Today · Cracked Pot · %@ Pokédollars", current];
        NSString *yesterday = [NSString stringWithFormat:@"Yesterday · Chipped Pot · %@ Pokédollars", previous];
        NSString *request = [NSString stringWithFormat:@"Buyer wants · Rare Bone · %@ Pokédollars", sale];
        if ([fixture isEqualToString:@"open"] || [fixture isEqualToString:@"no-bag"]) {
            assert([rows containsObject:today] && [rows containsObject:yesterday]);
            assert([rows containsObject:@"Tomorrow’s preview · Quick Claw"]);
            assert([rows containsObject:request]);
            assert([rows containsObject:@"3 in Bag"] == [fixture isEqualToString:@"open"]);
        } else if ([fixture isEqualToString:@"settled"]) {
            assert([rows containsObject:@"Today’s bargain · Purchased when last saved"]);
            assert([rows containsObject:@"Yesterday · Chipped Pot · Purchased when last saved"]);
            NSString *status = [NSString stringWithFormat:@"Sale recorded when last saved · Rare Bone · %@ Pokédollars", sale];
            assert([rows containsObject:status]);
            assert([rows containsObject:@"Tomorrow’s preview · Quick Claw"]);
            assert(![rows containsObject:@"3 in Bag"]);
        } else if ([fixture isEqualToString:@"restored"]) {
            NSString *offer = [NSString stringWithFormat:@"Today · Quick Claw · %@ Pokédollars", current];
            assert([rows containsObject:offer]);
            assert([rows containsObject:@"Tomorrow’s preview · Chipped Pot"]);
            assert([rows containsObject:@"1 in Bag"]);
        } else {
            assert([rows isEqualToArray:[DMGuideSavedContext stowMarketRowsWithSavedContext:nil]]);
            assert(![rows containsObject:today] && ![rows containsObject:request]);
        }
        assert(![save activityCompletionForKey:@"stow.buyer"] && ![save activityCompletionForKey:@"stow.bargain"]);
    }
    puts("PASS: Stow market stock slots, buyer treasure quantities, saved purchase and sale status, rollover and restore");
}

static void testCafePrizeReference(void) {
    DMGuideArea towns[] = {DMGuideAreaMotostoke, DMGuideAreaHammerlocke, DMGuideAreaWyndon};
    for (NSUInteger town = 0; town < sizeof(towns) / sizeof(towns[0]); town++) {
        assert([[DMGuideSavedContext cafePrizeTitleInArea:towns[town]] isEqualToString:@"Battle Café prizes"]);
        NSArray<NSString *> *rows = [DMGuideSavedContext cafePrizeRowsInArea:towns[town] savedContext:nil];
        assert(rows.count == 21);
        NSInteger total = 0;
        for (NSString *row in rows) total += [row componentsSeparatedByString:@" · "].lastObject.integerValue;
        assert(total == 100);
        if (town == 0) assert([rows containsObject:@"Strawberry Sweet · 20%"] && [rows containsObject:@"Exp. Candy XS · 6%"]);
        if (town == 1) assert([rows containsObject:@"Love Sweet · 14%"] && [rows containsObject:@"Berry Sweet · 14%"]);
        if (town == 2) assert([rows containsObject:@"Clover Sweet · 14%"] && [rows containsObject:@"Exp. Candy L · 5%"]);
        assert(![rows containsObject:@"Star Sweet · 2%"]);
    }
    assert(![DMGuideSavedContext cafePrizeTitleInArea:DMGuideAreaRoute4]);
    assert(![DMGuideSavedContext cafePrizeRowsInArea:DMGuideAreaRoute4 savedContext:nil].count);
}

static void testCafePrizes(const char *fixtureDirectory) {
    DMGuideArea towns[] = {DMGuideAreaMotostoke, DMGuideAreaHammerlocke, DMGuideAreaWyndon};
    NSArray<NSString *> *fixtures = @[@"split", @"boundaries", @"invalid", @"missing", @"restored"];
    NSArray<NSArray<NSString *> *> *expected = @[
        @[@"Moomoo Milk", @"Love Sweet", @"Flower Sweet"],
        @[@"Moomoo Milk", @"Love Sweet", @"Berry Sweet"],
        @[@"Lava Cookie", @"", @""],
        @[@"", @"", @""],
        @[@"Berry Sweet", @"Moomoo Milk", @"Flower Sweet"],
    ];
    for (NSUInteger i = 0; i < fixtures.count; i++) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixtures[i]]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        for (NSUInteger town = 0; town < sizeof(towns) / sizeof(towns[0]); town++) {
            NSArray<NSString *> *rows = [DMGuideSavedContext cafePrizeRowsInArea:towns[town] savedContext:save];
            NSString *prize = expected[i][town];
            if (prize.length) {
                NSString *prediction = [@"Next prize from saved roll · " stringByAppendingString:prize];
                assert([rows.firstObject isEqualToString:prediction]);
            } else {
                assert(![rows.firstObject hasPrefix:@"Next prize"]);
            }
            BOOL knownFlag = i != 3 || town != 0;
            BOOL used = knownFlag && i < 4 && town == 0;
            assert([rows containsObject:@"Challenge used when last saved"] == used);
            assert([rows containsObject:@"Challenge unused when last saved"] == (knownFlag && !used));
        }
        assert(![save activityCompletionForKey:@"motostoke.battle-cafe"]);
        assert(![save activityCompletionForKey:@"hammerlocke.cafe"]);
        assert(![save activityCompletionForKey:@"wyndon.cafe"]);
    }
    puts("PASS: three Battle Café reward pools, saved roll boundaries, independent daily flags and restore");
}

static void testAlcremieReference(void) {
    assert([[DMGuideSavedContext alcremieTitleWithSavedContext:nil] isEqualToString:@"Alcremie collection"]);
    NSArray<NSString *> *sweets = [DMGuideSavedContext alcremieSweetTitlesWithSavedContext:nil];
    assert(sweets.count == 7 && [sweets.firstObject isEqualToString:@"Strawberry Sweet"]);
    assert([sweets.lastObject isEqualToString:@"Ribbon Sweet"]);
    NSArray<NSString *> *strawberry = [DMGuideSavedContext alcremieRowsForSweet:0 savedContext:nil];
    assert(strawberry.count == 10 && [strawberry.firstObject containsString:@"Hammerlocke"]);
    assert([strawberry[1] isEqualToString:@"Vanilla Cream\nDay · Clockwise · Under 5 seconds"]);
    assert([strawberry.lastObject isEqualToString:@"Rainbow Swirl\nDusk · Counterclockwise · Over 10 seconds"]);
    NSArray<NSString *> *ribbon = [DMGuideSavedContext alcremieRowsForSweet:6 savedContext:nil];
    assert([ribbon.firstObject containsString:@"Cram-o-matic"]);
    assert(![DMGuideSavedContext alcremieRowsForSweet:-1 savedContext:nil].count);
    assert(![DMGuideSavedContext alcremieRowsForSweet:7 savedContext:nil].count);
    assert([DMShieldGuide hasAlcremieCollectionInArea:DMGuideAreaRoute4]);
    assert([DMShieldGuide hasAlcremieCollectionInArea:DMGuideAreaMotostoke]);
    assert([DMShieldGuide hasAlcremieCollectionInArea:DMGuideAreaHammerlocke]);
    assert([DMShieldGuide hasAlcremieCollectionInArea:DMGuideAreaWyndon]);
    assert(![DMShieldGuide hasAlcremieCollectionInArea:DMGuideAreaWedgehurst]);
}

static void testAlcremieCollection(const char *fixtureDirectory) {
    NSArray<NSString *> *fixtures = @[@"partial", @"no-bag", @"no-boxes", @"full", @"restored"];
    unsigned counts[] = {4, 4, 1, 63, 0};
    for (NSUInteger i = 0; i < fixtures.count; i++) {
        NSString *fixture = fixtures[i];
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        NSString *title = [fixture isEqualToString:@"no-boxes"] ? @"Alcremie collection · 1 found" :
            [NSString stringWithFormat:@"Alcremie collection · %u of 63 owned", counts[i]];
        assert([[DMGuideSavedContext alcremieTitleWithSavedContext:save] isEqualToString:title]);
        NSArray<NSString *> *sweets = [DMGuideSavedContext alcremieSweetTitlesWithSavedContext:save];
        NSArray<NSString *> *strawberry = [DMGuideSavedContext alcremieRowsForSweet:0 savedContext:save];
        NSArray<NSString *> *ribbon = [DMGuideSavedContext alcremieRowsForSweet:6 savedContext:save];
        assert(![save activityCompletionForKey:@"hammerlocke.strawberry-sweet"]);
        if ([fixture isEqualToString:@"partial"]) {
            assert([sweets[0] hasSuffix:@"2 of 9 owned"] && [sweets[1] hasSuffix:@"1 of 9 owned"]);
            assert([sweets[2] hasSuffix:@"0 of 9 owned"] && [sweets[5] hasSuffix:@"0 of 9 owned"]);
            assert([strawberry[1] isEqualToString:@"5 in Bag · 1 held by Pokémon"]);
            assert([strawberry[2] hasSuffix:@"Box 1, slot 2"]);
            assert([strawberry[3] hasSuffix:@"Box 2, slot 3"]);
            NSArray<NSString *> *berry = [DMGuideSavedContext alcremieRowsForSweet:2 savedContext:save];
            NSArray<NSString *> *star = [DMGuideSavedContext alcremieRowsForSweet:5 savedContext:save];
            assert([berry[1] isEqualToString:@"0 in Bag · 0 held by Pokémon"]);
            assert([star[1] isEqualToString:@"0 in Bag · 0 held by Pokémon"]);
            assert([ribbon[1] isEqualToString:@"7 in Bag · 1 held by Pokémon"]);
            assert([ribbon.lastObject hasSuffix:@"Party slot 1"]);
        } else if ([fixture isEqualToString:@"no-bag"]) {
            assert([strawberry[1] isEqualToString:@"1 held by Pokémon"]);
        } else if ([fixture isEqualToString:@"no-boxes"]) {
            assert([sweets[0] isEqualToString:@"Strawberry Sweet"]);
            assert([sweets[6] hasSuffix:@"1 found"]);
            assert(![strawberry[2] hasSuffix:@"Missing"]);
        } else {
            NSString *suffix = [fixture isEqualToString:@"full"] ? @"9 of 9 owned" : @"0 of 9 owned";
            for (NSString *sweet in sweets) assert([sweet hasSuffix:suffix]);
        }
    }
    puts("PASS: 63 Alcremie variants, separate Sweet counts, valid slots and pockets, partial saves and restore");
}

static void testGigantamaxReference(void) {
    assert([[DMGuideSavedContext gigantamaxTitleWithSavedContext:nil] isEqualToString:@"Gigantamax collection"]);
    NSArray<NSString *> *rows = [DMGuideSavedContext gigantamaxRowsWithSavedContext:nil];
    assert(rows.count == 25);
    NSUInteger speciesWithDens = 0;
    for (NSString *row in rows) {
        speciesWithDens += [row containsString:@"Den "];
        assert(![row containsString:@" · Missing"] && ![row containsString:@" · Owned"]);
    }
    assert(speciesWithDens == 17);
    assert([rows[4] containsString:@"Leon’s gift Charmander in Postwick"]);
    assert([rows[10] containsString:@"Let’s Go, Eevee!"]);
    assert([rows[21] containsString:@"Let’s Go, Pikachu!"]);
    NSArray<NSString *> *locations = [DMShieldGuide gigantamaxRaidLocationsForSpecies:@"Charizard"];
    assert(locations.count == 1 && [locations.firstObject containsString:@"Purple beam · 5★"]);
    assert(![DMShieldGuide gigantamaxRaidLocationsForSpecies:@"Flapple"].count);
}

static void testGigantamaxCollection(const char *fixtureDirectory) {
    NSArray<NSString *> *fixtures = @[@"dex-only", @"partial", @"no-party", @"full", @"restored"];
    unsigned counts[] = {0, 4, 4, 25, 0};
    for (NSUInteger index = 0; index < fixtures.count; index++) {
        NSString *fixture = fixtures[index];
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL partial = [fixture isEqualToString:@"partial"], incompleteRead = [fixture isEqualToString:@"no-party"];
        NSString *title = incompleteRead ? @"Gigantamax collection · 4 found" :
            [NSString stringWithFormat:@"Gigantamax collection · %u of 25 owned", counts[index]];
        assert([[DMGuideSavedContext gigantamaxTitleWithSavedContext:save] isEqualToString:title]);
        NSArray<NSString *> *rows = [DMGuideSavedContext gigantamaxRowsWithSavedContext:save];
        NSUInteger owned = 0;
        for (NSString *row in rows) owned += [row containsString:@" · Owned"];
        assert(owned == counts[index]);
        if (partial || incompleteRead) {
            assert([rows[0] hasPrefix:@"Alcremie · Owned · Box 32, slot 30"]);
            assert([rows[4] hasPrefix:@"Charizard · Owned · Box 2, slot 3"]);
            assert([rows[24] hasPrefix:@"Toxtricity · Owned · Box 2, slot 6"]);
            assert([rows[10] hasPrefix:partial ? @"Eevee · Missing\n" : @"Eevee\n"]);
            assert([rows[19] hasPrefix:partial ? @"Meowth · Missing\n" : @"Meowth\n"]);
            assert([rows[21] hasPrefix:partial ? @"Pikachu · Owned · Party slot 2" : @"Pikachu · Owned · Box 2, slot 4"]);
        }
        if ([fixture isEqualToString:@"dex-only"]) {
            assert([save.galarDexCaughtCount isEqual:@1]);
            assert([rows[4] hasPrefix:@"Charizard · Missing"]);
        }
    }
    puts("PASS: Gigantamax factors, all 25 species, den sources, valid form ranges, partial reads and restore");
}

static void testRotomFormReference(void) {
    assert([[DMGuideSavedContext rotomFormsTitleWithSavedContext:nil] isEqualToString:@"Rotom forms"]);
    NSArray<NSString *> *forms = [DMGuideSavedContext rotomFormRowsWithSavedContext:nil];
    assert(forms.count == 6);
    assert([forms[0] isEqualToString:@"Rotom · Electric/Ghost\nRecall"]);
    assert([forms[3] isEqualToString:@"Frost Rotom · Electric/Ice\nRefrigerator · Blizzard"]);
    assert([forms[4] isEqualToString:@"Fan Rotom · Electric/Flying\nElectric fan · Air Slash"]);
}

static void testRotomForms(const char *fixtureDirectory) {
    NSArray<NSString *> *fixtures = @[@"seen-only", @"partial", @"catalog", @"full", @"no-boxes", @"no-dex", @"restored"];
    unsigned counts[] = {0, 3, 3, 6, 1, 6, 0};
    for (NSUInteger index = 0; index < fixtures.count; index++) {
        NSString *fixture = fixtures[index];
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        NSString *title = [fixture isEqualToString:@"no-boxes"] ? @"Rotom forms · 1 found" :
            [NSString stringWithFormat:@"Rotom forms · %u of 6 in collection", counts[index]];
        assert([[DMGuideSavedContext rotomFormsTitleWithSavedContext:save] isEqualToString:title]);
        BOOL catalog = index >= 2 && index <= 5;
        assert(!![save activityCompletionForKey:@"wyndon.rotom-catalog"] == catalog);
        NSArray<NSString *> *rows = [DMGuideSavedContext rotomFormRowsWithSavedContext:save];
        if ([fixture isEqualToString:@"partial"] || [fixture isEqualToString:@"catalog"]) {
            assert([rows[0] hasSuffix:@"Box 2, slot 4"]);
            assert([rows[1] hasSuffix:@"Box 2, slot 3"]);
            assert([rows[2] hasSuffix:@"Party slot 1"]);
            assert([rows[3] hasSuffix:@"\nSeen in Pokédex"]);
            assert([rows[4] hasSuffix:@"\nSeen in Pokédex"]);
            assert([rows[5] hasSuffix:@"\nUnseen in Pokédex"]);
        } else if ([fixture isEqualToString:@"seen-only"]) {
            assert([rows[3] hasSuffix:@"\nSeen in Pokédex"] && [rows[4] hasSuffix:@"\nSeen in Pokédex"]);
        } else if ([fixture isEqualToString:@"no-boxes"]) {
            assert([rows[2] hasSuffix:@"Party slot 1"]);
            assert([rows[1] hasSuffix:@"\nUnseen in Pokédex"]);
        } else if ([fixture isEqualToString:@"restored"]) {
            for (NSString *row in rows) assert([row hasSuffix:@"\nUnseen in Pokédex"]);
        }
    }
    puts("PASS: six Rotom forms, form-specific Pokédex sightings, party and Boxes, Catalog independence and restore");
}

static void testSilvallyMemoryReference(void) {
    assert([[DMGuideSavedContext silvallyMemoryTitleWithSavedContext:nil] isEqualToString:@"Silvally Memories"]);
    NSArray<NSString *> *rows = [DMGuideSavedContext silvallyMemoryRowsWithSavedContext:nil];
    assert(rows.count == 17 && [NSSet setWithArray:rows].count == 17);
    assert([rows.firstObject isEqualToString:@"Fighting Memory"]);
    assert([rows.lastObject isEqualToString:@"Fairy Memory"]);
}

static void testSilvallyMemories(const char *fixtureDirectory) {
    NSString *key = @"battle-tower.memories";
    NSArray<NSString *> *fixtures = @[@"items-only", @"gift-only", @"partial", @"missing-bag", @"complete", @"restored"];
    unsigned counts[] = {17, 0, 3, 2, 17, 0};
    for (NSUInteger index = 0; index < fixtures.count; index++) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixtures[index]]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        BOOL complete = [fixtures[index] isEqualToString:@"complete"];
        NSString *title = [NSString stringWithFormat:@"Silvally Memories · %u of 17 found", counts[index]];
        assert([[DMGuideSavedContext silvallyMemoryTitleWithSavedContext:save] isEqualToString:title]);
        assert(!![save activityCompletionForKey:key] == complete);
        assert(![save activityCompletionForKey:@"battle-tower.type-null"]);
        NSArray<NSString *> *rows = [DMGuideSavedContext silvallyMemoryRowsWithSavedContext:save];
        if ([fixtures[index] isEqualToString:@"partial"]) {
            assert([rows[0] isEqualToString:@"Fighting Memory · In Bag"]);
            assert([rows[4] isEqualToString:@"Rock Memory · Held by a Pokémon"]);
            assert([rows[16] isEqualToString:@"Fairy Memory · Held by a Pokémon"]);
            for (NSUInteger item = 1; item < 4; item++) assert([rows[item] hasSuffix:@" · Missing"]);
            for (NSUInteger item = 5; item < 16; item++) assert([rows[item] hasSuffix:@" · Missing"]);
            assert([[save activityEvidenceForKey:key] isEqualToString:@"3 of 17 Memories found · Gift sequence recorded"]);
        }
        if ([fixtures[index] isEqualToString:@"missing-bag"]) {
            assert([rows[0] hasSuffix:@" · Unknown"]);
            assert([rows.lastObject hasSuffix:@" · Held by a Pokémon"]);
        }
    }
    puts("PASS: all 17 Silvally Memories, saved grant work, Bag and held sources, missing blocks, invalid slots and restore");
}

static void testBattleTowerRewards(const char *fixtureDirectory) {
    for (NSString *fixture in @[@"split", @"thresholds", @"rollover", @"first", @"invalid", @"missing"]) {
        NSData *data = [NSData dataWithContentsOfFile:[@(fixtureDirectory) stringByAppendingPathComponent:fixture]];
        DMGuideSavedContext *save = [DMGuideSavedContext decode:data];
        assert(save);
        NSArray<NSString *> *singles = [DMGuideSavedContext battleTowerRankRewardsForDoubles:NO savedContext:save];
        NSArray<NSString *> *doubles = [DMGuideSavedContext battleTowerRankRewardsForDoubles:YES savedContext:save];
        NSArray<NSString *> *singleWins = [DMGuideSavedContext battleTowerWinRewardsForDoubles:NO repeating:NO savedContext:save];
        NSArray<NSString *> *doubleWins = [DMGuideSavedContext battleTowerWinRewardsForDoubles:YES repeating:NO savedContext:save];
        NSArray<NSString *> *singleRepeat = [DMGuideSavedContext battleTowerWinRewardsForDoubles:NO repeating:YES savedContext:save];
        NSArray<NSString *> *doubleRepeat = [DMGuideSavedContext battleTowerWinRewardsForDoubles:YES repeating:YES savedContext:save];
        if ([fixture isEqualToString:@"split"]) {
            assert([singles[5] hasPrefix:@"Rank 7 · Great Ball Tier · Reached"]);
            assert([singles[6] hasPrefix:@"Rank 8 · Great Ball Tier · Ahead"]);
            assert([doubles[1] hasPrefix:@"Rank 3 · Beginner Tier · Reached"]);
            assert([doubles[2] hasPrefix:@"Rank 4 · Poké Ball Tier · Ahead"]);
            assert([singleRepeat.firstObject hasSuffix:@"Random mint · 7 wins to go"]);
            assert([doubleRepeat.lastObject hasSuffix:@"Starf Berry · 1 win to go"]);
        } else if ([fixture isEqualToString:@"thresholds"]) {
            assert([singleWins.lastObject hasSuffix:@"Starf Berry · Reached"]);
            assert([singleRepeat.firstObject hasSuffix:@"Random mint · Reached this cycle"]);
            assert([doubleRepeat.lastObject hasSuffix:@"Starf Berry · Reached this cycle"]);
        } else if ([fixture isEqualToString:@"rollover"]) {
            assert([singleRepeat.firstObject hasSuffix:@"Random mint · 1 win to go"]);
            assert([doubleRepeat.firstObject hasSuffix:@"Random mint · 10 wins to go"]);
            assert([doubleWins.lastObject hasSuffix:@"Starf Berry · Reached"]);
        } else if ([fixture isEqualToString:@"first"]) {
            assert([singleWins[2] isEqualToString:@"30 wins · Bottle Cap · 1 win to go"]);
            assert([doubleWins[4] isEqualToString:@"50 wins · Gold Bottle Cap · Reached"]);
        } else {
            assert([singles.firstObject isEqualToString:@"Rank 2 · Beginner Tier\nRare Candy · 3 BP"]);
            assert([singleWins.firstObject isEqualToString:@"10 wins · PP Up"]);
            assert([doubleRepeat.lastObject isEqualToString:@"Cycle step 100 · Starf Berry"]);
        }
    }
    puts("PASS: Battle Tower rank and win rewards, independent counters, repeat rollover and unknown data");
}

static void testGalarDex(const char *archivePath, const char *fixturePath) {
    NSString *directory = @(fixturePath);
    DMGuideSavedContext *archive = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:@(archivePath)]];
    assert([archive.galarDexCaughtCount isEqualToNumber:@3]);
    NSArray<NSString *> *opening = [DMGuideSavedContext galarDexEntriesInRange:0 missingOnly:NO savedContext:archive];
    assert([opening containsObject:@"001 Grookey · Seen"]);
    assert([opening containsObject:@"004 Scorbunny · Caught"]);
    assert([opening containsObject:@"021 Rookidee · Caught"]);
    assert([opening containsObject:@"008 Drizzile · Unseen"]);
    NSSet<NSString *> *uncaught = archive.missingGalarSpecies;
    assert(uncaught.count == 397 && [uncaught containsObject:@"Grookey"] && ![uncaught containsObject:@"Scorbunny"]);
    NSString *route = [[DMShieldGuide encounterGroupsInArea:DMGuideAreaRoute2 matchingSpecies:uncaught]
        componentsJoinedByString:@"\n"];
    assert([route containsString:@"Galarian Zigzagoon"] && [route containsString:@"Far shore, water bike required"]);
    assert(![route containsString:@"Rookidee"] && ![route containsString:@"Chewtle"]);

    NSString *reward = @"circhester.shiny-charm";
    for (NSString *name in @[@"almost", @"full", @"visited", @"rewarded"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:name]];
        DMGuideSavedContext *saved = [DMGuideSavedContext decode:data];
        BOOL almost = [name isEqualToString:@"almost"];
        assert([saved.galarDexCaughtCount isEqualToNumber:almost ? @399 : @400]);
        assert([saved.missingGalarSpecies isEqualToSet:almost ? [NSSet setWithObject:@"Eternatus"] : [NSSet set]]);
        NSArray<NSString *> *missing = [DMGuideSavedContext galarDexEntriesInRange:15 missingOnly:YES savedContext:saved];
        if (almost) {
            assert([missing isEqualToArray:@[@"400 Eternatus · Seen"]]);
            assert([[DMGuideSavedContext galarDexRangesWithSavedContext:saved].lastObject hasSuffix:@"1 missing"]);
            assert([[saved activityEvidenceForKey:reward] hasPrefix:@"399 of 400"]);
        } else {
            assert(!missing.count);
        }
        if ([name isEqualToString:@"full"])
            assert([[saved activityEvidenceForKey:reward] isEqualToString:@"Galar Pokédex complete · visit the director"]);
        if ([name isEqualToString:@"visited"])
            assert([[saved activityEvidenceForKey:reward] isEqualToString:@"Pokédex reward interaction recorded"]);
        assert(([saved activityCompletionForKey:reward] != nil) == [name isEqualToString:@"rewarded"]);
    }
    puts("PASS: exact Galar records, seen and caught distinction, filter counts and independent Shiny Charm award");
}

static void testRally(const char *fixturePath) {
    NSString *directory = @(fixturePath);
    NSMutableArray<DMGuideSavedContext *> *saves = [NSMutableArray array];
    for (NSString *name in @[@"score-tie", @"ready", @"events", @"awards", @"unknown-charge"]) {
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:name]];
        DMGuideSavedContext *saved = [DMGuideSavedContext decode:data];
        assert(saved);
        [saves addObject:saved];
    }
    DMGuideSavedContext *tie = saves[0], *ready = saves[1], *events = saves[2], *awards = saves[3], *unknown = saves[4];
    NSString *rally = @"north-wild.rally", *wave = @"north-wild.rally-thunder-wave",
        *volt = @"north-wild.rally-volt-switch", *ball = @"north-wild.rally-fast-ball",
        *turbo = @"north-wild.bike-turbo", *digging = @"north-wild.digging-duo";
    assert([[tie activityCompletionForKey:rally] isEqualToString:@"1 Rally finish recorded · Best score 20000"]);
    assert([[ready activityCompletionForKey:rally] isEqualToString:@"11 Rally finishes recorded · Best score 20001"]);
    assert(![tie activityCompletionForKey:wave] && [ready activityCompletionForKey:wave]);
    assert([[tie activityEvidenceForKey:volt] isEqualToString:@"Best score 20000"]);
    assert([[ready activityEvidenceForKey:volt] hasSuffix:@"point target reached"]);
    assert(![events activityCompletionForKey:volt] && [events activityEvidenceForKey:volt]);
    assert([awards activityCompletionForKey:volt]);
    assert([[ready activityEvidenceForKey:ball] isEqualToString:@"11 of 11 runs finished"] && ![ready activityCompletionForKey:ball]);
    assert([[events activityCompletionForKey:ball] hasPrefix:@"Fast Ball reward event recorded"]);
    assert([[tie activityEvidenceForKey:turbo] hasSuffix:@"next costs 1,000 W"]);
    assert([[ready activityEvidenceForKey:turbo] hasSuffix:@"next costs 3,000 W"]);
    assert([[events activityEvidenceForKey:turbo] hasSuffix:@"next costs 5,000 W"]);
    assert(![events activityCompletionForKey:turbo] && [awards activityCompletionForKey:turbo]);
    assert(![unknown activityEvidenceForKey:turbo] && ![unknown activityCompletionForKey:turbo]);
    assert([[ready activityCompletionForKey:digging] hasSuffix:@"Skill best 2"]);
    assert([[events activityCompletionForKey:digging] hasSuffix:@"Skill best 2 · Stamina best 8"]);
    puts("PASS: Rally finishes, exact score boundary, independent reward evidence, turbo tiers and Digging Duo records");
}

static void testCurryDex(const char *archivePath, const char *fixturePath) {
    NSString *directory = @(fixturePath);
    DMGuideSavedContext *empty = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:@(archivePath)]];
    DMGuideSavedContext *five = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:
        [directory stringByAppendingPathComponent:@"five"]]];
    DMGuideSavedContext *full = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:
        [directory stringByAppendingPathComponent:@"full"]]];
    DMGuideSavedContext *rewarded = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:
        [directory stringByAppendingPathComponent:@"rewarded"]]];
    assert([empty.cookedCurryCount isEqualToNumber:@0]);
    assert([five.cookedCurryCount isEqualToNumber:@5]);
    assert([full.cookedCurryCount isEqualToNumber:@151] && [rewarded.cookedCurryCount isEqualToNumber:@151]);
    NSArray<NSString *> *sausages = [DMGuideSavedContext curryRecipesInGroup:1 savedContext:five];
    assert([sausages containsObject:@"Sausage Curry · Cooked"]);
    assert([sausages containsObject:@"Spicy Sausage Curry · Cooked"]);
    assert([sausages containsObject:@"Dry Sausage Curry · Missing"]);
    assert([sausages containsObject:@"Sour Sausage Curry · Cooked"]);
    assert([[DMGuideSavedContext curryRecipesInGroup:25 savedContext:five].firstObject
        isEqualToString:@"Gigantamax Curry · Cooked"]);
    NSArray<NSString *> *rewards = [DMGuideSavedContext campingRewardsWithSavedContext:five];
    assert([rewards containsObject:@"Sausages ×3 · 1 recipe · Reward visit recorded"]);
    assert([rewards containsObject:@"Fresh Ball · 5 recipes · Ready for assessment"]);
    assert([rewards containsObject:@"Weighted Ball · 10 recipes"]);
    assert([[DMGuideSavedContext campingRewardsWithSavedContext:full].lastObject
        isEqualToString:@"Golden cookware · 151 recipes · Ready for assessment"]);
    assert([[DMGuideSavedContext campingRewardsWithSavedContext:rewarded].lastObject
        isEqualToString:@"Golden cookware · 151 recipes · Unlocked"]);
    assert(![empty activityCompletionForKey:@"wild-area.first-curry"]);
    assert([five activityCompletionForKey:@"wild-area.first-curry"]);
    assert(![full activityCompletionForKey:@"wild-area.golden-cookware"]);
    assert([rewarded activityCompletionForKey:@"wild-area.golden-cookware"]);
    puts("PASS: Curry Dex record bounds, distinct serving sizes, threshold readiness and independent reward flags");
}

static void testHiddenPickups(const char *archivePath, const char *fixtureDirectory) {
    NSString *directory = @(fixtureDirectory);
    DMGuideSavedContext *archive = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:@(archivePath)]];
    DMGuideSavedContext *partial = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:
        [directory stringByAppendingPathComponent:@"partial"]]];
    DMGuideSavedContext *complete = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:
        [directory stringByAppendingPathComponent:@"collected"]]];
    DMGuideSavedContext *respawned = [DMGuideSavedContext decode:[NSData dataWithContentsOfFile:
        [directory stringByAppendingPathComponent:@"respawned"]]];
    assert(archive && partial && complete && respawned);
    assert(![archive activityCompletionForKey:@"wedgehurst.revive"]);
    assert([partial activityCompletionForKey:@"wedgehurst.revive"]);
    assert(![partial activityCompletionForKey:@"route2.fresh-water"]);
    assert(![partial activityCompletionForKey:@"route2.repel"]);
    assert(![partial activityCompletionForKey:@"route2.rare-candy"]);
    assert(![partial activityCompletionForKey:@"galar-mine.revives"]);
    assert([[partial activityEvidenceForKey:@"galar-mine.revives"] hasPrefix:@"1 of 2"]);
    assert(![partial activityEvidenceForKey:@"galar-mine.stardust"]);
    assert(![partial activityCompletionForKey:@"route9.pearls"]);
    assert([[partial activityEvidenceForKey:@"route9.pearls"] hasPrefix:@"1 of 5"]);
    for (NSString *key in @[@"wedgehurst.revive", @"route2.fresh-water", @"galar-mine.revives",
                            @"route4.energy-powder", @"route9.pearls", @"hammerlocke.dire-hit"]) {
        assert([complete activityCompletionForKey:key]);
        assert([respawned activityCompletionForKey:key]);
    }
    for (NSString *key in @[@"route2.rare-candy", @"route5.feathers", @"north-wild.lake-stones"]) {
        assert(![partial activityCompletionForKey:key]);
        assert([[complete activityCompletionForKey:key] hasPrefix:@"Collected before respawn"]);
        assert(![respawned activityCompletionForKey:key]);
    }
    assert(![complete activityCompletionForKey:@"outskirts.feathers"]);
    NSArray<NSString *> *lake = [DMGuideSavedContext wildSparklesInArea:DMGuideAreaNorthWild
        subarea:7 savedContext:complete];
    assert([lake.firstObject hasPrefix:@"1 of 14"]);
    assert([lake containsObject:@"Water Stone · 1 of 1 awaiting respawn"]);
    DMGuideSparkleMap *collectedMap = [DMGuideSavedContext wildSparkleMapInArea:DMGuideAreaNorthWild
        subarea:7 savedContext:complete];
    DMGuideSparkleMap *respawnedMap = [DMGuideSavedContext wildSparkleMapInArea:DMGuideAreaNorthWild
        subarea:7 savedContext:respawned];
    assert(collectedMap.spots.count == 14 && respawnedMap.spots.count == 14);
    assert([collectedMap.spots[6].title hasSuffix:@"Water Stone"]);
    assert([collectedMap.spots[6].saveStatus isEqualToString:@"Awaiting respawn in the last save"]);
    assert([respawnedMap.spots[6].saveStatus isEqualToString:@"Not awaiting respawn in the last save"]);
    assert([collectedMap.spots[5].saveStatus isEqualToString:@"Not awaiting respawn in the last save"]);
    assert([[DMGuideSavedContext wildSparklesInArea:DMGuideAreaNorthWild subarea:7
        savedContext:respawned].firstObject hasPrefix:@"0 of 14"]);
    assert([[DMGuideSavedContext wildSparklesInArea:DMGuideAreaWildArea subarea:0
        savedContext:archive].firstObject hasPrefix:@"0 of 14"]);
    NSIndexSet *decoded = [complete valueForKey:@"permanentHiddenPickups"];
    assert([decoded containsIndex:513] && [decoded containsIndex:1026]);
    puts("PASS: hidden pickup indices, grouped progress, unrelated sparkles, invalid states and respawn");
}

static void refresh(DMGuideSaveMonitor *monitor) {
    __block BOOL notified = NO;
    [monitor refresh:^{ notified = YES; }];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (!notified && [deadline timeIntervalSinceNow] > 0)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    assert(notified);
}

static void testArchives(const char *preLab, const char *older, const char *newer) {
    NSData *beforeUnlock = [NSData dataWithContentsOfFile:@(preLab)];
    NSData *wedgehurst = [NSData dataWithContentsOfFile:@(older)];
    NSData *professor = [NSData dataWithContentsOfFile:@(newer)];
    assert(beforeUnlock && wedgehurst && professor);
    NSString *temp = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    snapshotPath = temp;
    DMGuideSaveMonitor *monitor = [DMGuideSaveMonitor new];
    dm_shield_guide_configure("unsupported", openTestSave);
    refresh(monitor);
    assert(!monitor.context && !monitor.stale);
    dm_shield_guide_configure("a16802625e7826bf83b6f9708e475b91", openTestSave);
    assert([beforeUnlock writeToFile:temp atomically:YES]);
    refresh(monitor);
    assert(monitor.context.area == DMGuideAreaWedgehurst && monitor.context.mainPhase.integerValue == 200);
    assert(monitor.context.pokedexUnlocked && !monitor.context.pokedexUnlocked.boolValue);
    for (NSString *key in @[@"route2.jake", @"route2.lauren", @"route2.benjamin"])
        assert(![monitor.context activityCompletionForKey:key]);
    assert([wedgehurst writeToFile:temp atomically:YES]);
    refresh(monitor);
    assert(!monitor.stale && monitor.context.area == DMGuideAreaWedgehurst);
    assert(monitor.context.mainPhase.integerValue == 250 && monitor.context.pokedexUnlocked.boolValue);
    assert([professor writeToFile:temp atomically:YES]);
    refresh(monitor);
    assert(monitor.context.area == DMGuideAreaRoute2 && monitor.context.mainPhase.integerValue == 270);
    assert(monitor.context.guidance.integerValue == 250);
    assert([monitor.context.objective isEqualToString:DMGuideOpeningObjective(250)]);
    assert([monitor.context activityCompletionForKey:@"route2.first-catch"]);
    for (NSString *key in @[@"route2.jake", @"route2.lauren", @"route2.benjamin"])
        assert([monitor.context activityCompletionForKey:key]);
    assert(![monitor.context activityCompletionForKey:@"route1.first-catch"]);
    assert(![monitor.context activityCompletionForKey:@"battle-tower.leon-card"]);
    assert(![monitor.context activityCompletionForKey:@"motostoke.ball-guy-card"]);

    NSMutableData *corrupt = [professor mutableCopy];
    ((uint8_t *)corrupt.mutableBytes)[0] ^= 1;
    assert(![DMGuideSavedContext decode:corrupt]);
    assert([corrupt writeToFile:temp atomically:YES]);
    refresh(monitor);
    assert(monitor.stale && monitor.context.mainPhase.integerValue == 270);
    assert([beforeUnlock writeToFile:temp atomically:YES]);
    refresh(monitor);
    assert(!monitor.stale && monitor.context.area == DMGuideAreaWedgehurst && monitor.context.mainPhase.integerValue == 200);
    assert(monitor.context.pokedexUnlocked && !monitor.context.pokedexUnlocked.boolValue);
    assert(![monitor.context activityCompletionForKey:@"route2.first-catch"]);
    for (NSString *key in @[@"route2.jake", @"route2.lauren", @"route2.benjamin"])
        assert(![monitor.context activityCompletionForKey:key]);
    assert([NSFileManager.defaultManager removeItemAtPath:temp error:nil]);
    puts("PASS: archive replacement, exact guidance, corruption/staleness and older-save reconciliation");
}

static NSData *fixtureData(NSString *folder, NSString *name) {
    NSData *data = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:name]];
    assert(data);
    return data;
}

static void testSyntheticMonitor(NSString *folder) {
    NSData *early = fixtureData(folder, @"early");
    NSData *later = fixtureData(folder, @"later");
    snapshotPath = [folder stringByAppendingPathComponent:@"committed"];
    DMGuideSaveMonitor *monitor = [DMGuideSaveMonitor new];
    NSString *pickup = @"route1.potion";
    assert([early writeToFile:snapshotPath atomically:YES]);
    dm_shield_guide_configure("unsupported", openTestSave);
    refresh(monitor);
    assert(!monitor.context && !monitor.stale);
    assert([monitor.status isEqualToString:@"Saved guidance requires Shield 1.3.2"]);
    dm_shield_guide_configure(DM_SHIELD_GUIDE_BUILD, openTestSave);
    assert([NSFileManager.defaultManager removeItemAtPath:snapshotPath error:nil]);
    refresh(monitor);
    assert(!monitor.context && !monitor.stale);
    assert([monitor.status isEqualToString:@"Waiting for a committed Shield save"]);

    assert([early writeToFile:snapshotPath atomically:YES]);
    refresh(monitor);
    assert(monitor.context.area == DMGuideAreaWedgehurst);
    assert(![monitor.context activityCompletionForKey:pickup]);

    assert([fixtureData(folder, @"superseded") writeToFile:snapshotPath atomically:YES]);
    replacementOnRecheck = later;
    opensUntilReplacement = 2;  // Replace the inode when the monitor reopens after decoding.
    __block BOOL refreshed = NO;
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (!refreshed && deadline.timeIntervalSinceNow > 0) {
        [monitor refresh:^{
            assert(monitor.context.mainPhase.integerValue == 270);
            refreshed = YES;
        }];
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    assert(refreshed && !replacementOnRecheck);
    assert(monitor.context.area == DMGuideAreaRoute2);
    assert([monitor.context.objective isEqualToString:DMGuideOpeningObjective(250)]);
    assert([monitor.context activityCompletionForKey:pickup]);

    NSData *truncated = [later subdataWithRange:NSMakeRange(0, later.length - 1)];
    assert(![DMGuideSavedContext decode:truncated]);
    assert([truncated writeToFile:snapshotPath atomically:YES]);
    refresh(monitor);
    assert(monitor.stale && monitor.context.mainPhase.integerValue == 270);
    assert([monitor.status isEqualToString:@"Last known save · refresh unavailable"]);
    assert([early writeToFile:snapshotPath atomically:YES]);
    refresh(monitor);
    assert(!monitor.stale && monitor.context.mainPhase.integerValue == 200);
    assert(![monitor.context activityCompletionForKey:pickup]);
    assert([NSFileManager.defaultManager removeItemAtPath:snapshotPath error:nil]);
    dm_shield_guide_configure("unsupported", openTestSave);
    puts("PASS: synthetic committed save, superseded read, exact guidance, truncation, stale context and rollback");
}

static void testSyntheticGifts(NSString *folder) {
    NSString *gift = @"hammerlocke.soothe-bell";
    DMGuideSavedContext *visit = [DMGuideSavedContext decode:fixtureData(folder, @"full-bag")];
    DMGuideSavedContext *alternate = [DMGuideSavedContext decode:fixtureData(folder, @"alternate-item-only")];
    DMGuideSavedContext *held = [DMGuideSavedContext decode:fixtureData(folder, @"held-gift")];
    assert(visit && alternate && held);
    assert([visit activityEvidenceForKey:gift] && ![visit activityCompletionForKey:gift]);
    assert(![alternate activityCompletionForKey:gift]);
    assert([[held activityCompletionForKey:gift] containsString:@"held by a Pokémon"]);
    puts("PASS: gift interaction alone, alternate item alone, and matching reward held by a Pokémon");
}

static void testFirstHopWin(NSString *folder) {
    for (NSString *name in @[@"missing", @"initial", @"postponed", @"lost", @"won", @"later"]) {
        DMGuideSavedContext *save = [DMGuideSavedContext decode:fixtureData(folder, name)];
        assert(save);
        BOOL recorded = [name isEqualToString:@"won"] || [name isEqualToString:@"later"];
        assert(!![save activityCompletionForKey:@"postwick.hop-first-win"] == recorded);
        assert(![save activityCompletionForKey:@"postwick.sonia-revives"]);
    }
    puts("PASS: first Hop win flag, postponed and lost battles, later phase, and missing state");
}

static void testRoute2HopWin(NSString *folder) {
    for (NSString *name in @[@"missing", @"initial", @"postponed", @"lost", @"won", @"later"]) {
        DMGuideSavedContext *save = [DMGuideSavedContext decode:fixtureData(folder, name)];
        assert(save && [save activityCompletionForKey:@"postwick.hop-first-win"]);
        BOOL recorded = [name isEqualToString:@"won"] || [name isEqualToString:@"later"];
        assert(!![save activityCompletionForKey:@"route2.hop-win"] == recorded);
        assert(![save activityCompletionForKey:@"motostoke.hop-win"]);
    }
    puts("PASS: Route 2 Hop win flag, postponed and lost battles, later phase, and independent Postwick win");
}

static void testFieldTrainerFlags(NSString *folder) {
    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    for (DMGuideArea area = 0; area < (DMGuideArea)DMShieldGuide.areaNames.count; area++) {
        for (DMGuideActivity *activity in [DMShieldGuide activitiesInArea:area]) {
            if ([activity.key containsString:@".trainer-"] ||
                [@[@"route2.jake", @"route2.lauren", @"route2.benjamin"] containsObject:activity.key])
                [keys addObject:activity.key];
        }
    }
    assert(keys.count == 65 && [NSSet setWithArray:keys].count == 65);
    NSSet<NSString *> *pairs = [NSSet setWithArray:@[
        @"route5.trainer-gillian", @"route6.trainer-iwan", @"glimwood.trainer-robert",
        @"route8.trainer-jordan", @"route9.trainer-owen", @"route10.trainer-gillian"
    ]];
    for (NSString *name in @[@"missing", @"lost", @"wrong-type", @"all", @"restored"]) {
        DMGuideSavedContext *save = [DMGuideSavedContext decode:fixtureData(folder, name)];
        assert(save);
        for (NSString *key in keys)
            assert(!![save activityCompletionForKey:key] == [name isEqualToString:@"all"]);
    }
    for (NSString *winner in keys) {
        DMGuideSavedContext *save = [DMGuideSavedContext decode:fixtureData(folder, winner)];
        assert(save);
        assert([[save activityCompletionForKey:winner] containsString:@"estimated from save"]);
        for (NSString *key in keys)
            assert(!![save activityCompletionForKey:key] == [key isEqualToString:winner]);
        if ([pairs containsObject:winner]) {
            for (NSString *suffix in @[@"-primary", @"-partner"]) {
                DMGuideSavedContext *partial = [DMGuideSavedContext decode:fixtureData(folder, [winner stringByAppendingString:suffix])];
                assert(partial && ![partial activityCompletionForKey:winner]);
            }
        }
        assert(![save activityCompletionForKey:@"motostoke.hop-win"]);
        assert(![save activityCompletionForKey:@"wild-area.chloe"]);
        assert(![save activityCompletionForKey:@"battle-tower.rental-team"]);
    }
    puts("PASS: 65 independent field Trainer flags, six doubles pairs, missing/false/wrong-type fields and restore");
}

static void testDailyTracking(NSString *folder) {
    NSMutableArray<DMGuideActivity *> *daily = [NSMutableArray array];
    for (DMGuideArea area = 0; area < (DMGuideArea)DMShieldGuide.areaNames.count; area++) {
        for (DMGuideActivity *activity in [DMShieldGuide activitiesInArea:area])
            if (activity.isDaily) [daily addObject:activity];
    }
    assert(daily.count == 9);
    NSString *suite = [@"shield-guide-daily-" stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    DMShieldGuide *guide = [[DMShieldGuide alloc] initWithDefaults:defaults];
    for (DMGuideActivity *activity in daily) {
        assert(![guide isChecked:activity]);
        [guide setChecked:YES forActivity:activity];
    }
    guide = [[DMShieldGuide alloc] initWithDefaults:defaults];
    for (NSString *name in @[@"used", @"restored", @"used"]) {
        DMGuideSavedContext *save = [DMGuideSavedContext decode:fixtureData(folder, name)];
        assert(save);
        for (DMGuideActivity *activity in daily) {
            assert(![save activityCompletionForKey:activity.key]);
            assert([guide isChecked:activity]);
        }
    }
    for (NSString *tag in @[@"2000-01-01", @"2999-12-31"]) {
        for (DMGuideActivity *activity in daily) {
            NSString *key = [@"shieldGuide.checked." stringByAppendingString:activity.key];
            [defaults setObject:tag forKey:key];
            assert(![guide isChecked:activity]);
            [guide setChecked:YES forActivity:activity];
            assert([guide isChecked:activity]);
        }
    }
    for (NSString *name in @[@"used", @"missing-request", @"zero-request", @"invalid-request",
                             @"wrong-type-request", @"missing-outcome", @"wrong-type-outcome"]) {
        DMGuideSavedContext *save = [DMGuideSavedContext decode:fixtureData(folder, name)];
        assert(save);
        assert(!![save activityEvidenceForKey:@"stow.buyer"] == [name isEqualToString:@"used"]);
        assert(![save activityCompletionForKey:@"stow.buyer"]);
    }
    [defaults removePersistentDomainForName:suite];
    puts("PASS: nine daily marks, same-day restart, older restore, past/future date tags and typed buyer evidence");
}

static void testAmbiguousEvents(NSString *folder) {
    NSArray<NSString *> *manualKeys = @[
        @"hammerlocke.applin", @"hulbury.maximizers", @"wild-area.chloe",
        @"battle-tower.rental-team", @"wild-area.watt-find", @"north-wild.yamask-evolution",
        @"wedgehurst.galarian-slowpoke", @"motostoke.leon-starter-gift", @"motostoke.hop-win"
    ];
    NSString *suite = [@"shield-guide-side-events-" stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    DMShieldGuide *guide = [[DMShieldGuide alloc] initWithDefaults:defaults];
    NSMutableDictionary<NSString *, DMGuideActivity *> *activities = [NSMutableDictionary dictionary];
    for (DMGuideArea area = 0; area < (DMGuideArea)DMShieldGuide.areaNames.count; area++)
        for (DMGuideActivity *activity in [DMShieldGuide activitiesInArea:area])
            activities[activity.key] = activity;
    for (NSString *name in @[@"1", @"2", @"restored"]) {
        DMGuideSavedContext *save = [DMGuideSavedContext decode:fixtureData(folder, name)];
        assert(save);
        for (NSString *key in manualKeys) {
            DMGuideActivity *activity = activities[key];
            assert(activity && ![save activityCompletionForKey:key]);
            [guide setChecked:YES forActivity:activity];
            assert([guide isChecked:activity]);
            [guide setChecked:NO forActivity:activity];
            assert(![guide isChecked:activity]);
        }
        assert(![save activityCompletionForKey:@"wild-area.first-raid"]);
        if (![name isEqualToString:@"restored"])
            assert([[save activityCompletionForKey:@"wild-area.raid-battle"] isEqualToString:@"99 Max Raid battles recorded"]);
    }
    DMGuideActivity *raid = activities[@"wild-area.first-raid"];
    [guide setChecked:YES forActivity:raid];
    guide = [[DMShieldGuide alloc] initWithDefaults:defaults];
    assert([guide isChecked:raid]);
    [defaults removePersistentDomainForName:suite];
    puts("PASS: ambiguous side-event flags, ownership and general records retain independent player marks");
}


static DMGuideActivityRow *presentationRow(DMGuidePresentation *context, DMShieldGuide *guide, NSString *key) {
    for (DMGuideActivityRow *row in [context rowsWithGuide:guide query:@"" incompleteOnly:NO])
        if ([row.activity.key isEqualToString:key]) return row;
    assert(!"Missing presentation row");
    return nil;
}

static void testPresentation(NSString *root) {
    NSString *suite = [@"shield-guide-presentation-" stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    DMShieldGuide *guide = [[DMShieldGuide alloc] initWithDefaults:defaults];
    DMGuideSavedContext *save = [DMGuideSavedContext decode:fixtureData(root, @"monitor/later")];
    DMGuideLiveLocation *live = [DMGuideLiveLocation new];
    [live setValue:@(DMGuideAreaMotostoke) forKey:@"area"];
    [live setValue:@"Indoors — Motostoke" forKey:@"name"];
    [live setValue:@YES forKey:@"placementBased"];
    DMGuidePresentation *(^resolve)(DMGuideSource, BOOL, DMGuideLiveLocation *, DMGuideSavedContext *) =
        ^(DMGuideSource source, BOOL stale, DMGuideLiveLocation *location, DMGuideSavedContext *saved) {
            return [DMGuidePresentation resolveSource:source manualArea:DMGuideAreaRoute1 saved:saved
                stale:stale status:stale ? @"Last known save · refresh unavailable" : @"Based on your last save"
                live:location preview:DMShieldGuide.previews[0]];
        };
    DMGuidePresentation *current = resolve(DMGuideSourceCurrent, NO, live, save);
    assert(current.area == DMGuideAreaMotostoke && current.progress == save && !current.canChooseArea);
    NSString *summary = [current.summary componentsJoinedByString:@"\n"];
    assert([summary containsString:@"Live location estimate"] && [summary containsString:@"Last saved objective"]);
    assert(![current.summary containsObject:save.nextStep] && [summary containsString:@"moved since saving"]);
    assert(presentationRow(current, guide, @"motostoke.gym-mission").later);
    assert(presentationRow(current, guide, @"motostoke.gym-badge").later);
    assert(presentationRow(current, guide, @"motostoke.steel-beam").later);
    assert(!presentationRow(current, guide, @"motostoke.focus-energy").later);
    current = resolve(DMGuideSourceCurrent, NO, nil, save);
    assert(current.area == DMGuideAreaRoute2 && [current.summary containsObject:save.nextStep]);
    current = resolve(DMGuideSourceSaved, NO, live, save);
    assert(current.area == DMGuideAreaRoute2 && current.progress == save);
    current = resolve(DMGuideSourceManual, NO, live, save);
    assert(current.area == DMGuideAreaRoute1 && current.canChooseArea && current.progress == save);
    DMGuideActivityRow *pickup = presentationRow(current, guide, @"route1.potion");
    assert(pickup.completed && [pickup.status containsString:@"recorded in save"]);
    assert([current rowsWithGuide:guide query:@"Potion pickup" incompleteOnly:NO].count == 1);
    assert(![current rowsWithGuide:guide query:@"Potion pickup" incompleteOnly:YES].count);
    assert(![current rowsWithGuide:guide query:@"no such activity" incompleteOnly:NO].count);
    current = resolve(DMGuideSourceArchive, NO, live, save);
    assert(current.readOnly && !current.progress && !current.canChooseArea && current.area == DMShieldGuide.previews[0].area);
    current = resolve(DMGuideSourceCurrent, YES, live, save);
    assert(current.area == DMGuideAreaMotostoke && !current.progress);
    assert([[current.summary componentsJoinedByString:@"\n"] containsString:@"Last-known saved objective"]);
    current = resolve(DMGuideSourceSaved, YES, live, save);
    assert(current.area == DMGuideAreaRoute1 && current.canChooseArea && !current.progress);
    current = resolve(DMGuideSourceCurrent, NO, nil, nil);
    assert(current.area == DMGuideAreaRoute1 && !current.progress && current.canChooseArea);
    DMGuideSavedContext *unknown = [DMGuideSavedContext decode:fixtureData(root, @"presentation/unknown")];
    current = resolve(DMGuideSourceSaved, NO, nil, unknown);
    assert(current.canChooseArea && current.area == DMGuideAreaRoute1);
    for (NSString *name in @[@"unknown", @"locked", @"ready", @"wrong-types", @"invalid-letter"]) {
        DMGuideSavedContext *saved = [DMGuideSavedContext decode:fixtureData(root, [@"presentation/" stringByAppendingString:name])];
        for (NSNumber *area in @[@(DMGuideAreaRoute2), @(DMGuideAreaPostwick), @(DMGuideAreaBallonlea)]) {
            NSString *key = area.integerValue == DMGuideAreaRoute2 ? @"route2.choice-band" :
                area.integerValue == DMGuideAreaPostwick ? @"postwick.charmander" : @"ballonlea.letter";
            DMGuidePresentation *context = [DMGuidePresentation resolveSource:DMGuideSourceManual manualArea:area.integerValue
                saved:saved stale:NO status:@"Saved fixture" live:nil preview:nil];
            DMGuideActivityRow *row = presentationRow(context, guide, key);
            assert(!row.completed);
            assert(row.later != [name isEqualToString:@"ready"]);
            if ([name isEqualToString:@"locked"]) assert([row.access containsString:@"Not unlocked"]);
            else if (![name isEqualToString:@"ready"]) assert([row.access containsString:@"Access unknown"]);
        }
    }
    DMGuideSavedContext *delivered = [DMGuideSavedContext decode:fixtureData(root, @"presentation/delivered")];
    current = [DMGuidePresentation resolveSource:DMGuideSourceManual manualArea:DMGuideAreaHammerlocke
        saved:delivered stale:NO status:@"Saved fixture" live:nil preview:nil];
    DMGuideActivityRow *letter = presentationRow(current, guide, @"hammerlocke.letter-return");
    assert(!letter.later && !letter.completed && [letter.relatedAreas containsObject:@(DMGuideAreaBallonlea)]);
    DMGuideActivityRow *manual = presentationRow(current, guide, @"hammerlocke.applin");
    [guide setChecked:YES forActivity:manual.activity];
    assert(presentationRow(current, guide, manual.activity.key).completed);
    [guide setChecked:NO forActivity:manual.activity];
    assert(!presentationRow(current, guide, manual.activity.key).completed);
    current = [DMGuidePresentation resolveSource:DMGuideSourceManual manualArea:DMGuideAreaWeald
        saved:save stale:NO status:@"Saved fixture" live:nil preview:nil];
    for (DMGuideActivityRow *row in [current rowsWithGuide:guide query:@"" incompleteOnly:NO])
        assert(row.completed || row.later); // Opening access cannot establish the deep forest.
    assert([[DMGuidePresentation servicesInArea:DMGuideAreaHulbury].description containsString:@"incense"]);
    [defaults removePersistentDomainForName:suite];
    puts("PASS: shared presentation sources, live/save mismatch, stale/manual/archive isolation, access unknown versus locked, filters and related areas");
}

static void testReleaseJourneys(NSString *root) {
    NSArray<NSDictionary *> *steps = [NSJSONSerialization JSONObjectWithData:fixtureData(root, @"release-journeys.json") options:0 error:nil];
    assert(steps.count == 16);
    NSString *suite = [@"nxnative.release-journeys." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    DMShieldGuide *guide = [[DMShieldGuide alloc] initWithDefaults:defaults];
    for (NSDictionary *step in steps) {
        DMGuideSavedContext *save = [DMGuideSavedContext decode:fixtureData(root, step[@"fixture"])];
        assert(save);
        DMGuidePresentation *context = [DMGuidePresentation resolveSource:DMGuideSourceManual
            manualArea:[step[@"area"] integerValue] saved:save stale:NO status:@"Based on your last save" live:nil preview:nil];
        NSArray<DMGuideActivityRow *> *rows = [context rowsWithGuide:guide query:step[@"title"] incompleteOnly:NO];
        DMGuideActivityRow *found = nil;
        for (DMGuideActivityRow *row in rows) if ([row.activity.key isEqual:step[@"key"]]) found = row;
        assert(found && [found.activity.title isEqual:step[@"title"]]);
        if (![found.status isEqual:step[@"status"]]) NSLog(@"Journey %@: %@", step[@"name"], found.status);
        assert([found.status isEqual:step[@"status"]] && found.completed == [step[@"completed"] boolValue]);
        NSString *group = found.completed ? @"completed" : found.later ? @"later" : @"nearby";
        assert([group isEqual:step[@"group"]]);
    }
    for (NSString *name in @[@"waiting", @"respawned"]) {
        DMGuideSavedContext *save = [DMGuideSavedContext decode:fixtureData(root, [@"rehearsal/sparkle-" stringByAppendingString:name])];
        NSString *summary = [DMGuideSavedContext wildSparklesInArea:DMGuideAreaWildArea subarea:0 savedContext:save].firstObject;
        assert([summary hasPrefix:[name isEqual:@"waiting"] ? @"1 of 14" : @"0 of 14"]);
    }
    [defaults removePersistentDomainForName:suite];
    puts("PASS: 16 shared release journey contracts and recurring sparkle restore");
}

static void testSyntheticFixtures(NSString *root) {
    testReleaseJourneys(root);
    testPresentation(root);
    testSyntheticMonitor([root stringByAppendingPathComponent:@"monitor"]);
    testSyntheticGifts([root stringByAppendingPathComponent:@"gifts"]);
    testFirstHopWin([root stringByAppendingPathComponent:@"first-hop"]);
    testRoute2HopWin([root stringByAppendingPathComponent:@"route2-hop"]);
    testFieldTrainerFlags([root stringByAppendingPathComponent:@"field-trainers"]);
    testDailyTracking([root stringByAppendingPathComponent:@"daily-tracking"]);
    testAmbiguousEvents([root stringByAppendingPathComponent:@"ambiguous-events"]);
    testGymChallenge([root stringByAppendingPathComponent:@"gyms"].fileSystemRepresentation);
    testPostgameProgress([root stringByAppendingPathComponent:@"postgame"].fileSystemRepresentation);
    testCafePrizes([root stringByAppendingPathComponent:@"cafe-prizes"].fileSystemRepresentation);
    testTeaEvolutions([root stringByAppendingPathComponent:@"tea-evolutions"].fileSystemRepresentation);
}

static void writeCatalog(NSString *path) {
    NSMutableArray *areas = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableDictionary *> *details = [NSMutableDictionary dictionary];
    void (^addRows)(NSString *, NSString *, NSArray *) = ^(NSString *family, NSString *group, NSArray *rows) {
        if (!rows.count) return;
        NSMutableDictionary *groups = details[family];
        if (!groups) details[family] = groups = [NSMutableDictionary dictionary];
        assert(!groups[group]);
        groups[group] = rows;
    };
    NSMutableArray<DMGuideSavedContext *> *avatars = [NSMutableArray array];
    for (NSNumber *avatar in @[@0, @1]) {
        DMGuideSavedContext *stock = [DMGuideSavedContext new];
        [stock setValue:avatar forKey:@"wardrobeAvatar"];
        [stock setValue:[NSMutableData dataWithLength:0xF1C] forKey:@"wardrobeOwnership"];
        [stock setValue:[NSIndexSet indexSetWithIndex:1583] forKey:@"giftItems"]; // Include Style Card stock.
        [avatars addObject:stock];
    }
    NSArray<NSString *> *names = DMShieldGuide.areaNames;
    NSUserDefaults *catalogDefaults = [[NSUserDefaults alloc] initWithSuiteName:[@"shield-guide-catalog-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    DMShieldGuide *catalogGuide = [[DMShieldGuide alloc] initWithDefaults:catalogDefaults];
    for (DMGuideArea area = 0; area < (DMGuideArea)names.count; area++) {
        NSMutableArray *activities = [NSMutableArray array];
        DMGuidePresentation *presentation = [DMGuidePresentation resolveSource:DMGuideSourceManual manualArea:area
            saved:nil stale:NO status:@"Catalog reference" live:nil preview:nil];
        for (DMGuideActivityRow *row in [presentation rowsWithGuide:catalogGuide query:@"" incompleteOnly:NO]) {
            DMGuideActivity *activity = row.activity;
            [activities addObject:@{@"key": activity.key, @"title": activity.title, @"daily": @(activity.isDaily),
                @"hint": activity.hint, @"directions": activity.directions,
                @"accessWithoutSave": row.access, @"laterWithoutSave": @(row.later), @"relatedAreas": row.relatedAreas}];
        }
        [areas addObject:@{@"name": names[area], @"directions": [DMShieldGuide directionsInArea:area],
                           @"activities": activities, @"services": [DMGuidePresentation servicesInArea:area],
                           @"encounters": [DMShieldGuide encounterGroupsInArea:area]}];
        addRows(@"local-tms", names[area], [DMGuideSavedContext tmRowsInArea:area savedContext:nil]);
        addRows(@"cafe-prizes", names[area], [DMGuideSavedContext cafePrizeRowsInArea:area savedContext:nil]);
        if ([DMGuideSavedContext cafePrizeTitleInArea:area]) {
            addRows(@"cafe-saved-state", names[area], @[@"Last saved use flag", @"Next prize from saved roll"]);
        }
        [avatars enumerateObjectsUsingBlock:^(DMGuideSavedContext *stock, NSUInteger i, BOOL *stop) {
            for (DMGuideBoutiqueCategory *category in [DMGuideSavedContext boutiqueCategoriesInArea:area savedContext:stock]) {
                NSString *group = [NSString stringWithFormat:@"%@ / %@ / %@", names[area],
                    i == 0 ? @"Boy" : @"Girl", [category.title componentsSeparatedByString:@" · "].firstObject];
                addRows(@"boutique", group, category.items);
            }
        }];
        NSArray<NSString *> *subareas = [DMShieldGuide wildSubareasInArea:area];
        for (NSInteger index = 0; index < (NSInteger)subareas.count; index++) {
            NSString *subarea = subareas[index];
            addRows(@"wild-subarea-directions", subarea, @[[DMShieldGuide wildDirectionsInArea:area subarea:index]]);
            DMGuideSparkleMap *map = [DMGuideSavedContext wildSparkleMapInArea:area subarea:index savedContext:nil];
            NSMutableArray *spots = [NSMutableArray array];
            for (DMGuideSparkleSpot *spot in map.spots)
                [spots addObject:@{@"title": spot.title, @"directions": spot.denReference, @"nearestDen": @(spot.nearestDen)}];
            addRows(@"sparkle-spots", subarea, spots);
            addRows(@"sparkle-reward-groups", subarea, [DMGuideSavedContext wildSparklesInArea:area subarea:index savedContext:nil]);
            addRows(@"raid-dens", subarea, [DMShieldGuide raidDensInArea:area subarea:index]);
            [DMShieldGuide.wildWeatherNames enumerateObjectsUsingBlock:^(NSString *weather, NSUInteger i, BOOL *stop) {
                NSString *group = [NSString stringWithFormat:@"%@ / %@", subarea, weather];
                addRows(@"wild-encounter-groups", group, [DMShieldGuide wildEncountersInArea:area subarea:index weather:(NSInteger)i]);
            }];
        }
    }
    addRows(@"tm-case", @"TM00–TM99", [DMGuideSavedContext tmRowsInArea:DMGuideAreaUnknown savedContext:nil]);
    addRows(@"technical-records", @"TR00–TR99", [DMGuideSavedContext trRowsWithSavedContext:nil]);
    addRows(@"gyms", @"Shield", [DMGuideSavedContext gymChallengeRowsWithSavedContext:nil]);
    addRows(@"postgame-stadiums", @"Shield", [DMGuideSavedContext postgameStadiumRowsWithSavedContext:nil]);
    addRows(@"league-cards", @"Base album", [DMGuideSavedContext leagueCardAlbumRowsWithSavedContext:nil]);
    NSArray<NSString *> *cardMaker = [DMGuideSavedContext cardMakerRowsWithSavedContext:nil];
    addRows(@"card-maker-reference", @"Card Maker", @[cardMaker.firstObject]);
    addRows(@"card-maker", @"Unlocks", [cardMaker subarrayWithRange:NSMakeRange(1, cardMaker.count - 1)]);
    addRows(@"uniforms", @"Wardrobe", [DMGuideSavedContext uniformWardrobeRowsWithSavedContext:nil]);
    addRows(@"rotom", @"Appliances", [DMGuideSavedContext rotomFormRowsWithSavedContext:nil]);
    addRows(@"gigantamax", @"Base Galar species", [DMGuideSavedContext gigantamaxRowsWithSavedContext:nil]);
    NSArray<NSString *> *tea = [DMGuideSavedContext teaEvolutionRowsWithSavedContext:nil];
    addRows(@"tea-reference", @"Sinistea evolutions", @[tea.firstObject]);
    addRows(@"tea", @"Sinistea evolutions", [tea subarrayWithRange:NSMakeRange(1, tea.count - 1)]);
    addRows(@"memories", @"Types", [DMGuideSavedContext silvallyMemoryRowsWithSavedContext:nil]);
    addRows(@"camping-rewards", @"Camping King", [DMGuideSavedContext campingRewardsWithSavedContext:nil]);
    addRows(@"market-stock", @"Bargain offers", [DMGuideSavedContext stowBargainStock]);
    addRows(@"market-stock", @"Buyer prices", [DMGuideSavedContext stowBuyerPrices]);
    addRows(@"market-saved-state", @"Street Market", @[@"Saved stock and purchase state", @"Saved request and sale state"]);
    [[DMGuideSavedContext alcremieSweetTitlesWithSavedContext:nil] enumerateObjectsUsingBlock:^(NSString *sweet, NSUInteger i, BOOL *stop) {
        NSArray<NSString *> *rows = [DMGuideSavedContext alcremieRowsForSweet:(NSInteger)i savedContext:nil];
        addRows(@"alcremie-sweets", sweet, @[rows.firstObject]);
        addRows(@"alcremie", sweet, [rows subarrayWithRange:NSMakeRange(1, rows.count - 1)]);
    }];
    [DMGuideSavedContext.curryRecipeGroups enumerateObjectsUsingBlock:^(NSString *group, NSUInteger i, BOOL *stop) {
        addRows(@"curry-dex", group, [DMGuideSavedContext curryRecipesInGroup:(NSInteger)i savedContext:nil]);
    }];
    [[DMGuideSavedContext galarDexRangesWithSavedContext:nil] enumerateObjectsUsingBlock:^(NSString *range, NSUInteger i, BOOL *stop) {
        NSMutableArray *rows = [NSMutableArray array];
        for (DMGuideGalarDexEntry *entry in [DMGuideSavedContext galarDexRowsInRange:(NSInteger)i missingOnly:NO savedContext:nil])
            [rows addObject:@{@"number": @(entry.number), @"species": entry.species}];
        addRows(@"galar-dex", range, rows);
    }];
    for (NSNumber *doubles in @[@NO, @YES]) {
        NSString *format = doubles.boolValue ? @"Doubles" : @"Singles";
        addRows(@"battle-tower-rank", format, [DMGuideSavedContext battleTowerRankRewardsForDoubles:doubles.boolValue savedContext:nil]);
        addRows(@"battle-tower-win", format, [DMGuideSavedContext battleTowerWinRewardsForDoubles:doubles.boolValue repeating:NO savedContext:nil]);
        addRows(@"battle-tower-cycle", format, [DMGuideSavedContext battleTowerWinRewardsForDoubles:doubles.boolValue repeating:YES savedContext:nil]);
    }
    NSMutableArray *reference = [NSMutableArray array];
    for (DMGuideReferenceEntry *entry in DMShieldReference.allEntries) {
        [reference addObject:@{@"key": entry.key, @"category": entry.category, @"title": entry.title,
            @"body": entry.body, @"citation": entry.citation}];
    }
    assert([DMShieldReference entriesInCategory:@"Moves" query:@""].count == 547);
    assert([DMShieldReference entriesInCategory:@"Abilities" query:@"mOxIe"].count == 1);
    assert([DMShieldReference entriesInCategory:@"" query:@"   \n"].count == reference.count);
    assert([DMShieldReference entriesInCategory:@"" query:@"reference-no-such-entry-xyz"].count == 0);
    assert([DMShieldReference entriesInCategory:@"Natures" query:@"Adamant Dry"].count == 1);
    assert([DMShieldReference entriesInCategory:@"Berry trees" query:@"Rolling Fields Oran"].count == 2);
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"areas": areas, @"details": details, @"reference": reference}
        options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    assert([json writeToFile:path atomically:YES]);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        assert(dm_shield_guide_available());
        if (argc == 3 && !strcmp(argv[1], "--catalog")) {
            writeCatalog(@(argv[2]));
            return 0;
        }
        testLiveLocation();
        testActivityEvidence();
        testAutomaticCompletion();
        testCardMakerOverview();
        testTMReference();
        testTRReference();
        testBattleTowerRewardReference();
        testRotomFormReference();
        testGigantamaxReference();
        testAlcremieReference();
        testCafePrizeReference();
        testStowMarketReference();
        testTeaEvolutionReference();
        testSilvallyMemoryReference();
        testQuestCompletion();
        assert(![DMGuideSavedContext decode:NSData.data]);
        assert(![DMGuideSavedContext decode:[NSMutableData dataWithLength:128]]);
        assert(!DMGuideOpeningObjective(270));
        assert(DMGuideOpeningObjective(365) && DMGuideOpeningObjective(431) && DMGuideOpeningObjective(521));
        assert(!DMGuideOpeningObjective(410));
        assert([DMGuideOpeningObjective(646) isEqualToString:@"Meet Nessa at the lighthouse."]);
        assert(!DMGuideOpeningObjective(660));
        NSInteger objectiveCount = 0;
        for (NSInteger token = 0; token <= 10004; token++)
            if (DMGuideOpeningObjective(token)) objectiveCount++;
        assert(objectiveCount == 120);
        assert([DMGuideOpeningObjective(3181) isEqualToString:@"Face Zamazenta."]);
        assert(DMShieldGuide.areaNames.count == 31);
        NSString *route2Text = [[DMShieldGuide encounterGroupsInArea:DMGuideAreaRoute2] componentsJoinedByString:@"\n"];
        assert([route2Text containsString:@"Lotad"] && ![route2Text containsString:@"Seedot"]);
        assert([route2Text containsString:@"Far shore, water bike required · Fishing: Chewtle, Magikarp, Feebas"]);
        NSString *hulbury = [[DMShieldGuide encounterGroupsInArea:DMGuideAreaHulbury] componentsJoinedByString:@"\n"];
        assert([hulbury containsString:@"Blue-Striped Form"] && ![hulbury containsString:@"Red-Striped Form"]);
        assert([DMShieldGuide encounterGroupsInArea:DMGuideAreaUnknown].count == 0);
        assert(![DMGuideSavedContext new].missingGalarSpecies);
        assert(![DMShieldGuide encounterGroupsInArea:DMGuideAreaWeald matchingSpecies:[NSSet set]].count);
        NSString *formRoute = [[DMShieldGuide encounterGroupsInArea:DMGuideAreaRoute4
            matchingSpecies:[NSSet setWithArray:@[@"Meowth", @"Pumpkaboo"]]] componentsJoinedByString:@"\n"];
        assert([formRoute containsString:@"Galarian Meowth, Pumpkaboo (all four sizes)"]);
        assert(![formRoute containsString:@"Eevee"]);
        NSSet<NSString *> *growlithe = [NSSet setWithObject:@"Growlithe"];
        NSString *filteredWild = [[DMShieldGuide wildEncountersInArea:DMGuideAreaWildArea subarea:0 weather:4
            matchingSpecies:growlithe] componentsJoinedByString:@"\n"];
        assert([filteredWild containsString:@"Growlithe"] && ![filteredWild containsString:@"Bunnelby"]);
        assert(![DMShieldGuide wildEncountersInArea:DMGuideAreaWildArea subarea:0 weather:0 matchingSpecies:growlithe].count);
        NSArray<NSString *> *filteredRaid = [DMShieldGuide raidEncountersInArea:DMGuideAreaWildArea
            subarea:0 den:1 rare:NO stars:1 matchingSpecies:[NSSet setWithObject:@"Diglett"]];
        assert([filteredRaid isEqualToArray:@[@"Diglett · 35%"]]);
        assert([DMShieldGuide wildSubareasInArea:DMGuideAreaWildArea].count == 9);
        assert([DMShieldGuide wildSubareasInArea:DMGuideAreaNorthWild].count == 8);
        assert(DMShieldGuide.wildWeatherNames.count == 9);
        NSString *clear = [[DMShieldGuide wildEncountersInArea:DMGuideAreaWildArea subarea:0 weather:0] componentsJoinedByString:@"\n"];
        NSString *sun = [[DMShieldGuide wildEncountersInArea:DMGuideAreaWildArea subarea:0 weather:4] componentsJoinedByString:@"\n"];
        assert([clear containsString:@"Combee (Lv. 7–10)"] && ![clear containsString:@"Growlithe"]);
        assert([sun containsString:@"Growlithe"] && ![sun containsString:@"Vulpix"]);
        assert([clear containsString:@"Berry trees"] && [sun containsString:@"Berry trees"]);
        assert([clear containsString:@"Onix (Lv. 26)"]);
        assert([clear containsString:@"Strong wanderers · after becoming Champion\nDubwool (Lv. 65)"]);
        NSString *storm = [[DMShieldGuide wildEncountersInArea:DMGuideAreaWildArea subarea:0 weather:3] componentsJoinedByString:@"\n"];
        assert([storm containsString:@"Manectric (Lv. 26)"] && ![clear containsString:@"Manectric (Lv. 26)"]);
        assert(![DMShieldGuide wildEncountersInArea:DMGuideAreaWildArea subarea:9 weather:0].count);
        assert(![DMShieldGuide wildEncountersInArea:DMGuideAreaWildArea subarea:0 weather:9].count);
        assert(![DMShieldGuide wildEncountersInArea:DMGuideAreaRoute2 subarea:0 weather:0].count);
        assert([[DMShieldGuide raidEncountersInArea:DMGuideAreaWildArea subarea:0 den:1 rare:NO stars:1]
            containsObject:@"Diglett · 35%"]);
        assert(![[DMShieldGuide raidEncountersInArea:DMGuideAreaWildArea subarea:0 den:1 rare:YES stars:1]
            containsObject:@"Diglett · 35%"]);
        assert([[DMShieldGuide raidEncountersInArea:DMGuideAreaWildArea subarea:0 den:3 rare:YES stars:5]
            containsObject:@"Butterfree (Gigantamax) · 10%"]);
        assert(![DMShieldGuide raidEncountersInArea:DMGuideAreaWildArea subarea:1 den:3 rare:YES stars:5].count);
        assert(![DMShieldGuide raidEncountersInArea:DMGuideAreaWildArea subarea:0 den:3 rare:YES stars:6].count);
        assert(![DMShieldGuide raidDensInArea:DMGuideAreaRoute2 subarea:0].count);
        assert(![DMShieldGuide raidMapInArea:DMGuideAreaRoute2 subarea:0]);
        assert(![DMShieldGuide raidMapInArea:DMGuideAreaWildArea subarea:9]);
        assert(![DMGuideSavedContext wildSparklesInArea:DMGuideAreaRoute2 subarea:0 savedContext:nil].count);
        assert(![DMGuideSavedContext wildSparklesInArea:DMGuideAreaWildArea subarea:9 savedContext:nil].count);
        NSMutableSet<NSNumber *> *raidDens = [NSMutableSet set];
        NSUInteger sparkleSpots = 0;
        for (NSNumber *wildArea in @[@(DMGuideAreaWildArea), @(DMGuideAreaNorthWild)]) {
            DMGuideArea area = (DMGuideArea)wildArea.integerValue;
            for (NSInteger subarea = 0; subarea < (NSInteger)[DMShieldGuide wildSubareasInArea:area].count; subarea++) {
                for (NSInteger weather = 0; weather < (NSInteger)DMShieldGuide.wildWeatherNames.count; weather++)
                    assert([DMShieldGuide wildEncountersInArea:area subarea:subarea weather:weather].count);
                NSArray<NSString *> *sparkles = [DMGuideSavedContext wildSparklesInArea:area
                    subarea:subarea savedContext:nil];
                assert(sparkles.count > 1 && [sparkles.firstObject hasSuffix:@"Full save status unavailable"]);
                NSUInteger subareaSpots = 0;
                for (NSString *group in [sparkles subarrayWithRange:NSMakeRange(1, sparkles.count - 1)])
                    subareaSpots += [group componentsSeparatedByString:@" · "].lastObject.integerValue;
                assert(subareaSpots > 0 && subareaSpots == (NSUInteger)sparkles.firstObject.integerValue);
                sparkleSpots += subareaSpots;
                NSArray<NSNumber *> *dens = [DMShieldGuide raidDensInArea:area subarea:subarea];
                assert(dens.count);
                DMGuideSparkleMap *sparkleMap = [DMGuideSavedContext wildSparkleMapInArea:area
                    subarea:subarea savedContext:nil];
                assert(sparkleMap.spots.count == subareaSpots);
                NSMutableSet<NSString *> *spotTitles = [NSMutableSet set];
                for (DMGuideSparkleSpot *spot in sparkleMap.spots) {
                    assert([dens containsObject:@(spot.nearestDen)] && spot.denReference.length);
                    assert([spot.saveStatus isEqualToString:@"Save status unavailable"]);
                    assert(![spotTitles containsObject:spot.title]);
                    [spotTitles addObject:spot.title];
                }
                DMGuideRaidMap *map = [DMShieldGuide raidMapInArea:area subarea:subarea];
                assert(map.markers.count == dens.count && map.aspectRatio > 0);
                CGSize mapSize = CGSizeMake(250, 250 / map.aspectRatio);
                NSArray<DMGuideRaidMapMarker *> *pins = [map markersLaidOutInSize:mapSize];
                assert(pins.count == dens.count);
                for (NSUInteger i = 0; i < pins.count; i++) {
                    assert(pins[i].den == dens[i].integerValue && map.markers[i].den == pins[i].den);
                    CGPoint anchor = map.markers[i].position, pin = pins[i].position;
                    assert(anchor.x > 0 && anchor.x < 1 && anchor.y > 0 && anchor.y < 1);
                    assert(pin.x >= 13 && pin.x <= mapSize.width - 13 && pin.y >= 12 && pin.y <= mapSize.height - 12);
                    for (NSUInteger j = 0; j < i; j++) {
                        CGPoint other = pins[j].position;
                        assert(fabs(pin.x - other.x) >= 26 || fabs(pin.y - other.y) >= 24);
                    }
                }
                for (NSNumber *den in dens) {
                    assert(![raidDens containsObject:den]);
                    [raidDens addObject:den];
                    for (NSInteger stars = 1; stars <= 5; stars++) {
                        for (NSInteger rare = 0; rare <= 1; rare++) {
                            NSInteger total = 0;
                            for (NSString *entry in [DMShieldGuide raidEncountersInArea:area subarea:subarea
                                 den:den.integerValue rare:rare stars:stars])
                                total += [entry componentsSeparatedByString:@" · "].lastObject.integerValue;
                            assert(total == 100);
                        }
                    }
                }
            }
        }
        assert(raidDens.count == 99);
        assert(sparkleSpots == 229);
        NSUInteger curryRecipes = 0;
        for (NSUInteger i = 0; i < DMGuideSavedContext.curryRecipeGroups.count; i++)
            curryRecipes += [DMGuideSavedContext curryRecipesInGroup:i savedContext:nil].count;
        assert(curryRecipes == 151 && [DMGuideSavedContext campingRewardsWithSavedContext:nil].count == 10);
        assert([[DMGuideSavedContext curryRecipesInGroup:25 savedContext:nil] isEqualToArray:@[@"Gigantamax Curry"]]);
        assert(![DMGuideSavedContext curryRecipesInGroup:26 savedContext:nil].count);
        assert([DMGuideSavedContext galarDexRangesWithSavedContext:nil].count == 16);
        assert([[DMGuideSavedContext galarDexEntriesInRange:0 missingOnly:YES savedContext:nil].firstObject
            isEqualToString:@"001 Grookey"]);
        assert([[DMGuideSavedContext galarDexEntriesInRange:15 missingOnly:NO savedContext:nil].lastObject
            isEqualToString:@"400 Eternatus"]);
        assert(![DMGuideSavedContext galarDexEntriesInRange:16 missingOnly:NO savedContext:nil].count);
        DMGuideGalarDexEntry *lastDexEntry = [DMGuideSavedContext galarDexRowsInRange:15 missingOnly:NO savedContext:nil].lastObject;
        assert(lastDexEntry.number == 400 && [lastDexEntry.species isEqualToString:@"Eternatus"]);
        DMGuideEncounterLocations *chewtleLocations = [DMShieldGuide encounterLocationsForSpecies:@"Chewtle"];
        NSString *chewtleRoutes = [chewtleLocations.routes componentsJoinedByString:@"\n"];
        assert([chewtleRoutes containsString:@"Fishing on the near shore · Chewtle"]);
        assert([chewtleRoutes containsString:@"Far shore, water bike required · Fishing: Chewtle"]);
        DMGuideEncounterLocations *growlitheLocations = [DMShieldGuide encounterLocationsForSpecies:@"Growlithe"];
        NSString *growlitheWild = [growlitheLocations.wildArea componentsJoinedByString:@"\n"];
        assert([growlitheWild containsString:@"Rolling Fields"] && [growlitheWild containsString:@"Growlithe · Intense Sun"]);
        DMGuideEncounterLocations *diglettLocations = [DMShieldGuide encounterLocationsForSpecies:@"Diglett"];
        assert([[diglettLocations.raids componentsJoinedByString:@"\n"] containsString:@"Den 1 · Red beam · 1★"]);
        assert([DMShieldGuide encounterLocationsForSpecies:@"Togepi"].other.count);
        assert([[DMShieldGuide encounterLocationsForSpecies:@"Dracovish"].other.firstObject
            containsString:@"Fossilized Drake and Fossilized Fish"]);
        assert([[DMShieldGuide encounterLocationsForSpecies:@"Eternatus"].other.firstObject
            containsString:@"Champion Cup"]);
        for (NSInteger range = 0; range < 16; range++) {
            for (DMGuideGalarDexEntry *entry in [DMGuideSavedContext galarDexRowsInRange:range missingOnly:NO savedContext:nil]) {
                DMGuideEncounterLocations *locations = [DMShieldGuide encounterLocationsForSpecies:entry.species];
                if (!locations.routes.count && !locations.wildArea.count && !locations.raids.count && !locations.other.count) {
                    fprintf(stderr, "No acquisition hint for Galar Pokédex entry %ld %s\n", (long)entry.number, entry.species.UTF8String);
                    abort();
                }
            }
        }
        assert(!DMGuideHulburyDeliveryEvidence(@"hulbury.delivery-station", @11));
        assert(!DMGuideHulburyDeliveryEvidence(@"hulbury.delivery-swirlix", @4));
        assert([DMGuideHulburyDeliveryEvidence(@"hulbury.delivery-station", @2) isEqualToString:@"Order accepted"]);
        assert([DMGuideHulburyDeliveryEvidence(@"hulbury.delivery-station", @3) isEqualToString:@"Meal delivered · talk to the chef"]);
        assert([DMGuideHulburyDeliveryEvidence(@"hulbury.delivery-station", @6) isEqualToString:@"Chef follow-up recorded"]);
        assert([DMGuideHulburyDeliveryEvidence(@"hulbury.delivery-market", @9) isEqualToString:@"Meal delivered · talk to the chef"]);
        assert([DMGuideHulburyDeliveryEvidence(@"hulbury.delivery-market", @10) isEqualToString:@"Chef follow-up recorded"]);
        assert(!DMGuideMotostokeEvidence(@"motostoke.minccino-return", nil, nil, @YES));
        assert(!DMGuideMotostokeEvidence(@"motostoke.minccino-return", @4, nil, nil));
        assert([DMGuideMotostokeEvidence(@"motostoke.minccino-return", @1, nil, nil) isEqualToString:@"Search started"]);
        assert([DMGuideMotostokeEvidence(@"motostoke.minccino-return", @2, nil, nil) isEqualToString:@"Minccino returned"]);
        assert(!DMGuideMotostokeEvidence(@"motostoke.minccino-reward", @2, nil, @YES));
        assert(DMGuideMotostokeEvidence(@"motostoke.minccino-reward", @3, nil, nil));
        assert(DMGuideMotostokeEvidence(@"motostoke.trade", nil, @YES, nil));
        assert(!DMGuideMotostokeEvidence(@"motostoke.trade", @3, @NO, @YES));
        NSArray<DMGuideSnapshot *> *previews = DMShieldGuide.previews;
        assert(previews.count == 3);
        assert(previews[0].area == DMGuideAreaWedgehurst && previews[1].area == DMGuideAreaRoute2);
        assert(previews[0].mainPhase == 250 && previews[1].mainPhase == 250 && previews[2].mainPhase == 270);
        for (DMGuideSnapshot *preview in previews) {
            assert(preview.guidance == 250);
            assert([preview.objective isEqualToString:@"Go to meet the Pokémon Professor herself!"]);
        }
        assert([previews[2].party containsObject:@"Chewtle"] && [previews[2].party containsObject:@"Rookidee"]);

        NSString *suite = [@"nxnative.shield-guide-test." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        DMShieldGuide *guide = [[DMShieldGuide alloc] initWithDefaults:defaults];
        assert(guide.selectedArea == DMGuideAreaWedgehurst);
        guide.selectedArea = DMGuideAreaMotostoke;
        guide = [[DMShieldGuide alloc] initWithDefaults:defaults];
        assert(guide.selectedArea == DMGuideAreaMotostoke);

        NSMutableDictionary<NSString *, DMGuideActivity *> *activities = [NSMutableDictionary dictionary];
        for (NSUInteger area = 0; area < DMShieldGuide.areaNames.count; area++) {
            assert([DMShieldGuide directionsInArea:(DMGuideArea)area].length);
            for (DMGuideActivity *activity in [DMShieldGuide activitiesInArea:(DMGuideArea)area]) {
                DMGuideActivity *existing = activities[activity.key];
                if (existing) {
                    if ([activity.key isEqualToString:@"fashion.hairstyle"]) {
                        assert(area == DMGuideAreaHammerlocke || area == DMGuideAreaCirchester || area == DMGuideAreaWyndon);
                    } else if ([activity.key hasPrefix:@"rose-tower."]) {
                        assert(area == DMGuideAreaBattleTower);
                    } else {
                        assert(area == DMGuideAreaNorthWild);
                        assert([activity.key isEqualToString:@"wild-area.raid-battle"] ||
                               [activity.key isEqualToString:@"wild-area.first-raid"] ||
                               [activity.key isEqualToString:@"wild-area.bike-outfit"] ||
                               [activity.key isEqualToString:@"wild-area.chloe"] ||
                               [activity.key isEqualToString:@"wild-area.watt-find"] ||
                               [activity.key isEqualToString:@"nursery.hatch-egg"]);
                    }
                    assert([existing.title isEqualToString:activity.title] && [existing.hint isEqualToString:activity.hint] &&
                           [existing.directions isEqualToString:activity.directions]);
                }
                assert(activity.title.length && activity.hint.length && activity.directions.length);
                activities[activity.key] = activity;
            }
        }
        for (NSNumber *value in @[@(DMGuideAreaWildArea), @(DMGuideAreaNorthWild)]) {
            DMGuideArea area = (DMGuideArea)value.integerValue;
            NSArray<NSString *> *subareas = [DMShieldGuide wildSubareasInArea:area];
            for (NSUInteger index = 0; index < subareas.count; index++)
                assert([DMShieldGuide wildDirectionsInArea:area subarea:index].length);
            assert(![DMShieldGuide wildDirectionsInArea:area subarea:-1].length);
            assert(![DMShieldGuide wildDirectionsInArea:area subarea:subareas.count].length);
        }
        DMGuideActivity *returnMinccino = activities[@"motostoke.minccino-return"];
        DMGuideActivity *reward = activities[@"motostoke.minccino-reward"];
        DMGuideActivity *cafe = activities[@"motostoke.battle-cafe"];
        assert(returnMinccino && reward && cafe.isDaily);
        assert(activities[@"wedgehurst.birthday"] && activities[@"wedgehurst.revive"] && activities[@"wedgehurst.lab-potion"]);
        assert(activities[@"route1.first-catch"] && activities[@"route2.first-catch"]);
        assert(activities[@"route4.repel"] && activities[@"route4.energy-root"] &&
               activities[@"route4.x-accuracy"] && activities[@"route4.revival-herb"]);
        assert(activities[@"motostoke.hidden-nugget"] && activities[@"motostoke.steel-beam"] && activities[@"motostoke.marnie-smile"]);
        assert(activities[@"wild-area.poke-dolls"] && activities[@"route3.berry-gift"] && activities[@"turffield.riddle"]);
        assert(activities[@"wild-area.first-curry"] && activities[@"wild-area.camp-toys"] && activities[@"wild-area.golden-cookware"]);
        assert(activities[@"route5.toxel"] && activities[@"hulbury.trade"] && activities[@"hulbury.delivery-market"]);
        assert(activities[@"route6.fossil-revival"] && activities[@"route6.fossil.dracozolt"] &&
               activities[@"route6.fossil.arctozolt"] && activities[@"route6.fossil.dracovish"] &&
               activities[@"route6.fossil.arctovish"]);
        for (NSUInteger route = 3; route <= 10; route++) {
            NSString *key = [NSString stringWithFormat:@"route%lu.campsite-taxi", route];
            assert(activities[key]);
        }
        assert(activities[@"hulbury.maximizers"]);
        assert(activities[@"hammerlocke.letter-return"] && activities[@"ballonlea.letter"]);
        assert(activities[@"circhester.detective"] && activities[@"spikemuth.marnie-daily"].isDaily);
        assert(activities[@"postwick.charmander"] && activities[@"battle-tower.type-null"]);
        assert(activities[@"stow.phony-polteageist"] && activities[@"stow.antique-polteageist"]);
        assert(activities[@"battle-tower.memories"]);
        assert(activities[@"weald.postgame-epilogue"] && activities[@"power-plant.eternatus"] &&
               activities[@"power-plant.zamazenta"] && activities[@"turffield.postgame-stadium"]);
        assert(activities[@"hammerlocke.sonia-lock"] && activities[@"weald.sonia-book"] && activities[@"weald.sonia-shrine"]);
        assert(activities[@"route5.rotom-bike"] && activities[@"route9.bike-water-mode"] && activities[@"wild-area.bike-outfit"]);
        assert(activities[@"fashion.hairstyle"]);
        for (NSUInteger index = 0; index < shieldUniformCount; index++) {
            const ShieldUniform *uniform = &shieldUniforms[index];
            if (uniform->area != DMGuideAreaUnknown) {
                assert(activities[uniform->key]);
                assert([DMShieldGuide hasUniformWardrobeInArea:uniform->area]);
            }
        }
        assert(activities[@"route5.nursery-taxi"] && activities[@"north-wild.nursery-taxi"] && activities[@"nursery.hatch-egg"]);
        assert(activities[@"route5.nursery-deposit"] && activities[@"north-wild.nursery-deposit"] && activities[@"circhester.oval-charm"]);
        for (NSUInteger index = 0; index < sizeof(shieldCardBackgrounds) / sizeof(shieldCardBackgrounds[0]); index++)
            assert(activities[shieldCardBackgrounds[index].key]);
        for (NSUInteger index = 0; index < sizeof(shieldCardBackgroundTargets) / sizeof(shieldCardBackgroundTargets[0]); index++)
            assert(activities[shieldCardBackgroundTargets[index].key]);
        assert(activities[@"motostoke.gym-mission"] && activities[@"motostoke.gym-badge"] && activities[@"wyndon.champion-cup"]);
        assert(activities[@"north-wild.rally-thunder-wave"] && activities[@"north-wild.rally-volt-switch"] &&
               activities[@"north-wild.rally-fast-ball"] && activities[@"north-wild.bike-turbo"]);
        assert(activities[@"battle-tower.singles-master"] && activities[@"battle-tower.doubles-master"] &&
               activities[@"battle-tower.judge"] && activities[@"battle-tower.master-ribbon"]);
        assert(![guide isChecked:returnMinccino]);
        [guide setChecked:YES forActivity:returnMinccino];
        guide = [[DMShieldGuide alloc] initWithDefaults:defaults];
        assert([guide isChecked:returnMinccino] && ![guide isChecked:reward]);
        [guide setChecked:NO forActivity:returnMinccino];
        assert(![guide isChecked:returnMinccino]);

        [guide setChecked:YES forActivity:cafe];
        assert([guide isChecked:cafe]);
        [defaults setObject:@"2000-01-01" forKey:@"shieldGuide.checked.motostoke.battle-cafe"];
        assert(![guide isChecked:cafe]);
        [defaults removePersistentDomainForName:suite];
        puts("PASS: archive context, activity IDs, persistent checkoffs, separate Minccino stages and daily rollover");
        if (argc == 3 && !strcmp(argv[1], "--synthetic")) testSyntheticFixtures(@(argv[2]));
        if (argc == 4 && !strcmp(argv[1], "--quest")) testQuestArchive(argv[2], argv[3]);
        else if (argc == 4 && !strcmp(argv[1], "--hidden")) testHiddenPickups(argv[2], argv[3]);
        else if (argc == 4 && !strcmp(argv[1], "--curry")) testCurryDex(argv[2], argv[3]);
        else if (argc == 4 && !strcmp(argv[1], "--galar-dex")) testGalarDex(argv[2], argv[3]);
        else if (argc == 4 && !strcmp(argv[1], "--tower")) testBattleTower(argv[2], argv[3]);
        else if (argc == 4) testArchives(argv[1], argv[2], argv[3]);
        if (argc == 3 && !strcmp(argv[1], "--pokemon")) testPokemonProvenance(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--ribbons")) testRibbons(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--tutors")) testTutorMoves(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--gift-bag")) testGiftBag(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--town-rewards")) testTownRewards(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--wild-battles")) testWildBattles(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--fossils")) testFossilRecipes(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--station-and-ball-gifts")) testStationAndBallGifts(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--campsites")) testCampsiteProgress(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--league-cards")) testLeagueCards(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--postgame")) testPostgameProgress(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--sonia-and-applin")) testSoniaAndApplin(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--bike-unlocks")) testRotomBikeUnlocks(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--nurseries")) testNurseries(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--card-backgrounds")) testCardBackgrounds(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--uniform-wardrobe")) testUniformWardrobe(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--boutique-stock")) testBoutiqueStock(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--tm-case")) testTMCase(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--tr-inventory")) testTRInventory(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--past-rewards")) testPastRewards(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--tower-rewards")) testBattleTowerRewards(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--silvally-memories")) testSilvallyMemories(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--rotom-forms")) testRotomForms(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--gigantamax")) testGigantamaxCollection(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--alcremie")) testAlcremieCollection(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--cafe-prizes")) testCafePrizes(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--stow-market")) testStowMarket(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--tea-evolutions")) testTeaEvolutions(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--gyms")) testGymChallenge(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--cards-and-camping")) testCardsAndCamping(argv[2]);
        if (argc == 3 && !strcmp(argv[1], "--rally")) testRally(argv[2]);
        if (argc == 6 && !strcmp(argv[1], "--pickup")) testPickupArchives(argv[2], argv[3], argv[4], argv[5]);
    }
}
