#import "shield_guide.h"
#import "shield_guide_card_backgrounds.h"
#import "shield_guide_fossils.h"
#import "shield_guide_gyms.h"
#import "shield_guide_league_cards.h"
#import "shield_guide_postgame.h"
#import "shield_guide_uniforms.h"
#import <CoreText/CoreText.h>
#include "game_profile.h"
#include <string.h>
#include "shield_guide_reference.inc"

@interface DMGuideReferenceEntry ()
@property (nonatomic, readwrite, copy) NSString *key;
@property (nonatomic, readwrite, copy) NSString *category;
@property (nonatomic, readwrite, copy) NSString *title;
@property (nonatomic, readwrite, copy) NSString *body;
@property (nonatomic, readwrite, copy) NSString *citation;
@end
@implementation DMGuideReferenceEntry
@end

@implementation DMShieldReference
+ (NSArray<DMGuideReferenceEntry *> *)allEntries {
    static NSArray *entries;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSData *data = [NSData dataWithBytes:shieldReferenceJSON length:sizeof(shieldReferenceJSON) - 1];
        NSArray *rows = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSMutableArray *result = [NSMutableArray array];
        for (NSDictionary *row in rows) {
            DMGuideReferenceEntry *entry = [DMGuideReferenceEntry new];
            entry.key = row[@"key"]; entry.category = row[@"category"]; entry.title = row[@"title"];
            entry.body = row[@"body"]; entry.citation = row[@"citation"];
            [result addObject:entry];
        }
        entries = [result copy];
    });
    return entries;
}
+ (NSArray<NSString *> *)categories {
    static NSArray *categories;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableSet *names = [NSMutableSet set];
        for (DMGuideReferenceEntry *entry in self.allEntries) [names addObject:entry.category];
        categories = [[names allObjects] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    });
    return categories;
}
+ (NSArray<DMGuideReferenceEntry *> *)entriesInCategory:(NSString *)category query:(NSString *)query {
    NSArray *words = [query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *result = [NSMutableArray array];
    for (DMGuideReferenceEntry *entry in self.allEntries) {
        if (category.length && ![entry.category isEqualToString:category]) continue;
        NSString *text = [NSString stringWithFormat:@"%@ %@ %@ %@", entry.category, entry.title, entry.body, entry.citation];
        BOOL matches = YES;
        for (NSString *word in words) {
            if (word.length && [text rangeOfString:word options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location == NSNotFound) {
                matches = NO; break;
            }
        }
        if (matches) [result addObject:entry];
    }
    return result;
}
@end

bool dm_shield_guide_available(void) {
    return strcmp(DM_GAME_ID, "01008DB008C2C000") == 0;
}

NSString *DMGuideOpeningObjective(NSInteger token) {
    switch (token) {
        case 20: return @"Collect anything you need before leaving home.";
        case 25:
        case 30: return @"Go outside and meet Hop.";
        case 40: return @"Catch up with Hop at his house.";
        case 50: return @"Go to Wedgehurst to meet Leon.";
        case 81: return @"Choose your first partner Pokémon.";
        case 115: return @"Battle Hop.";
        case 130:
        case 180: return @"Tell your mum you’re heading to Wedgehurst.";
        case 140: return @"Look for the missing Wooloo in the Slumbering Weald.";
        case 142: return @"Continue deeper into the Slumbering Weald.";
        case 190: return @"Meet Hop on Route 1.";
        case 200: return @"Visit the Pokémon Research Lab in Wedgehurst.";
        case 215: return @"Explore Wedgehurst after visiting the lab.";
        case 220: return @"Visit the Pokémon Center in Wedgehurst.";
        case 240: return @"Head toward the professor’s house on Route 2.";
        case 250: return @"Go to meet the Pokémon Professor herself!";
        case 280: return @"Battle Hop near Professor Magnolia’s house.";
        case 340: return @"Return to Wedgehurst Station.";
        case 365: return @"Cross the Wild Area to Motostoke.";
        case 400: return @"Explore Motostoke.";
        case 412: return @"Head to Motostoke Stadium.";
        case 431: return @"Go to the Budew Drop Inn.";
        case 450: return @"Check in at the inn’s front desk.";
        case 471: return @"Return to Motostoke Stadium for the opening ceremony.";
        case 521: return @"Travel through Route 3 and Galar Mine toward Turffield.";
        case 570: return @"Meet Sonia by the Turffield geoglyph.";
        case 580: return @"Head to Turffield Stadium.";
        case 620: return @"Cross Route 5 to Hulbury.";
        case 640:
        case 680:
        case 700: return @"Explore Hulbury.";
        case 645:
        case 650: return @"Head to Hulbury Stadium.";
        case 646: return @"Meet Nessa at the lighthouse.";
        case 690: return @"Go to the seafood restaurant.";
        case 710: return @"Go through Galar Mine No. 2 toward Motostoke.";
        case 720: return @"Find Kabu in Galar Mine No. 2.";
        case 740: return @"Rest at the Budew Drop Inn.";
        case 760:
        case 770: return @"Return to Motostoke Stadium for the Fire Gym.";
        case 820:
        case 825: return @"Cross the northern Wild Area to Hammerlocke.";
        case 850: return @"Meet Rose at Hammerlocke Stadium.";
        case 880:
        case 890:
        case 900: return @"Go to the Hammerlocke vault.";
        case 910: return @"Take Route 6 to Stow-on-Side.";
        case 960: return @"Go to Stow-on-Side Stadium.";
        case 1010: return @"Explore Stow-on-Side.";
        case 1050:
        case 1070: return @"Investigate the mural overlooking Stow-on-Side.";
        case 1112: return @"Cross Glimwood Tangle to Ballonlea.";
        case 1115:
        case 1120: return @"Go to Ballonlea Stadium.";
        case 1150: return @"Explore Ballonlea.";
        case 1160:
        case 1410: return @"Return to Hammerlocke.";
        case 1170:
        case 1240: return @"Go to Circhester Stadium.";
        case 1260: return @"Explore Circhester.";
        case 1270: return @"Go to Circhester’s steak restaurant.";
        case 1280: return @"Meet up at the Hero’s Bath.";
        case 1300: return @"Follow Route 9 to Spikemuth.";
        case 1320: return @"Find the way into Spikemuth.";
        case 1325: return @"Head into Spikemuth.";
        case 1330: return @"Take on the Spikemuth Gym.";
        case 1390: return @"Explore Spikemuth.";
        case 1400: return @"Take the Route 9 Tunnel toward Hammerlocke.";
        case 1420: return @"Check in at Hammerlocke Stadium.";
        case 1422: return @"Battle Raihan’s Gym Trainers at the vault.";
        case 1430: return @"Challenge Raihan at Hammerlocke Stadium.";
        case 1440: return @"Explore Hammerlocke.";
        case 1450: return @"Catch the train at Hammerlocke Station.";
        case 1460: return @"Follow Route 10 to Wyndon.";
        case 1490:
        case 1510: return @"Check in at Wyndon Stadium.";
        case 1520:
        case 1680:
        case 1700:
        case 1705:
        case 1710:
        case 1720:
        case 1730:
        case 1790:
        case 10004: return @"Enter the Wyndon Stadium pitch when you’re ready.";
        case 1580: return @"Meet Piers outside the hotel.";
        case 1585: return @"Search around the monorail terminal for the staff member.";
        case 1600: return @"Take the lift to the top of Rose Tower.";
        case 1670: return @"Return to Wyndon Stadium.";
        case 1850: return @"Search the Slumbering Weald.";
        case 1870: return @"Find the relics at the Weald shrine.";
        case 1871: return @"Pick up the sword and shield.";
        case 1872: return @"Travel to Hammerlocke Stadium.";
        case 1880:
        case 1890:
        case 3150:
        case 3160: return @"Take the lift to the power plant beneath Hammerlocke Stadium.";
        case 1920:
        case 3170: return @"Head to the roof of Hammerlocke Stadium.";
        case 2030: return @"Return to Wyndon Stadium to face Leon.";
        case 3000: return @"Explore Galar as Champion.";
        case 3010: return @"Battle Hop in the Slumbering Weald.";
        case 3190: return @"Meet Hop in the Slumbering Weald.";
        case 3030: return @"Revisit the shrine in the Slumbering Weald.";
        case 3040:
        case 3095: return @"Go to the Pokémon Research Lab in Wedgehurst.";
        case 3050: return @"Investigate the incident at Turffield Stadium.";
        case 3070:
        case 3098: return @"Head outside to continue the investigation.";
        case 3080: return @"Investigate the Hulbury and Motostoke stadium incidents.";
        case 3100: return @"Investigate the Hammerlocke, Stow-on-Side, Ballonlea, and Circhester stadiums.";
        case 3165: return @"Battle Sordward.";
        case 3166: return @"Battle Shielbert.";
        case 3180: return @"Face Zacian.";
        case 3181: return @"Face Zamazenta.";
        case 3200: return @"Battle Hop.";
        case 10001: return @"Speak to Leon at Wyndon Stadium.";
        case 10002: return @"Choose a partner for the tournament.";
        case 10003: return @"Check in at the tournament front desk.";
        default: return nil;
    }
}

NSString *DMGuideMotostokeEvidence(NSString *key, NSNumber *stage, NSNumber *trade, NSNumber *fountain) {
    if ([key isEqualToString:@"motostoke.trade"] && trade.boolValue) return @"Trade recorded in save";
    if ([key isEqualToString:@"motostoke.fountain"] && fountain.boolValue) return @"Other fountain interaction recorded in save";
    if ([key isEqualToString:@"motostoke.minccino-return"]) {
        switch (stage.integerValue) {
            case 1: return @"Search started";
            case 2:
            case 3: return @"Minccino returned";
        }
    }
    if ([key isEqualToString:@"motostoke.minccino-reward"] && stage.integerValue == 3)
        return @"Reward conversation recorded";
    return nil;
}

static NSInteger hulburyDeliveryProgress(NSString *key, NSNumber *stage) {
    NSInteger work = stage.integerValue;
    if (work < 2 || work > 10) return -1;
    static NSArray<NSString *> *orders = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        orders = @[@"hulbury.delivery-station", @"hulbury.delivery-swirlix", @"hulbury.delivery-market"];
    });
    NSUInteger order = [orders indexOfObject:key];
    if (order == NSNotFound) return -1;
    NSInteger accepted = 2 + 3 * (NSInteger)order;
    return MIN(work - accepted, 2);
}

NSString *DMGuideHulburyDeliveryEvidence(NSString *key, NSNumber *stage) {
    switch (hulburyDeliveryProgress(key, stage)) {
        case 0: return @"Order accepted";
        case 1: return @"Meal delivered · talk to the chef";
        case 2: return @"Chef follow-up recorded";
        default: return nil;
    }
}

BOOL DMGuideHulburyDeliveryComplete(NSString *key, NSNumber *stage) {
    return hulburyDeliveryProgress(key, stage) == 2;
}

@interface DMGuideActivity ()
@property (nonatomic, copy, nullable) NSString *waterModeHint;
- (instancetype)initWithKey:(NSString *)key title:(NSString *)title hint:(NSString *)hint
                 directions:(NSString *)directions daily:(BOOL)daily;
@end

@implementation DMGuideActivity
- (instancetype)initWithKey:(NSString *)key title:(NSString *)title hint:(NSString *)hint
                 directions:(NSString *)directions daily:(BOOL)daily {
    if ((self = [super init])) {
        _key = [key copy];
        _title = [title copy];
        _hint = [hint copy];
        _directions = [directions copy];
        _daily = daily;
    }
    return self;
}
@end

@interface DMGuideSnapshot ()
- (instancetype)initWithTitle:(NSString *)title area:(DMGuideArea)area phase:(NSInteger)phase
                     guidance:(NSInteger)guidance nextStep:(NSString *)nextStep party:(NSArray<NSString *> *)party;
@end

@implementation DMGuideSnapshot
- (instancetype)initWithTitle:(NSString *)title area:(DMGuideArea)area phase:(NSInteger)phase
                     guidance:(NSInteger)guidance nextStep:(NSString *)nextStep party:(NSArray<NSString *> *)party {
    if ((self = [super init])) {
        _title = [title copy];
        _area = area;
        _mainPhase = phase;
        _guidance = guidance;
        _nextStep = [nextStep copy];
        _party = [party copy];
    }
    return self;
}
- (NSString *)objective {
    return DMGuideOpeningObjective(self.guidance);
}
@end

static DMGuideActivity *activity(NSString *key, NSString *title, NSString *hint, NSString *directions) {
    return [[DMGuideActivity alloc] initWithKey:key title:title hint:hint directions:directions daily:NO];
}

static DMGuideActivity *pickupAt(NSString *key, NSString *item, BOOL hidden, NSString *directions) {
    NSString *title = [NSString stringWithFormat:@"%@ · %@", item, hidden ? @"hidden pickup" : @"pickup"];
    return activity(key, title, hidden ? @"Look for a sparkle on the ground." : @"Look for an item ball.", directions);
}

static DMGuideActivity *trainerWin(NSString *key, NSString *trainer, NSString *landmark, NSString *team) {
    NSString *title = [@"Defeat " stringByAppendingString:trainer];
    return activity(key, title, landmark, team);
}

static DMGuideActivity *daily(NSString *key, NSString *title, NSString *hint, NSString *directions) {
    return [[DMGuideActivity alloc] initWithKey:key title:title hint:hint directions:directions daily:YES];
}

static DMGuideActivity *waterActivity(NSString *key, NSString *title, NSString *hint, NSString *directions) {
    DMGuideActivity *entry = activity(key, title, @"Unlock Water Mode on Route 9, then cross the water.", directions);
    entry.waterModeHint = hint;
    return entry;
}

static DMGuideActivity *cyclingOutfitActivity(void) {
    return activity(@"wild-area.bike-outfit", @"Try a type-themed cycling outfit", @"Ask a Rotom Rallyist for a makeover.",
        @"Put a Pokémon with the type you want at the front of your party. Select “A makeover!” and choose a type color. Choose “Rotom colors” to switch back to the default outfit.");
}

static DMGuideActivity *hatchEggActivity(void) {
    return activity(@"nursery.hatch-egg", @"Hatch a Pokémon Egg", @"Keep an Egg in your party as you travel.",
        @"Pick up an Egg from a Nursery worker and put it in your party. Walk or ride until it hatches. A party Pokémon with Flame Body or Steam Engine helps Eggs hatch faster.");
}

static NSArray<DMGuideActivity *> *wildAreaSharedActivities(void) {
    return @[
        activity(@"wild-area.raid-battle", @"Try a Max Raid", @"Look for a den with a beam of light.",
            @"Interact with a lit Pokémon Den and play through a Max Raid Battle."),
        activity(@"wild-area.first-raid", @"Clear your first Max Raid", @"Defeat the Dynamax Pokémon.",
            @"A saved raid catch checks this off automatically. If you win and leave without catching the Pokémon, check it off here."),
        activity(@"wild-area.chloe", @"Battle Pokémon Breeder Chloe", @"Chloe can appear on either side of the Wild Area.",
            @"Look in Rolling Fields, East Lake Axewell, Axew’s Eye, Giant’s Seat, Bridge Field, Stony Wilderness or Dusty Bowl. Chloe moves after a win. Before the Fire Badge she uses Grookey, Scorbunny and Sobble Lv. 13. Afterward she uses Raboot, Drizzile and Thwackey Lv. 30. After becoming Champion she uses Inteleon, Rillaboom and Cinderace Lv. 60. Mark your first win here."),
        activity(@"wild-area.watt-find", @"Buy a Hiker or Fisher’s find", @"Look for a Hiker or Fisher out in the Wild Area.",
            @"When a traveler offers an unknown item for 100 Watts, accept to buy it. This is separate from the Watt Traders’ shop.")
    ];
}

static NSArray<DMGuideActivity *> *fossilRecipeActivities(void) {
    NSMutableArray<DMGuideActivity *> *activities = [NSMutableArray arrayWithCapacity:fossilRecipeCount + 1];
    [activities addObject:activity(@"route6.fossil-revival", @"Try fossil revival",
        @"Bring two compatible fossil pieces to the researcher.",
        @"Speak to Cara Liss on the upper ledge and revive a Pokémon from two fossils.")];
    for (NSUInteger index = 0; index < fossilRecipeCount; index++) {
        const ShieldFossilRecipe *recipe = &fossilRecipes[index];
        NSString *title = [@"Register " stringByAppendingString:recipe->species];
        NSString *pair = [NSString stringWithFormat:@"%@ and %@", fossilPieceName(recipe->upperPiece),
                          fossilPieceName(recipe->lowerPiece)];
        [activities addObject:activity(recipe->key, title, pair,
            @"Speak to Cara Liss by the Route 6 campsite with both pieces. The Digging Duo in Bridge Field can help you find more fossils.")];
    }
    return activities;
}

static DMGuideActivity *campsiteTaxiStop(NSString *key, NSString *hint) {
    return activity(key, @"Campsite Flying Taxi stop", hint,
        @"Go to the campsite, then look for its Flying Taxi marker on the Town Map.");
}

static DMGuideActivity *waterPickup(NSString *key, NSString *item, BOOL hidden, NSString *directions) {
    NSString *title = [NSString stringWithFormat:@"%@ · %@", item, hidden ? @"hidden pickup" : @"pickup"];
    return waterActivity(key, title, hidden ? @"Look for a sparkle." : @"Look for an item ball.", directions);
}

#include "shield_guide_chapters.inc"

#include "shield_guide_raid_map.inc"

static BOOL encounterMatchesSpecies(NSString *name, NSSet<NSString *> *species) {
    if (!species) return YES;
    NSString *base = [name componentsSeparatedByString:@" ("].firstObject;
    if ([base hasPrefix:@"Galarian "]) base = [base substringFromIndex:@"Galarian ".length];
    return [species containsObject:base];
}

@interface DMGuideEncounterLocations ()
@property (nonatomic, copy, readwrite) NSArray<NSString *> *routes;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *wildArea;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *raids;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *other;
@end

@implementation DMGuideEncounterLocations
@end

@implementation DMShieldGuide {
    NSUserDefaults *_defaults;
}

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    if ((self = [super init])) _defaults = defaults;
    return self;
}

+ (NSArray<NSString *> *)areaNames {
    return @[@"Wedgehurst", @"Route 2", @"Motostoke", @"South Wild Area", @"Route 3", @"Galar Mine", @"Route 4", @"Turffield", @"Route 5", @"Hulbury",
        @"Galar Mine No. 2", @"Motostoke Outskirts", @"North Wild Area", @"Hammerlocke", @"Route 6", @"Stow-on-Side", @"Glimwood Tangle", @"Ballonlea", @"Route 7", @"Route 8", @"Circhester", @"Route 9", @"Spikemuth", @"Route 10", @"Wyndon", @"Rose Tower", @"Postwick", @"Route 1", @"Slumbering Weald", @"Hammerlocke Power Plant", @"Battle Tower"];
}

+ (NSArray<DMGuideSnapshot *> *)previews {
    static NSArray<DMGuideSnapshot *> *previews;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Normalized observations from the three labeled Shield 1.3.2 opening archives.
        previews = @[
            [[DMGuideSnapshot alloc] initWithTitle:@"Wedgehurst before Route 2" area:DMGuideAreaWedgehurst
                phase:250 guidance:250 nextStep:@"Take the uphill road out of Wedgehurst toward Route 2."
                party:@[@"Scorbunny"]],
            [[DMGuideSnapshot alloc] initWithTitle:@"Route 2 arrival" area:DMGuideAreaRoute2
                phase:250 guidance:250 nextStep:@"Follow the main path. Leon is ahead near the start of Route 2."
                party:@[@"Scorbunny"]],
            [[DMGuideSnapshot alloc] initWithTitle:@"Magnolia’s house approach" area:DMGuideAreaRoute2
                phase:270 guidance:250 nextStep:@"Continue to the house at the far end of Route 2 and speak to Professor Magnolia."
                party:@[@"Scorbunny", @"Chewtle", @"Rookidee"]]
        ];
    });
    return previews;
}

+ (NSString *)directionsInArea:(DMGuideArea)area {
    switch (area) {
        case DMGuideAreaUnknown: return @"";
        case DMGuideAreaWedgehurst:
            return @"Meet Leon at the purple-roofed research lab in the southeast. After Sonia adds the Pokédex, follow Hop uphill to the Pokémon Center. The stairs above the shops lead to Route 2. The Berry shop sells Cheri, Oran and Pecha Berries for 80 each. The Poké Mart starts selling Poké Balls after you meet Leon on Route 2.\n\n"
                @"After visiting Magnolia, meet Hop outside Wedgehurst Station for TM40 Swift. Go inside to see Mum for Camping Gear before taking the train.\n\n"
                @"After becoming Champion, go to Sonia’s lab after the shrine battle for the detector briefing. Start at Turffield Stadium, then visit Hulbury and Motostoke in either order. Return to the lab to join Hop against the brothers. Afterward, investigate Hammerlocke, Stow-on-Side, Ballonlea and Circhester in any order.";
        case DMGuideAreaRoute2:
            return @"Meet Leon by the first grass for 20 Poké Balls. He demonstrates catching if you haven’t caught one yet. Follow the path to Magnolia’s house, then speak to Hop in the yard for the endorsement battle. After the match, stay overnight for the Dynamax Band. Follow Hop back to Wedgehurst Station.\n\n"
                @"Fish from the near shore on your first visit. Return after the Route 9 bike upgrade to reach the island, far bank and river beyond the house.";
        case DMGuideAreaMotostoke:
            return @"On your first visit, follow Sonia into the lower Pokémon Center to learn about League Cards and Poké Jobs. Head north up the main street to the lift. Leon meets you at its base. Ride up to register at the stadium, then follow the League staff member west to the Budew Drop Inn.\n\n"
                @"At the inn, talk to Team Yell by the front desk. Expect Galarian Zigzagoon Lv. 9, then Nickit Lv. 9, then a double battle alongside Hop against both at Lv. 9. Fighting moves help against both. Check in after Marnie clears the lobby. In the morning, the staff member outside can escort you to the opening ceremony. The staff outside the stadium unlock Flying Taxi afterward. Head west to Route 3.\n\n"
                @"Fire Gym return from Hulbury\n"
                @"After meeting Kabu in the mine, heal at the upper Pokémon Center before going to the inn. Marnie offers a battle with Croagunk Lv. 24, Scraggy Lv. 24 and Morpeko Lv. 26. Ground moves help against Croagunk and Morpeko, and Fairy is strong against Scraggy. Rest at the inn, then head to the stadium in the morning.\n\n"
                @"In the postgame, talk to the Gym Leader at the stadium when Sonia asks you to investigate the incident.";
        case DMGuideAreaWildArea:
            return @"The train stops at Wild Area Station. Speak to Sonia at the fence outside to get the Pokémon Box Link, then head north through Rolling Fields and along the lakes to the giant stairs into Motostoke. The woman at the northeast side of the Meetup Spot heals your team. Give strong wanderers room as you cross.\n\n"
                @"Use the station to return to Wedgehurst. Trains to Motostoke become available after you reach the Budew Drop Inn. The Watt Trader appears by the fence after your first visit to Motostoke. Before earning a badge, you can catch wild Pokémon up to Lv. 20. Check your League Card for your current limit.";
        case DMGuideAreaRoute3:
            return @"Leave Motostoke to the west. Meet Sonia by the path overlooking the factory for an Escape Rope. Becca invites you into her camp farther along the route. The woman by the mine entrance heals your team.\n\n"
                @"For TM54, enter the mine and take the first branch off the tracks. Go past Worker Keith and take the side exit back to a ledge on Route 3.";
        case DMGuideAreaGalarMine:
            return @"Follow the tracks toward Route 4. The first side branch leads to Great Balls and a Route 3 ledge with TM54. The next branch leads to TM26. Near the far exit, Bede has Solosis Lv. 13, Gothita Lv. 15 and Hatenna Lv. 16. Bring Bug or Ghost coverage. Hatenna knows a Fairy move that can hit Dark types.";
        case DMGuideAreaRoute4:
            return @"Talk to the woman just outside Galar Mine to heal. Follow the main road between the fenced paddocks to meet Milo before Turffield. Explore the paddocks for Trainers and pickups. The fishing spot is east of the southeast paddock.";
        case DMGuideAreaTurffield:
            return @"Follow Yamper up the west hill to the geoglyph overlook. Sonia gives Milo’s League Card and two Revives there. Visit the stadium for the Grass Gym, then leave east toward the Route 5 Nursery. Return with Water Mode for the river and TM11.";
        case DMGuideAreaRoute5:
            return @"After the Grass Gym, take Turffield’s east exit and face the double battle near the first fork. Follow the north path to the Nursery or take the downhill loop past the camp and pond.\n\n"
                @"Help the doctor at the west end of the bridge. The Grunts use Galarian Zigzagoon Lv. 17 and Thievul Lv. 18, then Sableye Lv. 18. Fairy attacks help against all three. On the bridge, Hop uses Wooloo Lv. 18, Corvisquire Lv. 19 and the Lv. 21 evolved starter weak to yours. Then continue east to Hulbury.";
        case DMGuideAreaHulbury:
            return @"If the stadium is blocked, follow the harbor to the lighthouse and talk to Nessa, then return to the stadium. Bring Grass or Electric moves. Grass is especially effective against Drednaw.\n\n"
                @"Water Gym mission from its starting layout\n"
                @"1. Past the first Trainer, use red, yellow, then red again. Take the stairs.\n"
                @"2. Follow the outer platform past the next Trainer to yellow. Then use red and go up the next stairs.\n"
                @"3. Follow the platform west, then south to yellow. Go back up to red, use blue to the right, then descend to the central walkway and head for the finish.\n\n"
                @"After Nessa, Oleana meets you outside the stadium. Find Sonia and Rose at the Captain’s Table by the main street for TM79. Then head to the mine beyond the harbor. The restaurant deliveries become available after you become Champion.";
        default: return laterDirections(area);
    }
}

#include "shield_guide_encounters.inc"
#include "shield_guide_wild.inc"

static NSArray<NSString *> *otherLocationsForSpecies(NSString *species) {
    static const struct {
        __unsafe_unretained NSString *species;
        DMGuideArea area;
        __unsafe_unretained NSString *activityKey;
    } activities[] = {
        {@"Skwovet", DMGuideAreaMotostoke, @"motostoke.trade"},
        {@"Meowth", DMGuideAreaTurffield, @"turffield.trade"},
        {@"Cottonee", DMGuideAreaHulbury, @"hulbury.trade"},
        {@"Toxel", DMGuideAreaRoute5, @"route5.toxel"},
        {@"Togepi", DMGuideAreaHammerlocke, @"hammerlocke.trade"},
        {@"Impidimp", DMGuideAreaStow, @"stow.trade"},
        {@"Yamask", DMGuideAreaBallonlea, @"ballonlea.trade"},
        {@"Sawk", DMGuideAreaCirchester, @"circhester.trade"},
        {@"Mr. Mime", DMGuideAreaSpikemuth, @"spikemuth.trade"},
        {@"Duraludon", DMGuideAreaWyndon, @"wyndon.trade"},
        {@"Pikachu", DMGuideAreaWildArea, @"wild-area.lets-go-pikachu"},
        {@"Eevee", DMGuideAreaWildArea, @"wild-area.lets-go-eevee"},
        {@"Charmander", DMGuideAreaPostwick, @"postwick.charmander"},
        {@"Type: Null", DMGuideAreaBattleTower, @"battle-tower.type-null"},
    };
    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    for (size_t i = 0; i < sizeof(activities) / sizeof(activities[0]); i++) {
        if (![species isEqualToString:activities[i].species]) continue;
        DMGuideArea area = activities[i].area;
        for (DMGuideActivity *activity in [DMShieldGuide activitiesInArea:area]) {
            if ([activity.key isEqualToString:activities[i].activityKey])
                [rows addObject:[NSString stringWithFormat:@"%@\n%@\n%@",
                    DMShieldGuide.areaNames[area], activity.hint, activity.directions]];
        }
    }
    if ([@[@"Grookey", @"Scorbunny", @"Sobble"] containsObject:species])
        [rows addObject:@"Postwick\nChoose it as your first partner from Leon, or trade with another player."];
    for (NSUInteger index = 0; index < fossilRecipeCount; index++) {
        const ShieldFossilRecipe *recipe = &fossilRecipes[index];
        if ([species isEqualToString:recipe->species])
            [rows addObject:[NSString stringWithFormat:@"Route 6\nBring %@ and %@ to Cara Liss on the upper ledge.",
                fossilPieceName(recipe->lowerPiece), fossilPieceName(recipe->upperPiece)]];
    }
    if ([species isEqualToString:@"Eternatus"])
        [rows addObject:@"Energy Plant rooftop\nCatch Eternatus during the Champion Cup story."];
    if ([species isEqualToString:@"Zamazenta"])
        [rows addObject:@"Energy Plant rooftop\nReturn after the postgame stadium incidents to battle and catch Zamazenta."];
    if ([species isEqualToString:@"Zacian"])
        [rows addObject:@"Trade\nObtain Zacian by trading with another player. Its catch encounter is in Pokémon Sword."];

    NSArray<NSString *> *swordTrade = @[@"Seedot", @"Swirlix", @"Farfetch’d", @"Scraggy", @"Gothita",
        @"Rufflet", @"Mawile", @"Passimian", @"Turtonator", @"Solrock", @"Darumaka", @"Stonjourner",
        @"Deino", @"Jangmo-o"];
    if ([swordTrade containsObject:species]) {
        NSString *target = [@[@"Farfetch’d", @"Darumaka"] containsObject:species] ?
            [@"Galarian " stringByAppendingString:species] : species;
        [rows addObject:[NSString stringWithFormat:@"Trade\nTrade with a Pokémon Sword player for %@.", target]];
    }
    NSDictionary<NSString *, NSString *> *evolutions = @{
        @"Thwackey": @"Raise Grookey to level 16.",
        @"Rillaboom": @"Raise Thwackey to level 35.",
        @"Raboot": @"Raise Scorbunny to level 16.",
        @"Cinderace": @"Raise Raboot to level 35.",
        @"Drizzile": @"Raise Sobble to level 16.",
        @"Inteleon": @"Raise Drizzile to level 35.",
        @"Nuzleaf": @"Trade for Seedot from Sword and raise it to level 14.",
        @"Shiftry": @"Use a Leaf Stone on Nuzleaf.",
        @"Persian": @"Raise Kantonian Meowth to level 28. You can get one through the Turffield stadium trade.",
        @"Shedinja": @"Raise Nincada to level 20 with an empty party slot and a standard Poké Ball in the Bag.",
        @"Hitmonlee": @"Raise Tyrogue to level 20 with higher Attack than Defense.",
        @"Hitmonchan": @"Raise Tyrogue to level 20 with higher Defense than Attack.",
        @"Hitmontop": @"Raise Tyrogue to level 20 with equal Attack and Defense.",
        @"Pangoro": @"Raise Pancham to level 32 with a Dark-type Pokémon in the party.",
        @"Alcremie": @"Give Milcery a Sweet and spin in the field. Use the Alcremie collection in Route 4 or a Battle Café town for the flavor recipes.",
        @"Flapple": @"Use a Tart Apple on Applin. In Shield, trade for the Tart Apple from Sword.",
        @"Appletun": @"Use a Sweet Apple on Applin. Help the boy near the Hammerlocke vault or look for the sparkle by the tree on Axew’s Eye.",
        @"Slurpuff": @"Receive a Swirlix holding a Whipped Dream in a trade.",
        @"Sirfetch’d": @"Have Galarian Farfetch’d land three critical hits in one battle.",
        @"Scrafty": @"Trade for Scraggy from Sword and raise it to level 39.",
        @"Gothorita": @"Trade for Gothita from Sword and raise it to level 32.",
        @"Gothitelle": @"Raise Gothorita to level 41.",
        @"Escavalier": @"Receive a Karrablast in a trade for Shelmet. The Karrablast evolves on arrival.",
        @"Braviary": @"Trade for Rufflet from Sword and raise it to level 54.",
        @"Malamar": @"Raise Inkay to level 30 or higher while holding the Switch upside down. This action requires compatible motion input.",
        @"Weavile": @"Level up Sneasel at night while it holds a Razor Claw.",
        @"Runerigus": @"After Galarian Yamask takes at least 49 HP of damage from opposing attacks without fainting, walk beneath the stone arch in the Dusty Bowl.",
        @"Cofagrigus": @"Raise Unovan Yamask to level 34. You can get one through the Ballonlea stadium trade.",
        @"Polteageist": @"Use a Cracked Pot on Phony Sinistea or a Chipped Pot on Antique Sinistea. See Sinistea evolutions in Stow-on-Side or Glimwood Tangle.",
        @"Darmanitan": @"Use an Ice Stone on Galarian Darumaka.",
        @"Mantine": @"Level up Mantyke while Remoraid is in the party.",
        @"Goodra": @"Level up Sliggoo at level 50 or higher while it is raining in the overworld.",
        @"Silvally": @"Level up Type: Null with high friendship. The Battle Tower has a Type: Null gift.",
        @"Zweilous": @"Trade for Deino from Sword and raise it to level 50.",
        @"Hydreigon": @"Raise Zweilous to level 64.",
        @"Hakamo-o": @"Trade for Jangmo-o from Sword and raise it to level 35.",
        @"Kommo-o": @"Raise Hakamo-o to level 45.",
    };
    if (evolutions[species])
        [rows addObject:[@"Evolution\n" stringByAppendingString:evolutions[species]]];
    return rows;
}

+ (DMGuideEncounterLocations *)encounterLocationsForSpecies:(NSString *)species {
    NSSet<NSString *> *match = [NSSet setWithObject:species];
    NSArray<NSString *> *areas = self.areaNames;
    NSMutableArray<NSString *> *routes = [NSMutableArray array];
    for (NSUInteger area = 0; area < areas.count; area++) {
        NSArray<NSString *> *entries = [self encounterGroupsInArea:(DMGuideArea)area matchingSpecies:match];
        if (entries.count)
            [routes addObject:[NSString stringWithFormat:@"%@\n%@", areas[area], [entries componentsJoinedByString:@"\n"]]];
    }
    DMGuideEncounterLocations *locations = [DMGuideEncounterLocations new];
    locations.routes = routes;
    locations.wildArea = wildLocationsForSpecies(match);
    locations.raids = raidLocationsForSpecies(match, NO);
    locations.other = otherLocationsForSpecies(species);
    return locations;
}

static NSArray<DMGuideActivity *> *areaActivities(DMGuideArea area) {
    switch (area) {
        case DMGuideAreaUnknown: return @[];
        case DMGuideAreaWedgehurst:
            // Official guide, pp. 40–41, including the town item lists and the birthday conversation.
            return @[
                activity(@"wedgehurst.birthday", @"Register your birthday", @"Someone near the Pokémon Center has a question for you.",
                    @"Talk to the woman outside the Pokémon Center and confirm your birthday to register it. Stay to hear your fortune."),
                activity(@"wedgehurst.revive", @"A glint on the ground", @"Look for a sparkle as you head toward Route 2.",
                    @"Check the rock at the top of the stairs that lead to Route 2."),
                activity(@"wedgehurst.rare-candy", @"Rare Candy pickup", @"Look for item balls as you explore Wedgehurst.",
                    @"Look among the trees east of the Pokémon Research Lab. Check this off after collecting the Rare Candy."),
                activity(@"wedgehurst.poke-doll", @"Poké Doll pickup", @"Look for another item ball while exploring town.",
                    @"Follow the road past the Berry shop. Look for the item ball just west of the boutique."),
                activity(@"wedgehurst.lab-potion", @"A gift outside the lab", @"After meeting Sonia, look for a friendly passerby.",
                    @"Leave the Pokémon Research Lab after receiving the Pokédex. The passerby offers a Potion outside."),
                activity(@"wedgehurst.galarian-slowpoke", @"Catch the station’s Galarian Slowpoke",
                    @"Return to Wedgehurst Station after your first trip to the Wild Area.",
                    @"Speak to Avery inside the station. Approach the Lv. 12 Galarian Slowpoke after it wanders in. It reappears if you faint it or leave the battle. The encounter is available in Shield 1.3.2 without the Expansion Pass.")
            ];
        case DMGuideAreaRoute2:
            // Official guide, pp. 42–45.
            return @[
                activity(@"route2.first-catch", @"Catch a Pokémon on Route 2", @"Leon meets you near the grass to demonstrate catching.",
                    @"After meeting Leon, catch a wild Pokémon along Route 2."),
                activity(@"route2.jake", @"Defeat Youngster Jake", @"He waits on the main path after the early grass patches.",
                    @"Look below the Potion ledge and Trainer Tips sign. Jake uses Skwovet Lv. 6."),
                activity(@"route2.lauren", @"Defeat Lass Lauren", @"She watches the path beyond the Poké Ball ledge.",
                    @"Meet Lauren on the bend or go through the grass if you want to return later. She uses Chewtle Lv. 6."),
                activity(@"route2.benjamin", @"Defeat Youngster Benjamin", @"Look for the last Trainer before Magnolia’s house.",
                    @"Follow the main path toward the bridge. Benjamin uses Blipbug Lv. 5 and Nickit Lv. 7."),
                activity(@"route2.hop-win", @"Win Hop’s endorsement battle", @"Speak to Hop outside Magnolia’s house.",
                    @"Hop brings Wooloo Lv. 6, Rookidee Lv. 5 and the Lv. 8 starter weak to yours. Use Fighting moves on Wooloo if you have them and try Yamper’s Electric moves against Rookidee. Save after winning."),
                activity(@"route2.potion", @"Potions ×2 pickup", @"Look for an item ball by the main path.",
                    @"Pick up the item ball near the Trainer Tips sign, on the ledge east of Youngster Jake."),
                activity(@"route2.balls", @"Poké Balls ×3 pickup", @"Explore the edges of the main path.",
                    @"Climb the ledge along the middle stretch of the route to reach the item ball."),
                activity(@"route2.repel", @"Hidden Repel", @"Watch for sparkles along the route.",
                    @"Look for the sparkle on bare ground east of the grass patch before Magnolia’s house."),
                activity(@"route2.great-ball", @"Great Ball pickup", @"Search Magnolia’s garden.",
                    @"Walk along the west side of Magnolia’s house to the back of the garden."),
                activity(@"route2.payback", @"TM57 Payback pickup", @"There’s a narrow path by Magnolia’s house.",
                    @"Follow the passage behind the house to its far end."),
                activity(@"route2.fresh-water", @"Hidden Fresh Water", @"Check the flowerpots at Magnolia’s house.",
                    @"Look for a sparkle in the pot in front of the eastern crop plot."),
                waterPickup(@"route2.choice-band", @"Choice Band", NO, @"Ride east along the water from the bridge by Magnolia’s house."),
                waterPickup(@"route2.pp-max", @"PP Max", NO, @"Ride out to the island in the lake and look for the item ball."),
                waterPickup(@"route2.psycho-cut", @"TM69 Psycho Cut", NO, @"Cross to the northwest corner of the lake and look for the item ball."),
                waterPickup(@"route2.psychic-seed", @"Psychic Seed", NO, @"Follow the river south of Magnolia’s house and check the bank."),
                waterPickup(@"route2.rare-candy", @"Rare Candy", YES, @"Look for a sparkle on the lake island. It can reappear on a later day."),
                waterPickup(@"route2.prism-scale", @"Prism Scale", YES, @"Look for a sparkle on the water in the north part of the lake."),
                waterPickup(@"route2.max-ether", @"Max Ether", YES, @"Check for a sparkle by the bushes in the northwest corner of the lake."),
                waterPickup(@"route2.water-stone", @"Water Stone", YES, @"Ride down the river south of Magnolia’s house and check the sparkle at the end.")
            ];
        case DMGuideAreaMotostoke:
            // Official guide, pp. 28–29, 50–55 and 194. The Minccino quest stages use their own IDs.
            return @[
                activity(@"motostoke.trade", @"Pokémon Center trade", @"A Trainer in the lower Pokémon Center wants to trade.",
                    @"Bring a Bunnelby in your party to the girl near the lower Pokémon Center’s shop and exchange it for her Skwovet."),
                activity(@"motostoke.focus-energy", @"Record shop gift", @"Talk to people outside the record shops.",
                    @"Speak to the man outside the record shop on the west side of the main street for TR13 Focus Energy."),
                activity(@"motostoke.earbuds", @"Another record shop gift", @"There’s someone else to meet on the main street.",
                    @"Talk to the man outside the east-side record shop for the Hi-tech Earbuds."),
                activity(@"motostoke.leon-starter-gift", @"Leon’s gift for your starter", @"Approach the lift on your first visit.",
                    @"Meet Leon at the bottom of the lift before taking it to the stadium. He gives Miracle Seed for Grookey, Charcoal for Scorbunny or Mystic Water for Sobble."),
                activity(@"motostoke.hop-win", @"Win Hop’s battle by Route 3", @"After the opening ceremony, look near the west exit.",
                    @"Accept Hop’s challenge before leaving for Route 3. He uses Wooloo Lv. 11, Rookidee Lv. 12 and the Lv. 14 starter weak to yours. Try Fighting against Wooloo and Electric against Rookidee."),
                activity(@"motostoke.ball-guy", @"Meet Ball Guy", @"Look for the mascot near the stadium entrance.",
                    @"Talk to Ball Guy outside Motostoke Stadium. Ball Guy offers a Poké Ball."),
                activity(@"motostoke.star-piece", @"Budew Drop Inn gift", @"Try the rooms upstairs at the inn.",
                    @"After the opening ceremony, ride the inn elevator up and talk to the man in the far-left room for a Star Piece."),
                activity(@"motostoke.minccino-return", @"Find the missing Minccino", @"A boy near the Budew Drop Inn needs help finding his Pokémon.",
                    @"Accept the request, then whistle by pressing the left stick at the fountain to the left of the stadium. Check this off when Minccino returns."),
                activity(@"motostoke.minccino-reward", @"Follow up with Minccino’s owner", @"Visit the boy again after finding Minccino.",
                    @"Speak to him again after Minccino returns. He offers a Throat Spray."),
                activity(@"motostoke.fountain", @"The other fountain", @"Try this while you’re still looking for Minccino.",
                    @"Whistle at the fountain to the right of the stadium before returning Minccino. The man there offers Fresh Water."),
                activity(@"motostoke.pay-day", @"TM pickup", @"Explore the long staircase on the upper level.",
                    @"After the opening ceremony, head down the long stairs southeast of the upper Pokémon Center to find TM02 Pay Day."),
                [[DMGuideActivity alloc] initWithKey:@"motostoke.battle-cafe" title:@"Battle Café"
                    hint:@"The café offers a challenge each day."
                    directions:@"Find the café on the main street and speak to the café master by the counter. Check it off for today after the challenge."
                    daily:YES],
                activity(@"motostoke.marnie-smile", @"A scene at the Budew Drop Inn", @"Return to the inn after becoming Champion.",
                    @"Take the elevator and enter the leftmost upstairs room to see Marnie practicing with Morpeko."),
                activity(@"motostoke.steel-beam", @"A move tutor by the canals", @"Come back after you become Champion.",
                    @"Take the stairs toward the canal between Budew Drop Inn and the upper Pokémon Center. Bring a Steel-type Pokémon, Silvally, Zacian, or Zamazenta to learn Steel Beam."),
                activity(@"motostoke.poke-jobs", @"Try a Poké Job", @"Check Rotomi after Sonia’s introduction at the lower Pokémon Center.",
                    @"Use Rotomi in any Pokémon Center after the introduction. Send Box Pokémon that match the job’s preferred type. Return to the terminal when the job finishes for experience and possible rewards."),
                activity(@"motostoke.black-glasses", @"Black Glasses pickup", @"Check beside the Uniform Shop.",
                    @"Follow the narrow passage along the shop’s west wall to the end."),
                activity(@"motostoke.great-balls", @"Great Balls ×3 pickup", @"Go down to the canal.",
                    @"Follow the southwest canal walkway to the end."),
                activity(@"motostoke.silk-scarf", @"Silk Scarf pickup", @"Explore behind the upper Pokémon Center.",
                    @"Check beside the shipping containers southeast of the upper Pokémon Center."),
                activity(@"motostoke.burn-heals", @"Burn Heals ×3 pickup", @"Walk around the stadium lawn.",
                    @"Check behind the west fountain near the northwest corner of the lawn."),
                activity(@"motostoke.hidden-poke-ball", @"Recurring Poké Ball", @"Check a bin on the lower level.",
                    @"Go down the steps east of the lower Pokémon Center and check the trash bin. The Poké Ball can reappear on a later day."),
                activity(@"motostoke.hidden-nugget", @"Hidden Nugget", @"Look near the steam-powered gears.",
                    @"Take the steps west of the lower Pokémon Center and turn toward the gears before crossing the bridge."),
                activity(@"motostoke.hidden-revival-herb", @"Hidden Revival Herb", @"Check beside the Uniform Shop.",
                    @"Follow the walkway east of the shop to the tree with the hedge around it."),
                activity(@"motostoke.hidden-super-potion", @"Hidden Super Potion", @"Look below the street overpass.",
                    @"Check the base of the northwest support post."),
                activity(@"motostoke.hidden-paralyze-heals", @"Hidden Paralyze Heals ×2", @"Check by the lift.",
                    @"Look for a sparkle near the gear to the right of the lift at street level."),
                activity(@"motostoke.hidden-poke-doll", @"Hidden Poké Doll", @"Walk onto the bridge south of the upper Pokémon Center.",
                    @"Check the lawn next to the bench at the northeast end of the bridge."),
                activity(@"motostoke.hidden-x-accuracy", @"Hidden X Accuracy", @"Take the stairs south of the inn.",
                    @"Check the east side of the container parked against a roller door."),
                activity(@"motostoke.hidden-repel", @"Hidden Repel", @"Walk around the stadium lawn.",
                    @"Check the grass by the east fountain.")
            ];
        case DMGuideAreaWildArea:
            // Official guide, pp. 28 and 46–49.
            return [@[
                activity(@"wild-area.poke-dolls", @"Wild Area Station gift", @"Speak to the travelers inside the station.",
                    @"Talk to the backpacker with a Swinub near the station exit for five Poké Dolls."),
                activity(@"wild-area.lets-go-pikachu", @"A station gift for a returning Trainer", @"Requires compatible Let’s Go, Pikachu! save data recognized by the game.",
                    @"Talk to the girl on the west side of Wild Area Station to ask about a Gigantamax Pikachu."),
                activity(@"wild-area.lets-go-eevee", @"Another station gift for a returning Trainer", @"Requires compatible Let’s Go, Eevee! save data recognized by the game.",
                    @"Talk to the boy on the west side of Wild Area Station to ask about a Gigantamax Eevee."),
                activity(@"wild-area.first-berries", @"Gather Berries from a tree", @"Look for Berry trees away from the main path.",
                    @"Shake a Berry tree and stop before a Pokémon jumps out. You can come back another day."),
                activity(@"wild-area.first-curry", @"Cook your first curry", @"Use Pokémon Camp and bring a few Berries.",
                    @"Open Cooking in camp and finish a dish. Berries determine the flavor, and a main ingredient can change the dish."),
                activity(@"wild-area.camp-toys", @"Unlock the six bonus camp toys", @"Find the Camping King by the steps to Motostoke.",
                    @"Ask the Camping King to rate your Curry Dex after making 5, 10, 15, 30, 50 and 80 different kinds of curry."),
                activity(@"wild-area.golden-cookware", @"Unlock golden cookware", @"Fill your Curry Dex and return to the Camping King.",
                    @"Cook all 151 kinds of curry with any taste rating, then ask the Camping King to rate your Curry Dex."),
                cyclingOutfitActivity(),
                pickupAt(@"wild-area.tail-slap", @"TM84 Tail Slap · Rolling Fields", NO,
                    @"From the Meetup Spot, head west along the field edge to the den in the cliff hollow. Look inside the end of the dead log."),
                pickupAt(@"wild-area.white-herb", @"White Herb · Watchtower Ruins", NO,
                    @"Check the dead log southwest of the tower near the Dappled Grove border."),
                pickupAt(@"wild-area.max-revive", @"Max Revive · Watchtower Ruins", NO,
                    @"Climb the bluff to the ruins and check against the base of the tower."),
                pickupAt(@"wild-area.thunder-stone", @"Thunder Stone · North Lake Miloch", NO,
                    @"Look on the high eastern bank overlooking Giant’s Seat."),
                pickupAt(@"wild-area.leftovers", @"Leftovers · Giant’s Seat", NO,
                    @"Follow the east shore north past the rock spire. Check by the small tree in the northeast corner."),
                pickupAt(@"wild-area.bulldoze", @"TM81 Bulldoze · Giant’s Seat", NO,
                    @"From the footbridge, follow the east cliff wall around the rock spire."),
                waterActivity(@"wild-area.air-slash", @"TM95 Air Slash · Axew’s Eye", @"Cross to the island in Lake Axewell.",
                    @"Ride to Axew’s Eye and look for the item ball at the west end of the island.")
            ] arrayByAddingObjectsFromArray:wildAreaSharedActivities()];
        case DMGuideAreaRoute3:
            // Official guide, pp. 56–57.
            return @[
                trainerWin(@"route3.trainer-rei", @"Lass Rei",
                    @"Take the main path past the first grass out of Motostoke. You can go around her through the north grass.", @"Vulpix Lv. 12."),
                trainerWin(@"route3.trainer-hannah", @"Schoolgirl Hannah",
                    @"Follow the main path west of Rei toward the fork with the Trainer Tips sign.", @"Pancham Lv. 13."),
                trainerWin(@"route3.trainer-marvin", @"Schoolboy Marvin",
                    @"At the fork, head north to the grass before the factory overlook.", @"Budew Lv. 12, Gossifleur Lv. 12."),
                trainerWin(@"route3.trainer-kayleigh", @"Schoolgirl Kayleigh",
                    @"After Sonia, take the south branch to the ledge with the Berry tree and TM37.", @"Purrloin Lv. 12, Skwovet Lv. 13."),
                trainerWin(@"route3.trainer-tad", @"Postman Tad",
                    @"From the factory overlook, stay on the main path toward Becca’s camp.", @"Delibird Lv. 14."),
                trainerWin(@"route3.trainer-peter", @"Schoolboy Peter",
                    @"Follow the road past Becca’s camp toward the mine.", @"Sizzlipede Lv. 13, Dottler Lv. 14."),
                activity(@"route3.berry-gift", @"A Cheri Berry by the tent", @"Speak to the woman by the campsite.",
                    @"Talk to the woman outside the tent on the path to Galar Mine for a Cheri Berry."),
                campsiteTaxiStop(@"route3.campsite-taxi", @"Look for the tent along the path to Galar Mine."),
                pickupAt(@"route3.heal-balls", @"Heal Balls ×3", NO,
                    @"Cut through the first north grass patch from Motostoke and look by the ledge."),
                pickupAt(@"route3.beat-up", @"TM37 Beat Up", NO,
                    @"Follow the south branch past Schoolgirl Kayleigh to the ledge by the Berry tree."),
                pickupAt(@"route3.super-potion", @"Super Potion", NO,
                    @"Check the clearing in the grass south of the mine entrance."),
                pickupAt(@"route3.rock-blast", @"TM54 Rock Blast", NO,
                    @"Enter Galar Mine and take the first side branch past Worker Keith. Use its south exit onto the Route 3 ledge."),
                pickupAt(@"route3.big-mushroom", @"Big Mushroom", YES,
                    @"Check the tree above the first grass patch out of Motostoke."),
                pickupAt(@"route3.burn-heal", @"Burn Heal", YES,
                    @"At the first fork, check the dead end west of the Trainer Tips sign."),
                pickupAt(@"route3.revive", @"Revive", YES,
                    @"Check the rock on the northeast side of the hill around the Trainer Tips sign."),
                pickupAt(@"route3.x-defense", @"X Defense ×2", YES,
                    @"Check on the east side of the mine entrance.")
            ];
        case DMGuideAreaGalarMine:
            // Official guide, pp. 58–59 and 146.
            return @[
                trainerWin(@"galar-mine.trainer-keith", @"Worker Keith",
                    @"Take the first side branch from the Route 3 entrance. Look near the empty minecart.", @"Roggenrola Lv. 14."),
                trainerWin(@"galar-mine.trainer-georgia", @"Worker Georgia",
                    @"Take the second branch off the tracks, toward TM26.", @"Timburr Lv. 14 ×3."),
                trainerWin(@"galar-mine.trainer-sandra", @"Worker Sandra",
                    @"Follow the main tunnel to the near end of the bridge.", @"Diglett Lv. 14, Drilbur Lv. 15."),
                trainerWin(@"galar-mine.trainer-russel", @"Worker Russel",
                    @"Cross the bridge and turn right toward the gem cart and Heavy-Duty Boots.", @"Rolycoly Lv. 15."),
                pickupAt(@"galar-mine.great-balls", @"Great Balls ×3", NO,
                    @"Take the first branch past Keith. Follow it south, then double back into the side room to the east."),
                pickupAt(@"galar-mine.scary-face", @"TM26 Scary Face", NO,
                    @"Take the second branch west off the tracks and go past Worker Georgia to the end."),
                pickupAt(@"galar-mine.boots", @"Heavy-Duty Boots", NO,
                    @"Cross the bridge and check by the gem-filled cart to the right."),
                pickupAt(@"galar-mine.super-potions", @"Super Potions ×2", NO,
                    @"Follow the second stretch of minecart tracks and look east just beyond the bend."),
                pickupAt(@"galar-mine.star-piece", @"Star Piece", YES,
                    @"Check the gem cart across from the Route 3 entrance."),
                pickupAt(@"galar-mine.hard-stone", @"Hard Stone", YES,
                    @"Check the right wall before crossing the bridge."),
                pickupAt(@"galar-mine.ether", @"Ether", YES,
                    @"Cross the bridge and check by the crates on the west side."),
                activity(@"galar-mine.revives", @"Hidden Revives ×2", @"Look for two sparkles as you explore the mine.",
                    @"Check the empty cart at the first fork and the wheelbarrow just beyond the bridge."),
                activity(@"galar-mine.stardust", @"Hidden Stardust ×2", @"Look for two sparkles as you explore the mine.",
                    @"Check the crate along the north wall in Georgia’s tunnel and the crate near the Route 4 exit.")
            ];
        case DMGuideAreaRoute4:
            // Official guide, pp. 60–61.
            return @[
                trainerWin(@"route4.trainer-jaime", @"Pokémon Breeder Jaime",
                    @"Look by the entrance to the southeast paddock.", @"Galarian Meowth Lv. 14, Seedot Lv. 14, Butterfree Lv. 15."),
                trainerWin(@"route4.trainer-shane", @"Poké Kid Shane",
                    @"Go just inside the southeast paddock and look for the Pikachu costume.", @"Pikachu Lv. 15."),
                trainerWin(@"route4.trainer-bradley", @"Pokémon Breeder Bradley",
                    @"Follow the path between the two east paddocks toward the fishing spot.", @"Electrike Lv. 15, Lotad Lv. 15."),
                trainerWin(@"route4.trainer-mia", @"Poké Kid Mia",
                    @"Look for the Eevee costume near the northeast paddock entrance.", @"Eevee Lv. 15."),
                trainerWin(@"route4.trainer-rhys", @"Poké Kid Rhys",
                    @"Go to the southeast corner inside the northeast paddock, by TM07.", @"Joltik Lv. 14, Grubbin Lv. 14."),
                trainerWin(@"route4.trainer-sunny", @"Poké Kid Sunny",
                    @"Look just inside the northwest paddock, near the Diglett burrows.", @"Milcery Lv. 15."),
                campsiteTaxiStop(@"route4.campsite-taxi", @"Look for the camp as you travel through the fields toward Turffield."),
                pickupAt(@"route4.cleanse-tag", @"Cleanse Tag", NO,
                    @"Go to the clearing in the north part of the southeast paddock."),
                pickupAt(@"route4.nest-balls", @"Nest Balls ×3", NO,
                    @"Check the big rock in the middle of the southeast paddock."),
                pickupAt(@"route4.sharp-beak", @"Sharp Beak", NO,
                    @"Take the path east between the paddocks. Look along the riverbank south of the fishing spot."),
                pickupAt(@"route4.pin-missile", @"TM07 Pin Missile", NO,
                    @"Go to the southeast corner of the northeast paddock and look by Poké Kid Rhys."),
                pickupAt(@"route4.silver-powder", @"Silver Powder", NO,
                    @"Look under the tree in the northwest corner of the west paddock."),
                pickupAt(@"route4.ether", @"Ether", YES,
                    @"Check the northwest corner of the southeast paddock."),
                pickupAt(@"route4.repel", @"Repel", YES,
                    @"Check the wheelbarrow outside the west paddock."),
                pickupAt(@"route4.energy-root", @"Energy Root", YES,
                    @"Find the clearing along the west side of the west paddock."),
                pickupAt(@"route4.x-accuracy", @"X Accuracy ×2", YES,
                    @"Check by the crate in the northeast corner of the west paddock."),
                pickupAt(@"route4.revival-herb", @"Revival Herb", YES,
                    @"Check the southwest corner inside the northeast paddock."),
                activity(@"route4.paralyze-heal", @"Hidden Paralyze Heals", @"Look for two sparkles in the fields.",
                    @"Check the rocks east of Shane in the southeast field and the fallen pillar in the northeast field."),
                pickupAt(@"route4.rare-candy", @"Rare Candy", YES,
                    @"Check along the fence by the rock in the southeast corner of the southeast paddock."),
                activity(@"route4.energy-powder", @"Hidden Energy Powder", @"Look for sparkles in more than one spot.",
                    @"Check the sacks at the fork near the mine and the crate in the northeast corner of the southeast field.")
            ];
        case DMGuideAreaTurffield:
            // Official guide, pp. 62–64.
            return @[
                activity(@"turffield.riddle", @"Standing-stone riddle", @"Ask the girl near the geoglyph overlook for a clue.",
                    @"After hearing the clue, inspect Grass west of the stadium entrance, Water west of the campsite, then Fire at the east end of town. The reward is an Expert Belt."),
                activity(@"turffield.ball-guy", @"Meet Ball Guy", @"Look for the mascot inside the stadium.",
                    @"Talk to Ball Guy in Turffield Stadium to receive a Friend Ball."),
                activity(@"turffield.trade", @"Stadium trade", @"A Trainer in the stadium wants to trade.",
                    @"Offer a Galarian Meowth to the boy in the stadium to receive a Kantonian Meowth."),
                [[DMGuideActivity alloc] initWithKey:@"turffield.loto-id" title:@"Loto-ID"
                    hint:@"Try your luck at Rotomi after reaching Turffield."
                    directions:@"After the Route 4 meeting with Milo, choose Loto-ID at any Pokémon Center’s Rotomi. Play once per day. Prizes depend on the matching digits of your Pokémon’s Trainer IDs."
                    daily:YES],
                pickupAt(@"turffield.x-attacks", @"X Attacks ×3", NO,
                    @"Look by the Flying standing stone close to the hilltop."),
                pickupAt(@"turffield.max-revive", @"Max Revive", NO,
                    @"Follow the path around the southwest side of the stadium fence."),
                pickupAt(@"turffield.brutal-swing", @"TM97 Brutal Swing", NO,
                    @"Follow the path around the southeast side of the stadium fence."),
                pickupAt(@"turffield.leaf-stone", @"Leaf Stone", YES,
                    @"Check just south of the Water standing stone below the hilltop."),
                pickupAt(@"turffield.fresh-water", @"Fresh Water", YES,
                    @"Check the smallest drinking fountain at the overlook."),
                pickupAt(@"turffield.energy-root", @"Energy Root", YES,
                    @"Check along the fence east of the Pokémon Center."),
                pickupAt(@"turffield.everstone", @"Everstone", YES,
                    @"Take the short side path southeast of the stadium."),
                waterActivity(@"turffield.solar-beam", @"TM11 Solar Beam pickup", @"Follow the river to the far bank.",
                    @"Ride along the river to the isolated patch of land northeast of town.")
            ];
        case DMGuideAreaRoute5:
            // Official guide, pp. 66–68.
            return @[
                trainerWin(@"route5.trainer-gillian", @"Interviewers Gillian and Cam",
                    @"Meet the reporter and cameraman together on the path out of Turffield, before the first fork.", @"Helioptile Lv. 18, Klink Lv. 18."),
                trainerWin(@"route5.trainer-stuart", @"Cook Stuart",
                    @"At the first fork, take the downhill route toward the camp and pond.", @"Applin Lv. 20."),
                trainerWin(@"route5.trainer-debra", @"Pokémon Breeder Debra",
                    @"Follow the eastern climb from the camp and pond back toward the upper road.", @"Minccino Lv. 17, Steenee Lv. 19."),
                trainerWin(@"route5.trainer-adrian", @"Pokémon Breeder Adrian",
                    @"Continue along the same eastern climb toward the Nursery road.", @"Stufful Lv. 17, Cutiefly Lv. 18, Ralts Lv. 19."),
                trainerWin(@"route5.trainer-denise", @"Pokémon Breeder Denise",
                    @"Cross the large stone bridge and look near the X Sp. Atk pickup.", @"Cherubi Lv. 18, Woobat Lv. 19."),
                trainerWin(@"route5.trainer-gabrielle", @"Office Worker Gabrielle",
                    @"Follow the main road east past Denise toward Hulbury.", @"Croagunk Lv. 19."),
                activity(@"route5.rotom-bike", @"Get the Rotom Bike", @"Look for a doctor on the bridge beyond the Nursery.",
                    @"Defeat the two Team Yell Grunts who are bothering the doctor. He gives you a Rotom Bike for helping him."),
                campsiteTaxiStop(@"route5.campsite-taxi", @"Take the path south after the reporter and cameraman."),
                activity(@"route5.toxel", @"Receive the Nursery’s Toxel", @"Talk to the people inside the Nursery.",
                    @"Speak to the woman inside to receive Toxel. She also offers five Exp. Candy XS."),
                activity(@"route5.nursery-taxi", @"Route 5 Nursery Flying Taxi stop", @"Speak to the Nursery worker outside.",
                    @"Talk to the worker by the Nursery’s door to add the Nursery to your Flying Taxi destinations."),
                activity(@"route5.nursery-deposit", @"Leave two Pokémon at the Route 5 Nursery", @"Speak to the Nursery worker to leave a pair.",
                    @"Leave two compatible Pokémon and travel around Route 5. Return to the worker outside to pick up an Egg when one is ready."),
                hatchEggActivity(),
                activity(@"route5.feathers", @"Sparkles on the bridge", @"Check the bridge on return visits for more feathers.",
                    @"Collect any sparkle on the bridge. Possible finds include Health, Muscle, Resist, Genius, Clever, Swift, and Pretty Feathers."),
                pickupAt(@"route5.heal-balls", @"Heal Balls ×3", NO,
                    @"From the first fork take the downhill path. Check the clearing behind the southwest grass."),
                pickupAt(@"route5.attract", @"TM31 Attract", NO,
                    @"Go downhill before the Nursery and search past the grass on the east end of the lower loop."),
                pickupAt(@"route5.shed-shell", @"Shed Shell", NO,
                    @"Follow the northern route from Turffield and go around the trees into the fenced strip."),
                pickupAt(@"route5.x-sp-atk", @"X Sp. Atk ×3", NO,
                    @"Cross the stone bridge and check the grass near Breeder Denise."),
                pickupAt(@"route5.big-mushrooms", @"Big Mushrooms ×2", YES,
                    @"Look for a sparkle northwest of the camp on the lower route."),
                pickupAt(@"route5.absorb-bulb", @"Absorb Bulb", YES,
                    @"Check the clearing in the grass north of the road just past the east end of the bridge.")
            ];
        case DMGuideAreaHulbury:
            // Official guide, pp. 69–72 and 146.
            return @[
                activity(@"hulbury.trade", @"A market trade", @"A woman on a bench in the market wants to trade.",
                    @"Bring a Minccino to the woman on the bench to exchange it for her Cottonee."),
                activity(@"hulbury.ball-guy", @"Meet Ball Guy", @"Look for the mascot in the stadium lobby.",
                    @"Speak to Ball Guy inside Hulbury Stadium to collect a Lure Ball."),
                activity(@"hulbury.maximizers", @"A performance by the lighthouse", @"Revisit the lighthouse after becoming Champion.",
                    @"Find the Maximizers near the lighthouse and stay to watch them perform. Check this off after the performance."),
                pickupAt(@"hulbury.magnet", @"Magnet", NO,
                    @"Walk to the southwest corner of the market."),
                pickupAt(@"hulbury.shell-bell", @"Shell Bell", NO,
                    @"Follow the southern jetty to its north end."),
                pickupAt(@"hulbury.net-balls", @"Net Balls ×5", NO,
                    @"Check the south edge of the eastern circular pier."),
                pickupAt(@"hulbury.electroweb", @"TM82 Electroweb", NO,
                    @"Go behind the lighthouse to the northeast corner of the jetty."),
                pickupAt(@"hulbury.x-sp-def", @"X Sp. Def", YES,
                    @"Check the gap in the fence on the east side of the market."),
                pickupAt(@"hulbury.full-heal", @"Full Heal", YES,
                    @"Check the foot of the stairway up to Hulbury Station."),
                pickupAt(@"hulbury.x-speed", @"X Speed ×2", YES,
                    @"Check by the east lamp outside Hulbury Station."),
                pickupAt(@"hulbury.super-potions", @"Super Potions ×2", YES,
                    @"Check to the east of the pair of bins on the north jetty."),
                activity(@"hulbury.delivery-station", @"Captain’s Table delivery 1", @"Return after becoming Champion. The first customer’s clue sounds like a train.",
                    @"Accept the chef’s first order. Deliver it to the gray house closest to the station, then check in with the chef."),
                activity(@"hulbury.delivery-swirlix", @"Captain’s Table delivery 2", @"After the first delivery, listen for the Pokémon in the next clue.",
                    @"Follow the residential lane north from the Pokémon Center to the fourth house. Deliver to the resident with a Swirlix, then return to the chef."),
                activity(@"hulbury.delivery-market", @"Captain’s Table delivery 3", @"For the last delivery, look for a green-striped roof.",
                    @"Bring the last order to the market stall with the green-striped awning. Return to the chef for the Lucky Egg conversation.")
            ];
        default: return laterActivities(area);
    }
}

+ (NSArray<DMGuideActivity *> *)activitiesInArea:(DMGuideArea)area {
    NSMutableArray<DMGuideActivity *> *activities = [NSMutableArray array];
    for (NSUInteger index = 0; index < shieldGymCount; index++) {
        const ShieldGym *gym = &shieldGyms[index];
        if (gym->area != area) continue;
        [activities addObject:activity(gym->missionKey, @"Gym mission", gym->missionHint, gym->mission)];
        NSString *hint = [NSString stringWithFormat:@"Challenge %@ after the Gym mission.", gym->leader];
        [activities addObject:activity(gym->badgeKey, gym->badge, hint, gym->battle)];
        break;
    }
    if (area == DMGuideAreaWyndon) {
        [activities addObject:activity(@"wyndon.champion-cup", @"Win the Champion Cup", @"Challenge Leon at Wyndon Stadium.",
            @"After the finals and the story detour, return to the stadium. Leon has Aegislash and Dragapult Lv. 62, Haxorus Lv. 63 and Gigantamax Charizard Lv. 65. His two Lv. 64 Pokémon depend on your starter. Grookey faces Seismitoad and Cinderace. Scorbunny faces Mr. Rime and Inteleon. Sobble faces Rhyperior and Rillaboom. Bring Rock coverage for Charizard.")];
    }
    [activities addObjectsFromArray:areaActivities(area)];
    for (NSUInteger index = 0; index < postgameStadiumCount; index++) {
        const ShieldPostgameStadium *stadium = &postgameStadiums[index];
        if (stadium->area == area)
            [activities addObject:activity(stadium->key, @"Postgame stadium incident", stadium->hint, stadium->directions)];
    }
    for (NSUInteger index = 0; index < shieldLeagueCardCount; index++) {
        const ShieldLeagueCard *card = &shieldLeagueCards[index];
        if (card->area == area) [activities addObject:activity(card->key, card->name, card->hint, card->directions)];
    }
    NSString *directions = @"At a Pokémon Center, use Rotomi to open Card Maker and look under Background.";
    for (NSUInteger index = 0; index < sizeof(shieldCardBackgrounds) / sizeof(shieldCardBackgrounds[0]); index++) {
        const ShieldCardBackground *background = &shieldCardBackgrounds[index];
        if (background->area != area) continue;
        NSString *title = [@"Card Maker · " stringByAppendingString:background->name];
        const ShieldCardStyleUnlock *styles = cardStyleUnlockForFlag(background->flag);
        NSString *details = directions;
        if (styles) {
            details = @"Open Card Maker at Rotomi to use the newly available options.";
            if (styles->coatingPrices) details = [details stringByAppendingFormat:@" %@", styles->coatingPrices];
        }
        [activities addObject:activity(background->key, title, background->hint, details)];
    }
    for (NSUInteger index = 0; index < sizeof(shieldCardBackgroundTargets) / sizeof(shieldCardBackgroundTargets[0]); index++) {
        const ShieldCardBackgroundTarget *target = &shieldCardBackgroundTargets[index];
        if (target->area != area) continue;
        NSString *title = [@"Card Maker · " stringByAppendingString:target->name];
        [activities addObject:activity(target->key, title, target->hint, directions)];
    }
    for (NSUInteger index = 0; index < shieldUniformCount; index++) {
        const ShieldUniform *uniform = &shieldUniforms[index];
        if (uniform->area == area && uniform->source)
            [activities addObject:activity(uniform->key, uniform->name, uniform->source,
                @"Use a boutique’s fitting room to put on the pieces from your wardrobe.")];
    }
    if (area == DMGuideAreaMotostoke || area == DMGuideAreaHammerlocke ||
        area == DMGuideAreaCirchester || area == DMGuideAreaWyndon) {
        [activities addObject:activity(@"fashion.hairstyle", @"Try a hair salon", @"Choose the Hair service at the local salon.",
            @"The Hair service costs 3,000 Pokédollars. Preview styles and colors before making your choice.")];
    }
    return activities;
}

+ (BOOL)hasAlcremieCollectionInArea:(DMGuideArea)area {
    return area == DMGuideAreaMotostoke || area == DMGuideAreaRoute4 ||
        area == DMGuideAreaHammerlocke || area == DMGuideAreaWyndon;
}

+ (NSString *)alcremieDirections {
    return @"Find Milcery in the grass on Route 4. Give it a Sweet to hold and spin in the field. The Sweet sets the decoration. Time of day, direction and spin length set the flavor.";
}

+ (BOOL)hasUniformWardrobeInArea:(DMGuideArea)area {
    switch (area) {
        case DMGuideAreaMotostoke: case DMGuideAreaTurffield: case DMGuideAreaHulbury:
        case DMGuideAreaHammerlocke: case DMGuideAreaStow: case DMGuideAreaBallonlea:
        case DMGuideAreaCirchester: case DMGuideAreaSpikemuth: case DMGuideAreaWyndon:
        case DMGuideAreaBattleTower:
            return YES;
        default:
            return NO;
    }
}

- (DMGuideArea)selectedArea {
    NSInteger index = [_defaults integerForKey:@"shieldGuide.area"];
    return index >= 0 && index < (NSInteger)DMShieldGuide.areaNames.count ? (DMGuideArea)index : DMGuideAreaWedgehurst;
}

- (void)setSelectedArea:(DMGuideArea)area {
    [_defaults setInteger:area forKey:@"shieldGuide.area"];
}

static NSString *dayKey(void) {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *date = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:NSDate.date];
    return [NSString stringWithFormat:@"%ld-%02ld-%02ld", (long)date.year, (long)date.month, (long)date.day];
}

- (BOOL)isChecked:(DMGuideActivity *)activity {
    NSString *key = [@"shieldGuide.checked." stringByAppendingString:activity.key];
    return activity.isDaily ? [[_defaults stringForKey:key] isEqualToString:dayKey()] : [_defaults boolForKey:key];
}

- (void)setChecked:(BOOL)checked forActivity:(DMGuideActivity *)activity {
    NSString *key = [@"shieldGuide.checked." stringByAppendingString:activity.key];
    if (!checked) [_defaults removeObjectForKey:key];
    else if (activity.isDaily) [_defaults setObject:dayKey() forKey:key];
    else [_defaults setBool:YES forKey:key];
}
@end
