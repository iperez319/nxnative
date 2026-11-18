#import "shield_guide_save.h"
#import "shield_guide_card_backgrounds.h"
#import "shield_guide_fossils.h"
#import "shield_guide_gyms.h"
#import "shield_guide_league_cards.h"
#import "shield_guide_postgame.h"
#import "shield_guide_uniforms.h"
#import <CoreText/CoreText.h>
#include "shield_guide_live.h"
#include "../games/01008DB008C2C000/guide_live_profile.h"
#include <CommonCrypto/CommonDigest.h>
#include <errno.h>
#include <limits.h>
#include <math.h>
#include <stdatomic.h>
#include <sys/stat.h>
#include <unistd.h>

enum { maxSaveSize = 2 * 1024 * 1024 };
enum { boolFalse = 1, boolTrue = 2, boolElement = 3, object = 4, array = 5, u8 = 8, u16 = 9, u32 = 10 };
enum {
    birthdayMonth = 0x0D987D50, birthdayDay = 0x355C8314,
    letterProgress = 0x4584784A, detectiveProgress = 0xAF0E8346,
    riddleProgress = 0x0E85795E, outfitProgress = 0x67A659C4, applinProgress = 0xCC45DA54,
    rallyHighScore = 0x38548020, bikeChargeLimit = 0xF64719D9,
    rallyThunderWave = 0xB2D0C5DC, rallyVoltSwitch = 0xB2D0CAF5, rallyFastBall = 0xB2D0C942,
    diggingBestSkill = 0xA0F49CFB, diggingBestStamina = 0x066F38F5,
    marnieFirstWin = 0xBF9C3942, morimotoFirstWin = 0x92269668,
    marnieSmileProgress = 0x4C54B0CF,
    letsGoPikachuClaim = 0x9D95E9CA, letsGoEeveeClaim = 0x855235FF,
    championTournamentWins = 0x26FE3E7E, charmanderGiftBall = 0x178159E5,
    gameClear = 0x4DBE8A87,
    bikeWaterUnlock = 0x7526A53C,
    typeNullGiftProgress = 0x697D1E29,
    goldenCookwareUnlocked = 0x72D4B15E,
    dailyBuyerInitialized = 0xD902B576, buyerRequestOutstanding = 0xFC997003, buyerItem = 0x6C3B5E62,
    marketStockInitialized = 0xBCEFA75A, marketFirstVisit = 0x42636768,
    marketToday = 0xF8E07F9B, marketYesterday = 0xA4D5B8C0, marketTomorrow = 0xFE2E9869,
    marketBoughtToday = 0x29F6FFF4, marketBoughtYesterday = 0x3F9D0251,
    shinyCharmVisit = 0x813B1361,
    towerSinglesPoints = 0x439116A4, towerDoublesPoints = 0xEE7B2ABD,
    towerSinglesHighest = 0xCE4AC6FA, towerDoublesHighest = 0x29E026C7,
    towerSinglesRewardWins = 0x6226F5AD, towerDoublesRewardWins = 0x5F74FCEE,
    towerJudgeUnlocked = 0xD0E267EB,
    cafeMotostokeUsed = 0x3E2EF9CC, cafeHammerlockeUsed = 0x3E2EFEE5, cafeWyndonUsed = 0x3E2EFD32,
    cafeMotostokeRoll = 0x24F1FCA2, cafeHammerlockeRoll = 0x24F1FAEF, cafeWyndonRoll = 0x24F1F93C,
};
enum { marketCurrentPrice = 3000, marketPreviousPrice = 5000 };
// Saved work values index these script tables. Index 0 is the empty offer.
static const struct { __unsafe_unretained NSString *name; uint8_t weight; } marketBargains[] = {
    {nil, 0}, {@"Quick Claw", 4}, {@"Silver Powder", 1}, {@"Focus Band", 3}, {@"Metal Coat", 5},
    {@"Miracle Seed", 3}, {@"Black Glasses", 1}, {@"Black Belt", 1}, {@"Magnet", 1}, {@"Mystic Water", 3},
    {@"Sharp Beak", 3}, {@"Poison Barb", 1}, {@"Never-Melt Ice", 1}, {@"Spell Tag", 3}, {@"Twisted Spoon", 3},
    {@"Charcoal", 3}, {@"Dragon Fang", 3}, {@"Silk Scarf", 1}, {@"Metronome", 3}, {@"Black Sludge", 3},
    {@"Protector", 7}, {@"Reaper Cloth", 7}, {@"Razor Claw", 7}, {@"Ring Target", 3}, {@"Binding Band", 3},
    {@"Pixie Plate", 1}, {@"Protective Pads", 3}, {@"Cracked Pot", 20}, {@"Chipped Pot", 3},
};
static const struct { unsigned item, price; __unsafe_unretained NSString *name; } marketBuyerItems[] = {
    {0, 0, nil}, {86, 2000, @"Tiny Mushroom"}, {87, 10000, @"Big Mushroom"}, {580, 25000, @"Balm Mushroom"},
    {88, 3000, @"Pearl"}, {89, 12000, @"Big Pearl"}, {582, 27500, @"Pearl String"},
    {90, 4000, @"Stardust"}, {91, 14000, @"Star Piece"}, {583, 30000, @"Comet Shard"}, {106, 11111, @"Rare Bone"},
};
enum { marketBargainCount = sizeof(marketBargains) / sizeof(marketBargains[0]),
       marketBuyerItemCount = sizeof(marketBuyerItems) / sizeof(marketBuyerItems[0]) };

static bool isMarketTreasure(unsigned item) {
    for (NSUInteger index = 1; index < marketBuyerItemCount; index++)
        if (marketBuyerItems[index].item == item) return true;
    return false;
}
static const struct { DMGuideArea area; uint32_t dailyFlag, rollKey; } battleCafes[] = {
    {DMGuideAreaMotostoke, cafeMotostokeUsed, cafeMotostokeRoll},
    {DMGuideAreaHammerlocke, cafeHammerlockeUsed, cafeHammerlockeRoll},
    {DMGuideAreaWyndon, cafeWyndonUsed, cafeWyndonRoll},
};
enum { battleCafeCount = sizeof(battleCafes) / sizeof(battleCafes[0]) };
// Reward order matters. Each city's weights sum to 100 in sub_event_011.amx.
static const struct { __unsafe_unretained NSString *name; uint8_t weight[battleCafeCount]; } cafePrizes[] = {
    {@"Moomoo Milk", {5, 3, 1}}, {@"Lava Cookie", {3, 3, 3}}, {@"Berry Juice", {3, 3, 3}},
    {@"Rare Candy", {5, 5, 10}}, {@"Old Gateau", {3, 3, 3}}, {@"Sweet Heart", {3, 3, 3}},
    {@"Rage Candy Bar", {3, 3, 3}}, {@"Casteliacone", {3, 3, 3}},
    {@"Whipped Dream", {8, 6, 4}}, {@"Sachet", {8, 6, 4}},
    {@"Lumiose Galette", {3, 3, 3}}, {@"Shalour Sable", {3, 3, 3}},
    {@"Big Malasada", {3, 3, 3}}, {@"Pewter Crunchies", {3, 3, 3}},
    {@"Exp. Candy XS", {6, 0, 0}}, {@"Exp. Candy S", {10, 8, 0}},
    {@"Exp. Candy M", {0, 8, 12}}, {@"Exp. Candy L", {0, 0, 5}},
    {@"Strawberry Sweet", {20, 2, 2}}, {@"Love Sweet", {2, 14, 2}}, {@"Berry Sweet", {2, 14, 2}},
    {@"Clover Sweet", {2, 2, 14}}, {@"Flower Sweet", {2, 2, 14}},
};

static NSUInteger cafeIndexForArea(DMGuideArea area) {
    for (NSUInteger cafe = 0; cafe < battleCafeCount; cafe++)
        if (battleCafes[cafe].area == area) return cafe;
    return NSNotFound;
}
// Record8 is 50 signed 32-bit counters. Use the outcome-specific slots.
enum { recordCount = 50, eggHatchRecord = 0, raidCaptureRecord = 3, rallyFinishRecord = 10, fossilRevivalRecord = 15,
       curryCookedRecord = 34, pokeJobReturnRecord = 35,
       berryGatherRecord = 40, raidBattleRecord = 43, towerSinglesWinRecord = 47, towerDoublesWinRecord = 48 };
enum { rallyVoltSwitchScore = 20000, rallyFastBallFinishes = 11, bikeUpgradeCount = 3 };
enum { baseCardCount = 31, cardEntrySize = 8 };
enum { curryRecipeCount = 151, curryRecordSize = 0xB0, currySizeCount = 3, curryFlavorCount = 6, campToyCount = 6 };
enum { galarDexCount = 400, galarDexEntrySize = 0x30, galarDexSeenBytes = 0x20, galarDexRangeSize = 25 };
enum { rotomDexNumber = 372, zamazentaDexNumber = 399, eternatusDexNumber = 400 };
enum { rotomSpecies = 479, rotomFormCount = 6 };
enum { sinisteaSpecies = 854, polteageistSpecies = 855, crackedPot = 1253, chippedPot = 1254 };
static const struct {
    unsigned item;
    __unsafe_unretained NSString *form, *pot, *key, *source;
} teaEvolutions[] = {
    {crackedPot, @"Phony Form", @"Cracked Pot", @"stow.phony-polteageist",
        @"Climb the ladder to the right of the stadium stairs for the rooftop pickup, or check the bargain stall."},
    {chippedPot, @"Antique Form", @"Chipped Pot", @"stow.antique-polteageist",
        @"Check the bargain stall in Stow-on-Side for a Chipped Pot."},
};
enum { teaFormCount = sizeof(teaEvolutions) / sizeof(teaEvolutions[0]) };

static bool isTeaPot(unsigned item) {
    return item == crackedPot || item == chippedPot;
}

static NSUInteger teaFormForActivity(NSString *key) {
    for (NSUInteger form = 0; form < teaFormCount; form++)
        if ([key isEqualToString:teaEvolutions[form].key]) return form;
    return NSNotFound;
}

enum { alcremieSpecies = 869, alcremieFlavorCount = 9, firstAlcremieSweet = 1109, alcremieSweetCount = 7,
       alcremieFormCount = alcremieFlavorCount * alcremieSweetCount };
static NSString *const alcremieSweets[alcremieSweetCount] = {
    @"Strawberry Sweet", @"Love Sweet", @"Berry Sweet", @"Clover Sweet", @"Flower Sweet", @"Star Sweet", @"Ribbon Sweet",
};
static const struct {
    __unsafe_unretained NSString *flavor;
    __unsafe_unretained NSString *spin;
} alcremieFlavors[alcremieFlavorCount] = {
    {@"Vanilla Cream", @"Day · Clockwise · Under 5 seconds"},
    {@"Ruby Cream", @"Day · Counterclockwise · Under 5 seconds"},
    {@"Matcha Cream", @"Night · Clockwise · Under 5 seconds"},
    {@"Mint Cream", @"Night · Counterclockwise · Over 5 seconds"},
    {@"Lemon Cream", @"Night · Clockwise · Over 5 seconds"},
    {@"Salted Cream", @"Night · Counterclockwise · Under 5 seconds"},
    {@"Ruby Swirl", @"Day · Counterclockwise · Over 5 seconds"},
    {@"Caramel Swirl", @"Day · Clockwise · Over 5 seconds"},
    {@"Rainbow Swirl", @"Dusk · Counterclockwise · Over 10 seconds"},
};
static const char *const galarDexSpecies[] = {
#include "shield_guide_galar_dex.inc"
};
_Static_assert(sizeof(galarDexSpecies) / sizeof(galarDexSpecies[0]) == galarDexCount, "Galar Pokédex size mismatch");
static const struct {
    unsigned species;
    uint8_t forms;
    __unsafe_unretained NSString *name;
    __unsafe_unretained NSString *source;
} gigantamaxSpecies[] = {
    {alcremieSpecies, alcremieFlavorCount, @"Alcremie", nil},
    {842, 1, @"Appletun", nil},
    {12, 1, @"Butterfree", nil},
    {851, 1, @"Centiskorch", nil},
    {6, 1, @"Charizard", @"After becoming Champion, collect Leon’s gift Charmander in Postwick and evolve it."},
    {839, 1, @"Coalossal", @"Join a Sword Max Raid or trade."},
    {879, 1, @"Copperajah", nil},
    {823, 1, @"Corviknight", nil},
    {834, 1, @"Drednaw", nil},
    {884, 1, @"Duraludon", nil},
    {133, 1, @"Eevee", @"Wild Area Station gift with compatible Let’s Go, Eevee! save data."},
    {841, 1, @"Flapple", @"Join a Sword Max Raid or trade."},
    {569, 1, @"Garbodor", nil},
    {94, 1, @"Gengar", nil},
    {861, 1, @"Grimmsnarl", nil},
    {858, 1, @"Hatterene", nil},
    {99, 1, @"Kingler", nil},
    {131, 1, @"Lapras", nil},
    {68, 1, @"Machamp", @"Join a Sword Max Raid or trade."},
    {52, 1, @"Meowth", @"Trade or give a Kantonian Meowth Max Soup on the Isle of Armor."},
    {826, 1, @"Orbeetle", nil},
    {25, 1, @"Pikachu", @"Wild Area Station gift with compatible Let’s Go, Pikachu! save data."},
    {844, 1, @"Sandaconda", nil},
    {143, 1, @"Snorlax", @"Trade or use Max Soup on the Isle of Armor."},
    {849, 2, @"Toxtricity", @"Trade or use Max Soup on the Isle of Armor."},
};
enum { gigantamaxSpeciesCount = sizeof(gigantamaxSpecies) / sizeof(gigantamaxSpecies[0]) };
enum { hiddenItemsPerBlock = 512, hiddenItemEntrySize = 4, hiddenItemBlockSize = 0x810,
       hiddenItemUninitialized = 0, hiddenItemActive = 1, hiddenItemWaitingForRespawn = 2,
       hiddenItemCollectedPermanently = 3 };
typedef NS_ENUM(uint8_t, CampingRewardKind) { CampingIngredient, CampingToy, CampingCookware };
static const struct {
    NSUInteger threshold;
    uint32_t flag;
    CampingRewardKind kind;
    __unsafe_unretained NSString *name;
} campingRewards[] = {
    {1, 0x59514DF7, CampingIngredient, @"Sausages ×3"},
    {5, 0xAFA33CBD, CampingToy, @"Fresh Ball"},
    {10, 0xE49088C4, CampingToy, @"Weighted Ball"},
    {15, 0x45E850BE, CampingToy, @"Soothe Ball"},
    {30, 0x9B6CD5A2, CampingToy, @"Mirror Ball"},
    {50, 0xEA3E6881, CampingToy, @"Tympole Ball"},
    {80, 0x45FD94D6, CampingToy, @"Champion Ball"},
    {110, 0x59513EAC, CampingIngredient, @"Moomoo Cheese ×3"},
    {150, 0x5951405F, CampingIngredient, @"Smoke-Poke Tail ×3"},
    {151, goldenCookwareUnlocked, CampingCookware, @"Golden cookware"},
};

// Sword/Shield on-disk format constants. Format reference:
// https://github.com/kwsch/PKHeX/tree/master/PKHeX.Core/Saves/Encryption/SwishCrypto
static const uint8_t hashPrefix[] =
    "\x9e\xc9\x9c\xd7\x0e\xd3\x3c\x44\xfb\x93\x03\xdc\xeb\x39\xb4\x2a"
    "\x19\x47\xe9\x63\x4b\xa2\x33\x44\x16\xbf\x82\xa2\xba\x63\x55\xb6"
    "\x3d\x9d\xf2\x4b\x5f\x7b\x6a\xb2\x62\x1d\xc2\x1b\x68\xe5\xc8\xb5"
    "\x3a\x05\x90\x00\xe8\xa8\x10\x3d\xe2\xec\xf0\x0c\xb2\xed\x4f\x6d";
static const uint8_t hashSuffix[] =
    "\xd6\xc0\x1c\x59\x8b\xc8\xb8\xcb\x46\xe1\x53\xfc\x82\x8c\x75\x75"
    "\x13\xe0\x45\xdf\x32\x69\x3c\x75\xf0\x59\xf8\xd9\xa2\x5f\xb2\x17"
    "\xe0\x80\x52\xdb\xea\x89\x73\x99\x75\x79\xaf\xcb\x2e\x80\x07\xe6"
    "\xf1\x26\xe0\x03\x0a\xe6\x6f\xf6\x41\xbf\x7e\x59\xc2\xae\x55\xfd";
static const uint8_t fileMask[] =
    "\xa0\x92\xd1\x06\x07\xdb\x32\xa1\xae\x01\xf5\xc5\x1e\x84\x4f\xe3"
    "\x53\xca\x37\xf4\xa7\xb0\x4d\xa0\x18\xb7\xc2\x97\xda\x5f\x53\x2b"
    "\x75\xfa\x48\x16\xf8\xd4\x8a\x6f\x61\x05\xf4\xe2\xfd\x04\xb5\xa3"
    "\x0f\xfc\x44\x92\xcb\x32\xe6\x1b\xb9\xb1\x2e\x01\xb0\x56\x53\x36"
    "\xd2\xd1\x50\x3d\xde\x5b\x2e\x0e\x52\xfd\xdf\x2f\x7b\xca\x63\x50"
    "\xa4\x67\x5d\x23\x17\xc0\x52\xe1\xa6\x30\x7c\x2b\xb6\x70\x36\x5b"
    "\x2a\x27\x69\x33\xf5\x63\x7b\x36\x3f\x26\x9b\xa3\xed\x7a\x53\x00"
    "\xa4\x48\xb3\x50\x9e\x14\xa0\x52\xde\x7e\x10\x2b\x1b\x77\x6e";

static bool checkIntegrity(const uint8_t *bytes, size_t bodySize) {
    CC_SHA256_CTX hash;
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Init(&hash);
    CC_SHA256_Update(&hash, hashPrefix, sizeof(hashPrefix) - 1);
    CC_SHA256_Update(&hash, bytes, (CC_LONG)bodySize);
    CC_SHA256_Update(&hash, hashSuffix, sizeof(hashSuffix) - 1);
    CC_SHA256_Final(digest, &hash);
    return memcmp(digest, bytes + bodySize, sizeof(digest)) == 0;
}

typedef struct { uint32_t word; unsigned shift; } BlockMask;

static uint32_t nextWord(uint32_t x) {
    x ^= x << 2;
    x ^= x >> 15;
    return x ^ (x << 13);
}

static BlockMask blockMask(uint32_t key) {
    BlockMask mask = {key, 0};
    for (int remaining = __builtin_popcount(key); remaining; remaining--) mask.word = nextWord(mask.word);
    return mask;
}

static uint8_t maskByte(BlockMask *mask) {
    uint8_t byte = (uint8_t)(mask->word >> mask->shift);
    mask->shift += 8;
    if (mask->shift == 32) {
        mask->word = nextWord(mask->word);
        mask->shift = 0;
    }
    return byte;
}

static uint64_t decodeLE(const uint8_t *bytes, size_t count, BlockMask *mask) {
    uint64_t value = 0;
    for (size_t i = 0; i < count; i++) {
        uint8_t byte = bytes[i];
        if (mask) byte ^= maskByte(mask);
        value |= (uint64_t)byte << (i * 8);
    }
    return value;
}

static size_t scalarSize(uint8_t type) {
    static const uint8_t sizes[] = {1, 2, 4, 8, 1, 2, 4, 8, 4, 8};
    return type >= 8 && type <= 17 ? sizes[type - 8] : 0;
}

static uint64_t readObjectLE(const uint8_t *bytes, size_t offset, size_t count, BlockMask mask) {
    for (size_t i = 0; i < offset; i++) maskByte(&mask);
    return decodeLE(bytes + offset, count, &mask);
}

enum {
    wardrobeSize = 0xF1C, wardrobeCategoryBytes = 128,
    wardrobeTop = 9, wardrobeShorts = 11, wardrobeLegwear = 12, wardrobeShoes = 13, wardrobeGlove = 14,
};

static bool hasWardrobePart(const uint8_t *ownership, unsigned category, unsigned part) {
    unsigned byte = category * wardrobeCategoryBytes + part / 8;
    return (ownership[byte] & (1u << (part % 8))) != 0;
}

static NSData *wardrobeOwnership(const uint8_t *bytes, BlockMask mask) {
    NSMutableData *data = [NSMutableData dataWithLength:(wardrobeGlove + 1) * wardrobeCategoryBytes];
    uint8_t *ownership = data.mutableBytes;
    for (NSUInteger offset = 0; offset < data.length; offset++) ownership[offset] = bytes[offset] ^ maskByte(&mask);
    return data;
}

static NSIndexSet *ownedUniforms(const uint8_t *ownership, uint8_t gender) {
    NSMutableIndexSet *owned = [NSMutableIndexSet indexSet];
    for (NSUInteger index = 0; index < shieldUniformCount; index++) {
        const ShieldUniform *uniform = &shieldUniforms[index];
        unsigned part = uniform->outfitIndex[gender];
        if (hasWardrobePart(ownership, wardrobeTop, part) &&
            hasWardrobePart(ownership, wardrobeShorts, part + 1) &&
            hasWardrobePart(ownership, wardrobeLegwear, part) &&
            hasWardrobePart(ownership, wardrobeShoes, part) &&
            (uniform->gloveIndex < 0 || hasWardrobePart(ownership, wardrobeGlove, (unsigned)uniform->gloveIndex)))
            [owned addIndex:index];
    }
    return owned;
}

typedef struct {
    uint8_t shop, tab, category;
    uint16_t part;
    uint32_t price;
    bool styleCardRequired;
    const char *name, *color;
} ShieldBoutiquePart;

#include "shield_guide_boutique_stock.inc"

static const ShieldBoutiquePart *boutiqueStockForAvatar(uint8_t avatar, NSUInteger *count) {
    if (avatar == 0) {
        *count = sizeof(boutiqueStockAvatar0) / sizeof(boutiqueStockAvatar0[0]);
        return boutiqueStockAvatar0;
    }
    *count = sizeof(boutiqueStockAvatar1) / sizeof(boutiqueStockAvatar1[0]);
    return boutiqueStockAvatar1;
}

static unsigned boutiqueShopInArea(DMGuideArea area) {
    switch (area) {
        case DMGuideAreaWedgehurst: return 1;
        case DMGuideAreaMotostoke: return 2;
        case DMGuideAreaHammerlocke: return 3;
        case DMGuideAreaCirchester: return 4;
        case DMGuideAreaWyndon: return 5;
        default: return 0;
    }
}

enum { boutiqueTabCount = 10 };
static NSString *const boutiqueTabs[] = {
    @"Tops", @"Outerwear", @"Bottoms", @"Dresses", @"Shoes", @"Gloves",
    @"Bags", @"Hats", @"Eyewear", @"Legwear",
};

@interface DMGuideBoutiqueCategory ()
@property (nonatomic) NSInteger identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<NSString *> *items;
@end

@implementation DMGuideBoutiqueCategory
@end

static NSIndexSet *cookedCurryRecipes(const uint8_t *bytes, BlockMask mask) {
    NSMutableIndexSet *cooked = [NSMutableIndexSet indexSet];
    for (NSUInteger recipe = 0; recipe < curryRecipeCount; recipe++) {
        // The native count treats any registered serving size as one distinct dish.
        size_t offset = recipe * curryRecordSize;
        if (decodeLE(bytes + offset, currySizeCount, &mask)) [cooked addIndex:recipe];
        for (size_t i = currySizeCount; i < curryRecordSize; i++) maskByte(&mask);
    }
    return cooked;
}

typedef struct {
    __unsafe_unretained NSString *key;
    bool recurring;
    uint16_t indices[10];
} HiddenPickup;

static const HiddenPickup hiddenPickups[] = {
#include "shield_guide_hidden_items.inc"
};

static const struct {
    uint8_t subarea;
    uint16_t indices[14];
    __unsafe_unretained NSString *rewards;
} wildSparkles[] = {
#include "shield_guide_wild_sparkles.inc"
};

#include "shield_guide_sparkle_map.inc"

static NSInteger sparkleSubareaIndex(DMGuideArea area, NSInteger subarea) {
    if (subarea < 0 || (NSUInteger)subarea >= [DMShieldGuide wildSubareasInArea:area].count) return -1;
    return area == DMGuideAreaNorthWild ? subarea + (NSInteger)[DMShieldGuide wildSubareasInArea:DMGuideAreaWildArea].count : subarea;
}

static const HiddenPickup *hiddenPickupForKey(NSString *key) {
    for (size_t i = 0; i < sizeof(hiddenPickups) / sizeof(hiddenPickups[0]); i++)
        if ([key isEqualToString:hiddenPickups[i].key]) return &hiddenPickups[i];
    return NULL;
}

enum { firstTRItem = 1130, focusEnergyTR = firstTRItem + 13 };
enum { weatherLesson = 0x0CF6D916, weatherBonus = 0xA6BF731D, stowFossilGift = 0xFDCF5FB6,
       masterBallGiftStage = 0x697141AC, masterBallGift = 0xC6A2919B, beastBallGift = 0xDE311170,
       pokeDollGift = 0xE98F75E0, masterBallItem = 1, beastBallItem = 851, pokeDollItem = 63,
       starPiece = 91, cheriBerry = 149, soniasBook = 1271,
       landBike = 1081, waterBike = 1266, ovalCharm = 631, styleCard = 1583 };
static const struct {
    NSString *key;
    NSString *eventLabel;
    uint32_t flag;
    unsigned item;
    bool holdable;
} giftRewards[] = {
    {@"hammerlocke.soothe-bell", @"Gift interaction recorded", 0xAA077C03, 218, true},
    {@"hammerlocke.mr-focus", @"Reward conversation recorded", 0x9BCEA990, 275, true},
    {@"ballonlea.eviolite", @"Reward conversation recorded", 0x0179AC72, 538, true},
    {@"motostoke.focus-energy", @"Gift interaction recorded", 0x40C3F0CC, focusEnergyTR, true},
    {@"motostoke.star-piece", @"Gift interaction recorded", 0x122139BB, starPiece, true},
    {@"route3.berry-gift", @"Camper’s gift interaction recorded", 0xDE75B53A, cheriBerry, true},
    {@"motostoke.earbuds", @"Gift interaction recorded", 0x61154168, 1255, false},
    {@"stow.fly", @"Gift interaction recorded", 0x1DD4DA8E, 333, false},
    {@"ballonlea.revenge", @"Gift interaction recorded", 0x2D66FAA5, 369, false},
    {@"circhester.rock-tomb", @"Gift interaction recorded", 0x11F04DAF, 375, false},
    {@"circhester.screech", @"Gift interaction recorded", 0xB43125FE, 343, false},
    {@"circhester.fake-tears", @"Gift interaction recorded", 0xFCC87EFF, 374, false},
    {@"circhester.catching-charm", @"Director’s gift interaction recorded", 0x623D4566, 1267, false},
    {@"circhester.oval-charm", @"Morimoto’s reward interaction recorded", morimotoFirstWin, ovalCharm, false},
    {@"circhester.shiny-charm", @"Pokédex reward interaction recorded", shinyCharmVisit, 632, false},
    {@"route9.dive", @"Gift interaction recorded", 0xE8B9BD4A, 372, false},
    {@"north-wild.rally-thunder-wave", @"Thunder Wave reward event recorded", rallyThunderWave, 341, false},
    {@"north-wild.rally-volt-switch", @"Volt Switch reward event recorded", rallyVoltSwitch, 407, false},
    {@"wyndon.rotom-catalog", @"Reward conversation recorded", 0x2B6451E7, 1278, false},
};
enum { giftRewardCount = sizeof(giftRewards) / sizeof(giftRewards[0]) };
static const unsigned weatherRewards[] = {284, 285, 282, 283, 1123}; // Heat, Damp, Icy, Smooth, Umbrella
enum { weatherRewardCount = sizeof(weatherRewards) / sizeof(weatherRewards[0]) };
enum { firstSilvallyMemory = 904 };
static NSString *const silvallyMemoryTypes[] = {
    @"Fighting", @"Flying", @"Poison", @"Ground", @"Rock", @"Bug", @"Ghost", @"Steel",
    @"Fire", @"Water", @"Grass", @"Electric", @"Psychic", @"Ice", @"Dragon", @"Dark", @"Fairy",
};
enum { silvallyMemoryCount = sizeof(silvallyMemoryTypes) / sizeof(silvallyMemoryTypes[0]) };

static bool isAlcremieSweet(unsigned item) {
    return item >= firstAlcremieSweet && item < firstAlcremieSweet + alcremieSweetCount;
}

static bool isHoldableReward(unsigned item) {
    if (isAlcremieSweet(item) || isTeaPot(item)) return true;
    if (item >= firstSilvallyMemory && item < firstSilvallyMemory + silvallyMemoryCount) return true;
    for (size_t i = 0; i < giftRewardCount; i++)
        if (giftRewards[i].item == item) return giftRewards[i].holdable;
    for (size_t i = 0; i < weatherRewardCount; i++)
        if (weatherRewards[i] == item) return true;
    return false;
}

static NSUInteger tmNumberForItem(unsigned item) {
    if (item == 1230) return 0;
    if (item >= 328 && item <= 419) return item - 327; // TM01–TM92
    if (item >= 618 && item <= 620) return item - 525; // TM93–TM95
    if (item >= 690 && item <= 693) return item - 594; // TM96–TM99
    return NSNotFound;
}

static const struct {
    DMGuideArea area;
    __unsafe_unretained NSString *move;
    __unsafe_unretained NSString *hint;
    unsigned price;
} technicalMachines[] = {
#include "shield_guide_tms.inc"
};
enum { technicalMachineCount = sizeof(technicalMachines) / sizeof(technicalMachines[0]) };
_Static_assert(technicalMachineCount == 100, "Expected TM00 through TM99");

static const struct {
    __unsafe_unretained NSString *move;
    __unsafe_unretained NSString *type;
    unsigned watts;
} technicalRecords[] = {
#include "shield_guide_trs.inc"
};
enum { technicalRecordCount = sizeof(technicalRecords) / sizeof(technicalRecords[0]) };
_Static_assert(technicalRecordCount == 100, "Expected TR00 through TR99");

static NSIndexSet *giftItemsInBag(const uint8_t *bytes, BlockMask mask,
                                 NSMutableDictionary<NSNumber *, NSNumber *> *quantities,
                                 NSMutableIndexSet *ownedTMs, NSMutableIndexSet *recordedItems) {
    enum { ballsStart = 0x00F0, battleStart = 0x0168, berriesStart = 0x01B8,
           itemsStart = 0x02F8, machinesStart = 0x0B90, treasureStart = 0x0ED8,
           treasureEnd = 0x1068, keyItemsStart = 0x11F8, bagEnd = 0x12F8 };
    NSMutableIndexSet *items = [NSMutableIndexSet indexSet];
    for (size_t offset = 0; offset < bagEnd; offset += 4) {
        uint32_t entry = (uint32_t)decodeLE(bytes + offset, 4, &mask);
        unsigned item = entry & 0x7FFF;
        unsigned quantity = (entry >> 15) & 0x7FFF;
        if (!item) continue;
        bool inTreasure = offset >= treasureStart && offset < treasureEnd;
        bool inMachines = offset >= machinesStart && offset < treasureStart;
        bool inGeneralItems = offset >= itemsStart && offset < machinesStart;
        bool isTR = item >= firstTRItem && item < firstTRItem + technicalRecordCount;
        bool countQuantity;
        if (item == masterBallItem || item == beastBallItem) countQuantity = offset >= ballsStart && offset < battleStart;
        else if (item == pokeDollItem) countQuantity = offset >= battleStart && offset < berriesStart;
        else if (item >= fossilizedBird && item <= fossilizedDino) countQuantity = inTreasure;
        else if (inTreasure && isMarketTreasure(item)) countQuantity = true;
        else if (isAlcremieSweet(item) || isTeaPot(item)) countQuantity = inGeneralItems;
        else countQuantity = isTR && inMachines;
        if (countQuantity) {
            if (quantity) quantities[@(item)] = @(quantities[@(item)].unsignedIntegerValue + quantity);
            [recordedItems addIndex:item];
        }
        NSUInteger tm = tmNumberForItem(item);
        if (inMachines && tm != NSNotFound && quantity) [ownedTMs addIndex:tm];
        bool holdable = isHoldableReward(item);
        bool correctPocket;
        if (item == starPiece) correctPocket = inTreasure;
        else if (item == cheriBerry) correctPocket = offset >= berriesStart && offset < itemsStart;
        else if (isTR || tm != NSNotFound) correctPocket = inMachines;
        else if (holdable) correctPocket = inGeneralItems;
        else correctPocket = offset >= keyItemsStart;
        if (!correctPocket) continue;
        if (quantity) [items addIndex:item];
        // Exhausting a stack leaves its item ID in the pocket.
        if (holdable) [recordedItems addIndex:item];
    }
    return items;
}

enum { pk8SlotSize = 0x158, pk8StoredSize = 0x148, pk8ChunkSize = 0x50, slotsPerBox = 30 };
enum {
    route1Capture = 1 << 0,
    route2Capture = 1 << 1,
    nurseryToxel = 1 << 2,
    towerTypeNull = 1 << 3,
    bestFriendsRibbon = 1 << 4,
    effortRibbon = 1 << 5,
    towerMasterRibbon = 1 << 6,
    bestFriendsReady = 1 << 7,
    effortReady = 1 << 8,
    hyperTrained = 1 << 9,
    firstTutorMoveBit = 10,
};

static const struct {
    NSString *key;
    uint16_t move;
    NSString *name;
} tutorMoves[] = {
    {@"motostoke.steel-beam", 796, @"Steel Beam"},
    {@"hammerlocke.pledge-tutor", 520, @"Grass Pledge"},
    {@"hammerlocke.pledge-tutor", 519, @"Fire Pledge"},
    {@"hammerlocke.pledge-tutor", 518, @"Water Pledge"},
    {@"circhester.draco-meteor", 434, @"Draco Meteor"},
    {@"wyndon.starter-tutor", 338, @"Frenzy Plant"},
    {@"wyndon.starter-tutor", 307, @"Blast Burn"},
    {@"wyndon.starter-tutor", 308, @"Hydro Cannon"},
};
enum { tutorMoveCount = sizeof(tutorMoves) / sizeof(tutorMoves[0]),
       tutorMoveMask = ((1u << tutorMoveCount) - 1u) << firstTutorMoveBit,
       firstFossilBit = firstTutorMoveBit + tutorMoveCount,
       masterBallCatch = 1u << (firstFossilBit + fossilRecipeCount),
       beastBallCatch = masterBallCatch << 1, ownsApplin = beastBallCatch << 1,
       eternatusCatch = ownsApplin << 1, zamazentaCatch = eternatusCatch << 1 };
_Static_assert(zamazentaCatch != 0 && firstFossilBit + fossilRecipeCount + 5 <= sizeof(unsigned) * CHAR_BIT,
               "Too many Pokémon activity bits");

typedef struct {
    uint32_t id;
    uint8_t gender;
    uint8_t name[26];
} ShieldTrainer;

typedef struct {
    NSUInteger slot; // One-based. Zero means no candidate observed.
    bool boxed;
} ShieldPokemonPosition;

typedef struct {
    unsigned species;
    uint8_t form;
    bool gigantamax;
    uint32_t decoration;
} ShieldPokemonForm;

typedef struct {
    unsigned activities;
    ShieldPokemonPosition friendshipCandidate;
    ShieldPokemonPosition effortCandidate;
    ShieldPokemonPosition applinCandidate;
    ShieldPokemonPosition rotomForms[rotomFormCount];
    ShieldPokemonPosition gigantamax[gigantamaxSpeciesCount];
    ShieldPokemonPosition alcremieForms[alcremieFormCount];
    ShieldPokemonPosition sinisteaForms[teaFormCount];
    ShieldPokemonPosition polteageistForms[teaFormCount];
} ShieldCollection;

static bool sameTrainerName(const uint8_t *left, const uint8_t *right) {
    if (!(left[0] || left[1])) return false;
    for (size_t i = 0; i < 26; i += 2) {
        if (left[i] != right[i] || left[i + 1] != right[i + 1]) return false;
        if (!(left[i] || left[i + 1])) return true;
    }
    return false;
}

static unsigned pokemonActivity(const uint8_t *slot, const ShieldTrainer *trainer,
                                NSMutableDictionary<NSNumber *, NSNumber *> *heldItems, ShieldPokemonForm *form) {
    // PK8 stores four shuffled 80-byte chunks under a second cipher.
    // The selector values 24–31 repeat the first eight orders.
    static const uint8_t orders[24][4] = {
        {0,1,2,3}, {0,1,3,2}, {0,2,1,3}, {0,3,1,2}, {0,2,3,1}, {0,3,2,1},
        {1,0,2,3}, {1,0,3,2}, {2,0,1,3}, {3,0,1,2}, {2,0,3,1}, {3,0,2,1},
        {1,2,0,3}, {1,3,0,2}, {2,1,0,3}, {3,1,0,2}, {2,3,0,1}, {3,2,0,1},
        {1,2,3,0}, {1,3,2,0}, {2,1,3,0}, {3,1,2,0}, {2,3,1,0}, {3,2,1,0},
    };
    if (decodeLE(slot + 4, 2, NULL)) return 0;
    uint32_t seed = (uint32_t)decodeLE(slot, 4, NULL);
    unsigned order = ((seed >> 13) & 31) % 24;
    uint8_t decrypted[pk8StoredSize];
    uint16_t checksum = 0;
    for (size_t i = 8; i < pk8StoredSize; i += 2) {
        seed = seed * 0x41C64E6D + 0x6073;
        uint16_t word = (uint16_t)decodeLE(slot + i, 2, NULL) ^ (uint16_t)(seed >> 16);
        checksum += word;
        decrypted[i] = (uint8_t)word;
        decrypted[i + 1] = word >> 8;
    }
    if (checksum != decodeLE(slot + 6, 2, NULL)) return 0;
    // The order lists which encrypted chunk contains each logical chunk.
    uint8_t pokemon[pk8StoredSize];
    for (size_t chunk = 0; chunk < 4; chunk++)
        memcpy(pokemon + 8 + chunk * pk8ChunkSize,
               decrypted + 8 + orders[order][chunk] * pk8ChunkSize, pk8ChunkSize);

    unsigned species = (unsigned)decodeLE(pokemon + 0x08, 2, NULL);
    if (!species || species > 898 || (pokemon[0x8F] & 0x40)) return 0;
    *form = (ShieldPokemonForm){.species = species, .form = pokemon[0x24], .gigantamax = (pokemon[0x16] & 0x10) != 0};
    if (species == alcremieSpecies) form->decoration = (uint32_t)decodeLE(pokemon + 0xE4, 4, NULL);
    unsigned held = (unsigned)decodeLE(pokemon + 0x0A, 2, NULL);
    if (held == fossilizedDrake || held == masterBallItem || held == beastBallItem || held == pokeDollItem ||
        (held && isHoldableReward(held)))
        heldItems[@(held)] = @(heldItems[@(held)].unsignedIntegerValue + 1);

    // These per-Pokémon outcomes and eligibility checks apply to the current collection.
    unsigned observed = species == 840 ? ownsApplin : 0;
    if (pokemon[0x34] & (1u << 3)) observed |= bestFriendsRibbon;
    if (pokemon[0x34] & (1u << 7)) observed |= effortRibbon;
    if (pokemon[0x3A] & (1u << 3)) observed |= towerMasterRibbon;
    if (pokemon[0x126] & 0x3F) observed |= hyperTrained;
    uint8_t handler = pokemon[0xC4];
    if (handler <= 1 && pokemon[handler ? 0xC8 : 0x112] == 255) observed |= bestFriendsReady;
    unsigned effort = 0;
    for (NSUInteger stat = 0x26; stat <= 0x2B; stat++) effort += pokemon[stat];
    if (effort == 510) observed |= effortReady;
    // The four active move slots exclude move reminder data.
    for (NSUInteger offset = 0x72; offset <= 0x78; offset += 2) {
        unsigned move = (unsigned)decodeLE(pokemon + offset, 2, NULL);
        if (!move) continue;
        for (NSUInteger index = 0; index < tutorMoveCount; index++)
            if (move == tutorMoves[index].move) observed |= 1u << (firstTutorMoveBit + index);
    }

    if (pokemon[0xDE] != 45 || (pokemon[0x22] & 1) ||
        decodeLE(pokemon + 0x0C, 4, NULL) != trainer->id ||
        (pokemon[0x125] >> 7) != trainer->gender ||
        !sameTrainerName(pokemon + 0xF8, trainer->name) ||
        decodeLE(pokemon + 0x120, 2, NULL)) return observed;

    unsigned level = pokemon[0x125] & 0x7F;
    unsigned location = (unsigned)decodeLE(pokemon + 0x122, 2, NULL);
    // PK8 Ball values differ from Bag item IDs. Poipole's gift retains its ball after evolving.
    if (location && pokemon[0x124] == 1) observed |= masterBallCatch;
    if (location && pokemon[0x124] == 26 && !(location == 244 && (species == 803 || species == 804)))
        observed |= beastBallCatch;
    switch (location) {
        case 12: return observed | route1Capture;
        case 18: return observed | route2Capture;
        case 40:
            if ((species == 848 || species == 849) && level == 1 && pokemon[0x124] == 11) observed |= nurseryToxel;
            break;
        case 66:
            if (species == 890 && level == 60) observed |= eternatusCatch;
            if (species == 889 && level == 70) observed |= zamazentaCatch;
            break;
        case 68:
            if (level == 10 && pokemon[0x124] == 4) {
                for (NSUInteger index = 0; index < fossilRecipeCount; index++)
                    if (species == fossilRecipes[index].nationalNumber) observed |= 1u << (firstFossilBit + index);
            }
            break;
        case 158:
            if ((species == 772 || species == 773) && level == 50 && pokemon[0x124] == 4) observed |= towerTypeNull;
            break;
    }
    return observed;
}

static void scanPokemonCollection(const uint8_t *bytes, size_t slots, BlockMask mask, const ShieldTrainer *trainer,
                                 bool boxed, ShieldCollection *collection,
                                 NSMutableDictionary<NSNumber *, NSNumber *> *heldItems) {
    for (size_t index = 0; index < slots; index++) {
        uint8_t slot[pk8SlotSize];
        for (size_t i = 0; i < sizeof(slot); i++) slot[i] = bytes[index * sizeof(slot) + i] ^ maskByte(&mask);
        ShieldPokemonForm form = {0};
        unsigned activities = pokemonActivity(slot, trainer, heldItems, &form);
        ShieldPokemonPosition position = {index + 1, boxed};
        if (form.species == rotomSpecies && form.form < rotomFormCount && !collection->rotomForms[form.form].slot)
            collection->rotomForms[form.form] = position;
        if (form.species == alcremieSpecies && form.form < alcremieFlavorCount && form.decoration < alcremieSweetCount) {
            NSUInteger variant = form.decoration * alcremieFlavorCount + form.form;
            if (!collection->alcremieForms[variant].slot) collection->alcremieForms[variant] = position;
        }
        if (form.form < teaFormCount) {
            if (form.species == sinisteaSpecies && !collection->sinisteaForms[form.form].slot)
                collection->sinisteaForms[form.form] = position;
            if (form.species == polteageistSpecies && !collection->polteageistForms[form.form].slot)
                collection->polteageistForms[form.form] = position;
        }
        if (form.gigantamax) {
            for (NSUInteger i = 0; i < gigantamaxSpeciesCount; i++) {
                if (gigantamaxSpecies[i].species != form.species) continue;
                if (form.form < gigantamaxSpecies[i].forms && !collection->gigantamax[i].slot)
                    collection->gigantamax[i] = position;
                break;
            }
        }
        if (!collection->friendshipCandidate.slot && (activities & bestFriendsReady) && !(activities & bestFriendsRibbon))
            collection->friendshipCandidate = position;
        if (!collection->effortCandidate.slot && (activities & effortReady) && !(activities & effortRibbon))
            collection->effortCandidate = position;
        if (!collection->applinCandidate.slot && (activities & ownsApplin))
            collection->applinCandidate = position;
        collection->activities |= activities;
    }
}

static NSString *pokemonPositionLabel(ShieldPokemonPosition position) {
    if (!position.slot) return nil;
    if (!position.boxed) return [NSString stringWithFormat:@"Party slot %lu", position.slot];
    NSUInteger index = position.slot - 1;
    return [NSString stringWithFormat:@"Box %lu, slot %lu", index / slotsPerBox + 1, index % slotsPerBox + 1];
}

static NSString *tutorMoveCompletion(NSString *key, unsigned activities) {
    if (!(activities & tutorMoveMask)) return nil;
    NSMutableArray<NSString *> *known = nil;
    NSUInteger total = 0;
    for (NSUInteger index = 0; index < tutorMoveCount; index++) {
        if (![tutorMoves[index].key isEqualToString:key]) continue;
        total++;
        if (!(activities & (1u << (firstTutorMoveBit + index)))) continue;
        if (!known) known = [NSMutableArray arrayWithCapacity:3];
        [known addObject:tutorMoves[index].name];
    }
    if (!known.count) return nil;
    if (total == 1) return [known.firstObject stringByAppendingString:@" known in your collection"];
    return [NSString stringWithFormat:@"%lu of %lu moves known in your collection · %@",
            known.count, total, [known componentsJoinedByString:@", "]];
}

static NSString *openingLocation(uint64_t map, uint64_t zone) {
    if (map == 0x9A3DF7D37DB70B41) {
        switch (zone) {
            case 0x019B5DC049D8CB3E: return @"Postwick";
            case 0x078BC1FF1A657844: return @"Route 1";
            case 0xE80BCEC03B7D6E23: return @"Wedgehurst";
            case 0x10355EFF1F4DB0B5:
            case 0x10355BFF1F4DAB9C: return @"Route 2";
        }
    }
    if (map == 0xDF864AE11FD1F74F && zone == 0x8F67CD45F405D66E) return @"Slumbering Weald";
    if (map == 0x2B77107F4A244C7A && zone == 0xB019E4C35D0B6FBF) return @"Research Lab · Wedgehurst";
    if (map == 0xE1F366164FC51572 && zone == 0x9A018D90DC5F1D15) return @"Pokémon Center · Wedgehurst";
    if (map == 0xD08669201CEB5B3E && zone == 0xA9AB2CAA935AB8AB) return @"Hop’s house · Postwick";
    if (map == 0xD08668201CEB598B && zone == 0xA9AB2DAA935ABA5E) return @"Leon’s room · Postwick";
    return nil;
}

typedef struct {
    uint64_t zone;
    DMGuideArea area;
    NSUInteger index;
} WildSubarea;

static const WildSubarea *wildSubareaForPlacement(uint64_t map, uint64_t zone) {
    if (map != 0x5742865396E549D0) return NULL;
    // Shield 1.3.2 base Wild Area placement zones, in guide subarea order.
    static const WildSubarea subareas[] = {
        {0x776776717EA4483E, DMGuideAreaWildArea, 0}, // Rolling Fields
        {0x776777717EA449F1, DMGuideAreaWildArea, 1}, // Dappled Grove
        {0x776778717EA44BA4, DMGuideAreaWildArea, 2}, // Watchtower Ruins
        {0x776779717EA44D57, DMGuideAreaWildArea, 3}, // East Lake Axewell
        {0x77677A717EA44F0A, DMGuideAreaWildArea, 4}, // West Lake Axewell
        {0x77677B717EA450BD, DMGuideAreaWildArea, 5}, // Axew’s Eye
        {0x77676C717EA43740, DMGuideAreaWildArea, 6}, // South Lake Miloch
        {0x77676D717EA438F3, DMGuideAreaWildArea, 7}, // Giant’s Seat
        {0x776AFA717EA75E61, DMGuideAreaWildArea, 8}, // North Lake Miloch
        {0x776E81717EAA799D, DMGuideAreaNorthWild, 0}, // Motostoke Riverbank
        {0x776E7E717EAA7484, DMGuideAreaNorthWild, 1}, // Bridge Field
        {0x7771E5717EAD5960, DMGuideAreaNorthWild, 2}, // Stony Wilderness
        {0x7771E8717EAD5E79, DMGuideAreaNorthWild, 3}, // Dusty Bowl
        {0x7771E7717EAD5CC6, DMGuideAreaNorthWild, 4}, // Giant’s Mirror
        {0x7771EA717EAD61DF, DMGuideAreaNorthWild, 5}, // Hammerlocke Hills
        {0x7771E9717EAD602C, DMGuideAreaNorthWild, 6}, // Giant’s Cap
        {0x7771EC717EAD6545, DMGuideAreaNorthWild, 7}, // Lake of Outrage
    };
    for (size_t i = 0; i < sizeof(subareas) / sizeof(subareas[0]); i++)
        if (subareas[i].zone == zone) return &subareas[i];
    return NULL;
}

static DMGuideArea placementArea(uint64_t map, uint64_t zone) {
    // Exact pairs from the Shield 1.3.2 placement tables. Transit-only zones are excluded.
    static const struct { uint64_t map, zone; DMGuideArea guide; } places[] = {
        {0x92DABAD379E43890, 0xE0D6E5E78C91F4A7, DMGuideAreaMotostoke},
        {0x92DABAD379E43890, 0xE0D6E6E78C91F65A, DMGuideAreaMotostoke},
        {0xD5B32339EF32161E, 0xBC0019AF7C29A129, DMGuideAreaMotostoke},
        {0xBA709439DF652483, 0xB2E97CAF76E496D8, DMGuideAreaMotostoke},
        {0x05EDD76967156C5C, 0x4DA2FF92F4867575, DMGuideAreaMotostoke},
        {0x968CA7F658D51431, 0x9EB6C735FAD546D8, DMGuideAreaMotostoke},
        {0xB120FF7D7083F540, 0xCFFBA69AFDF6F879, DMGuideAreaMotostoke},
        {0xE8A5785858276EA2, 0x490D42709F87B935, DMGuideAreaWildArea},
        {0x5742865396E549D0, 0x776775717EA4468B, DMGuideAreaWildArea},
        {0x92DABAD379E43890, 0x194B97FF2492111A, DMGuideAreaRoute3},
        {0xF8A8D9E12DD0828A, 0x75D83E45E5AA7953, DMGuideAreaGalarMine},
        {0x89C421D3749F350B, 0xDBCF5CFF0180B073, DMGuideAreaRoute4},
        {0x89C421D3749F350B, 0xF12207C040C1CE88, DMGuideAreaTurffield},
        {0x371DF746EA468953, 0x49529A72E22FC56E, DMGuideAreaTurffield},
        {0x9DA8BEDF11695A83, 0xB641F5C0EAA2E42C, DMGuideAreaTurffield},
        {0x89C421D3749F350B, 0xE4E595FF06C510D8, DMGuideAreaRoute5},
        {0xA209D5DA48009B3D, 0xD828AAE89C5F139C, DMGuideAreaRoute5},
        {0xC58D3CD3963ECAD2, 0x1C7150C0594994E5, DMGuideAreaHulbury},
        {0xDD4CD58D891E323E, 0x2B7C86C0D370D3C3, DMGuideAreaHulbury},
        {0xDD4CD48D891E308B, 0x2B7C87C0D370D576, DMGuideAreaHulbury},
        {0x4685B535D0DC55FC, 0x3C01E282A0F961DD, DMGuideAreaHulbury},
        {0x3F89FFB7F9EBA6BC, 0xADBFD15574453573, DMGuideAreaHulbury},
        {0x9B6894DD7C53383A, 0x3EC246133B01279F, DMGuideAreaHulbury},
#include "shield_guide_placements.inc"
    };
    for (size_t i = 0; i < sizeof(places) / sizeof(places[0]); i++)
        if (places[i].map == map && places[i].zone == zone) return places[i].guide;
    return DMGuideAreaUnknown;
}

static DMGuideArea guideArea(uint64_t map, uint64_t zone, NSString *name) {
    if ([name hasSuffix:@"Wedgehurst"]) return DMGuideAreaWedgehurst;
    if ([name isEqualToString:@"Route 2"]) return DMGuideAreaRoute2;
    return placementArea(map, zone);
}

// Installed before the host starts the guest and front end. Cleared for an
// unsupported build even if the caller supplies a module.
static const uint8_t *liveBase;
static DMGuideHeapRead liveRead;

void dm_shield_guide_configure_live(const char *build, const void *base, size_t size, DMGuideHeapRead read) {
    liveBase = base;
    liveRead = base && size >= dmShieldLocationRoot + sizeof(uint64_t) &&
        dm_shield_guide_available() && !strcmp(build, DM_SHIELD_GUIDE_BUILD) ? read : NULL;
}

static uint64_t liveRoot(size_t offset) {
    return __atomic_load_n((const uint64_t *)(liveBase + offset), __ATOMIC_RELAXED);
}

static bool readLiveField(uint64_t object, size_t offset, void *out, size_t size) {
    return object && !(object & 7) && object <= UINT64_MAX - offset - size &&
        liveRead(object + offset, out, size);
}

@implementation DMGuideLiveLocation
+ (instancetype)currentLocation {
    if (!liveRead) return nil;
    uint64_t object = liveRoot(dmShieldLocationRoot), mirrorRoot = liveRoot(dmShieldMirrorRoot);
    uint64_t mirror, primaryType, mirrorType, zone, pair[2], recheck[2], mirrorAgain, zoneAgain;
    if (!readLiveField(mirrorRoot, dmShieldMirrorPointer, &mirror, sizeof(mirror)) ||
        !readLiveField(object, 0, &primaryType, sizeof(primaryType)) ||
        primaryType != (uintptr_t)liveBase + dmShieldLocationVtable ||
        !readLiveField(mirror, dmShieldMirrorVtableField, &mirrorType, sizeof(mirrorType)) ||
        mirrorType != (uintptr_t)liveBase + dmShieldMirrorVtable ||
        !readLiveField(object, dmShieldLocationPair, pair, sizeof(pair)) ||
        !readLiveField(mirror, dmShieldMirrorZone, &zone, sizeof(zone)) || !zone || pair[1] != zone ||
        !readLiveField(object, dmShieldLocationPair, recheck, sizeof(recheck)) ||
        memcmp(pair, recheck, sizeof(pair)) ||
        !readLiveField(mirrorRoot, dmShieldMirrorPointer, &mirrorAgain, sizeof(mirrorAgain)) ||
        mirror != mirrorAgain || !readLiveField(mirror, dmShieldMirrorZone, &zoneAgain, sizeof(zoneAgain)) ||
        zone != zoneAgain || object != liveRoot(dmShieldLocationRoot) ||
        mirrorRoot != liveRoot(dmShieldMirrorRoot)) return nil;
    NSString *name = openingLocation(pair[0], zone);
    const WildSubarea *subarea = wildSubareaForPlacement(pair[0], zone);
    DMGuideArea area = subarea ? subarea->area : guideArea(pair[0], zone, name);
    if (area == DMGuideAreaUnknown) return nil;
    DMGuideLiveLocation *location = [self new];
    location->_area = area;
    location->_name = name ?: DMShieldGuide.areaNames[area];
    location->_placementBased = name == nil;
    if (subarea) {
        location->_wildSubarea = @(subarea->index);
        location->_name = [DMShieldGuide wildSubareasInArea:area][subarea->index];
    }
    return location;
}
@end

@interface DMGuideGalarDexEntry ()
@property (nonatomic, readwrite) NSInteger number;
@property (nonatomic, copy, readwrite) NSString *species;
@property (nonatomic, copy, readwrite) NSString *label;
@end

@implementation DMGuideGalarDexEntry
@end

typedef NS_ENUM(uint8_t, StadiumResolution) {
    StadiumUnobserved, StadiumReady, StadiumDebriefPending, StadiumResolved,
};

static const ShieldPostgameStadium *postgameStadiumForKey(NSString *key) {
    if (![key hasSuffix:@".postgame-stadium"]) return NULL;
    for (NSUInteger index = 0; index < postgameStadiumCount; index++)
        if ([key isEqualToString:postgameStadiums[index].key]) return &postgameStadiums[index];
    return NULL;
}

typedef struct {
    uint8_t deposits;
    bool eggReady;
} NurseryStatus;

static NSInteger nurseryIndexForKey(NSString *key) {
    if ([key isEqualToString:@"route5.nursery-deposit"]) return 0;
    if ([key isEqualToString:@"north-wild.nursery-deposit"]) return 1;
    return NSNotFound;
}

static const ShieldCardBackgroundTarget *cardBackgroundTargetForKey(NSString *key) {
    for (NSUInteger index = 0; index < sizeof(shieldCardBackgroundTargets) / sizeof(shieldCardBackgroundTargets[0]); index++) {
        if ([key isEqualToString:shieldCardBackgroundTargets[index].key]) return &shieldCardBackgroundTargets[index];
    }
    return NULL;
}

static NSString *const cardStyleSingular[] = {
    @"effect", @"frame", @"expression", @"pose", @"coating",
};
static NSString *const cardStylePlural[] = {
    @"effects", @"frames", @"expressions", @"poses", @"coatings",
};

static NSString *cardBackgroundUnlockLabel(const ShieldCardBackground *background) {
    NSString *label = background->count == 1 ? @"1 Card Maker background unlocked" :
        [NSString stringWithFormat:@"%u Card Maker backgrounds unlocked", background->count];
    const ShieldCardStyleUnlock *styles = cardStyleUnlockForFlag(background->flag);
    if (!styles) return label;
    NSMutableArray<NSString *> *options = [NSMutableArray array];
    for (NSUInteger index = 0; index < ShieldCardStyleCategoryCount; index++) {
        unsigned count = styles->counts[index];
        if (count) [options addObject:[NSString stringWithFormat:@"%u %@", count,
            count == 1 ? cardStyleSingular[index] : cardStylePlural[index]]];
    }
    return [label stringByAppendingFormat:@"\nAlso available · %@", [options componentsJoinedByString:@", "]];
}

@interface DMGuideSavedContext ()
@property (nonatomic, readwrite, nullable) NSString *location;
@property (nonatomic, readwrite) BOOL placementBasedLocation;
@property (nonatomic, readwrite, nullable) NSNumber *wildSubarea;
@property (nonatomic, readwrite) DMGuideArea area;
@property (nonatomic, readwrite, nullable) NSNumber *mainPhase;
@property (nonatomic, readwrite, nullable) NSNumber *guidance;
@property (nonatomic, readwrite, nullable) NSNumber *pokedexUnlocked;
@property (nonatomic, nullable) NSNumber *minccinoStage;
@property (nonatomic, nullable) NSNumber *motostokeTrade;
@property (nonatomic, nullable) NSNumber *motostokeFountain;
@property (nonatomic, nullable) NSNumber *hulburyDelivery;
@property (nonatomic) BOOL hulburyTrade;
@property (nonatomic) BOOL toxelGiftConversation;
@property (nonatomic, copy) NSIndexSet *savedFlags;
@property (nonatomic, copy) NSIndexSet *knownGymFlags;
@property (nonatomic, copy) NSIndexSet *knownCafeFlags;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSNumber *> *activityWork;
@property (nonatomic, copy) NSIndexSet *positiveActivityRecords;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSNumber *> *cardBackgroundRecords;
@property (nonatomic, nullable) NSNumber *raidBattles;
@property (nonatomic, nullable) NSNumber *eggsHatched;
@property (nonatomic, nullable) NSNumber *raidCaptures;
@property (nonatomic, nullable) NSNumber *hasFireBadge;
@property (nonatomic, nullable) NSNumber *isChampion;
@property (nonatomic, nullable) NSNumber *waterModeRecorded;
@property (nonatomic, nullable) NSNumber *rallyFinishes;
@property (nonatomic, nullable) NSNumber *towerSinglesWins;
@property (nonatomic, nullable) NSNumber *towerDoublesWins;
@property (nonatomic) unsigned pokemonActivities;
@property (nonatomic, copy, nullable) NSString *friendshipRibbonCandidate;
@property (nonatomic, copy, nullable) NSString *effortRibbonCandidate;
@property (nonatomic, copy, nullable) NSString *applinCandidate;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSString *> *rotomForms;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSString *> *gigantamaxPositions;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSString *> *alcremiePositions;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSString *> *sinisteaPositions;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSString *> *polteageistPositions;
@property (nonatomic) BOOL pokemonCollectionKnown;
@property (nonatomic) uint8_t rotomSeenForms;
@property (nonatomic, copy, nullable) NSString *cyclingOutfitType;
@property (nonatomic, copy) NSIndexSet *giftItems;
@property (nonatomic, copy, nullable) NSIndexSet *recordedBagItems;
@property (nonatomic, copy, nullable) NSIndexSet *ownedTMs;
@property (nonatomic, copy, nullable) NSDictionary<NSNumber *, NSNumber *> *bagQuantities;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSNumber *> *heldItemQuantities;
@property (nonatomic, readonly) BOOL memoryInventoryKnown;
@property (nonatomic, copy) NSIndexSet *npcLeagueCards;
@property (nonatomic, copy, nullable) NSIndexSet *uniformsInWardrobe;
@property (nonatomic, copy, nullable) NSData *wardrobeOwnership;
@property (nonatomic) uint8_t wardrobeAvatar;
@property (nonatomic, nullable) NSNumber *marketRequestOutstanding;
@property (nonatomic, copy) NSIndexSet *permanentHiddenPickups;
@property (nonatomic, copy) NSIndexSet *hiddenPickupsAwaitingRespawn;
@property (nonatomic, copy) NSIndexSet *knownBaseRecurringPickups;
@property (nonatomic, copy, nullable) NSIndexSet *cookedCurryRecipes;
@property (nonatomic, copy, nullable) NSIndexSet *galarDexCaught;
@property (nonatomic, copy, nullable) NSIndexSet *galarDexSeen;
- (void)resolveMap:(uint64_t)map zone:(uint64_t)zone;
- (NSUInteger)unlockedCampToyCount;
- (NSUInteger)weatherRewardCount;
- (NSUInteger)ownedSilvallyMemoryCount;
- (NSUInteger)quantityInCollection:(unsigned)item;
- (StadiumResolution)resolutionForStadium:(const ShieldPostgameStadium *)stadium;
- (NSInteger)bikeTurboLevel;
- (BOOL)hasWaterMode;
- (NSUInteger)collectedCountForHiddenPickup:(const HiddenPickup *)pickup total:(NSUInteger *)total;
@end

@implementation DMGuideSavedContext {
    NurseryStatus _nurseries[2];
}
+ (instancetype)decode:(NSData *)data {
    if (data.length <= CC_SHA256_DIGEST_LENGTH || data.length > maxSaveSize) return nil;
    size_t length = data.length - CC_SHA256_DIGEST_LENGTH;
    if (!checkIntegrity(data.bytes, length)) return nil;
    __attribute__((objc_precise_lifetime)) NSMutableData *body = [NSMutableData dataWithLength:length];
    uint8_t *clear = body.mutableBytes;
    const uint8_t *raw = data.bytes;
    for (size_t i = 0; i < length; i++) clear[i] = raw[i] ^ fileMask[i % (sizeof(fileMask) - 1)];

    DMGuideSavedContext *result = [self new];
    uint64_t map = 0, zone = 0;
    bool shield = false;
    ShieldTrainer trainer = {0};
    const uint8_t *party = NULL, *boxes = NULL;
    const uint8_t *wardrobe = NULL;
    BlockMask partyMask = {0}, boxMask = {0};
    BlockMask wardrobeMask = {0};
    uint8_t wardrobeGender = UINT8_MAX;
    size_t partyCount = 0;
    enum { partySlots = 6, boxSlots = 32 * slotsPerBox };
    uint32_t previousKey = 0;
    NSMutableIndexSet *flags = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *gymFlags = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *cafeFlags = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *permanentHidden = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *hiddenAwaitingRespawn = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *knownBaseRecurring = [NSMutableIndexSet indexSet];
    NSMutableDictionary<NSNumber *, NSNumber *> *work = [NSMutableDictionary dictionary];
    for (size_t offset = 0; offset < length;) {
        if (length - offset < 5) return nil;
        uint32_t key = (uint32_t)decodeLE(clear + offset, 4, NULL);
        if (offset && key <= previousKey) return nil;
        previousKey = key;
        offset += 4;
        BlockMask mask = blockMask(key);
        uint8_t type = clear[offset++] ^ maskByte(&mask);
        size_t size = 0;
        if (type == object || type == array) {
            if (length - offset < (type == array ? 5u : 4u)) return nil;
            size = (size_t)decodeLE(clear + offset, 4, &mask);
            offset += 4;
            if (type == array) {
                uint8_t element = clear[offset++] ^ maskByte(&mask);
                size_t width = element == boolElement ? 1 : scalarSize(element);
                if (!width || size > (length - offset) / width) return nil;
                size *= width;
            }
        } else if (type != boolFalse && type != boolTrue) {
            size = scalarSize(type);
            if (!size) return nil;
        }
        if (size > length - offset) return nil;

        const uint8_t *value = clear + offset;
        if (type == object) {
            switch (key) {
                case 0x0D66012C:
                    if (size == boxSlots * pk8SlotSize) { boxes = value; boxMask = mask; }
                    break;
                case 0x1177C2C4:
                    if (size == 0x12F8) {
                        NSMutableDictionary<NSNumber *, NSNumber *> *quantities = [NSMutableDictionary dictionary];
                        NSMutableIndexSet *ownedTMs = [NSMutableIndexSet indexSet];
                        NSMutableIndexSet *recorded = [NSMutableIndexSet indexSet];
                        result.giftItems = giftItemsInBag(value, mask, quantities, ownedTMs, recorded);
                        result.recordedBagItems = recorded;
                        result.ownedTMs = ownedTMs;
                        result.bagQuantities = quantities;
                    }
                    break;
                case 0x16AAA7FA:
                    if (size >= 0x6008) map = readObjectLE(value, 0x6000, 8, mask);
                    break;
                case 0x2D6FBA6A: {
                    enum { nurserySize = 0x2B8, secondSlot = 0x149, waitingEgg = 0x2A0 };
                    if (size != 2 * nurserySize) break;
                    for (NSUInteger index = 0; index < 2; index++) {
                        size_t base = index * nurserySize;
                        uint64_t first = readObjectLE(value, base, 1, mask);
                        uint64_t second = readObjectLE(value, base + secondSlot, 1, mask);
                        bool ready = readObjectLE(value, base + waitingEgg, 1, mask) != 0;
                        if (first <= 1 && second <= 1)
                            result->_nurseries[index] = (NurseryStatus){(uint8_t)(first + second), ready};
                    }
                    break;
                }
                case 0x37DA95A3:
                    if (size == recordCount * sizeof(int32_t)) {
                        NSMutableIndexSet *completed = [NSMutableIndexSet indexSet];
                        NSMutableDictionary<NSNumber *, NSNumber *> *cardRecords = [NSMutableDictionary dictionary];
                        for (NSUInteger index = 0; index < recordCount; index++) {
                            int32_t count = (int32_t)decodeLE(value + index * sizeof(count), sizeof(count), &mask);
                            if (count > 0) [completed addIndex:index];
                            if (index >= firstCardBackgroundRecord && index <= lastCardBackgroundRecord && count >= 0)
                                cardRecords[@(index)] = @(count);
                            if (index == eggHatchRecord && count >= 0) result.eggsHatched = @(count);
                            if (index == raidBattleRecord && count >= 0) result.raidBattles = @(count);
                            if (index == raidCaptureRecord && count >= 0) result.raidCaptures = @(count);
                            if (index == rallyFinishRecord && count >= 0) result.rallyFinishes = @(count);
                            if (index == towerSinglesWinRecord && count >= 0) result.towerSinglesWins = @(count);
                            if (index == towerDoublesWinRecord && count >= 0) result.towerDoublesWins = @(count);
                        }
                        result.positiveActivityRecords = completed;
                        result.cardBackgroundRecords = cardRecords;
                    }
                    break;
                case 0x6148F6AC: case 0xE479EE37: case 0xE579EFCA:
                    if (size == hiddenItemBlockSize) {
                        NSUInteger group = key == 0x6148F6AC ? 0 : key == 0xE479EE37 ? 1 : 2;
                        for (NSUInteger index = 0; index < hiddenItemsPerBlock; index++) {
                            uint8_t state = (uint8_t)decodeLE(value + index * hiddenItemEntrySize, hiddenItemEntrySize, &mask);
                            NSUInteger id = group * hiddenItemsPerBlock + index;
                            if (state == hiddenItemCollectedPermanently) [permanentHidden addIndex:id];
                            if (state == hiddenItemWaitingForRespawn) [hiddenAwaitingRespawn addIndex:id];
                            if (group == 0 && (state == hiddenItemUninitialized || state == hiddenItemActive ||
                                               state == hiddenItemWaitingForRespawn))
                                [knownBaseRecurring addIndex:id];
                        }
                    }
                    break;
                case 0x6EB72940:
                    if (size == curryRecipeCount * curryRecordSize)
                        result.cookedCurryRecipes = cookedCurryRecipes(value, mask);
                    break;
                case 0x4716C404:
                    if (size == galarDexCount * galarDexEntrySize) {
                        NSMutableIndexSet *caught = [NSMutableIndexSet indexSet];
                        NSMutableIndexSet *seen = [NSMutableIndexSet indexSet];
                        for (NSUInteger index = 0; index < galarDexCount; index++) {
                            const uint8_t *entry = value + index * galarDexEntrySize;
                            bool hasSeenForm = false;
                            for (size_t offset = 0; offset < galarDexSeenBytes; offset += sizeof(uint64_t)) {
                                uint64_t forms = decodeLE(entry + offset, sizeof(forms), &mask);
                                hasSeenForm |= forms != 0;
                                if (index == rotomDexNumber - 1)
                                    result.rotomSeenForms |= (uint8_t)(forms & ((1u << rotomFormCount) - 1));
                            }
                            if (hasSeenForm) [seen addIndex:index];
                            if ((entry[galarDexSeenBytes] ^ maskByte(&mask)) & 1) [caught addIndex:index];
                            for (size_t offset = galarDexSeenBytes + 1; offset < galarDexEntrySize; offset++)
                                maskByte(&mask);
                        }
                        result.galarDexCaught = caught;
                        result.galarDexSeen = seen;
                    }
                    break;
                case 0x2985FE5D:
                    if (size == partySlots * pk8SlotSize + 4) {
                        partyCount = (size_t)readObjectLE(value, partySlots * pk8SlotSize, 1, mask);
                        if (partyCount <= partySlots) { party = value; partyMask = mask; }
                    }
                    break;
                case 0x7BE8A4C6:
                    if (size == 32) zone = readObjectLE(value, 8, 8, mask);
                    break;
                case 0xB1C26FB0:
                    if (size == baseCardCount * cardEntrySize) {
                        // The entry's first byte is ownership. The remaining bytes hold metadata.
                        NSMutableIndexSet *cards = [NSMutableIndexSet indexSet];
                        for (NSUInteger index = 0; index < baseCardCount; index++)
                            if (readObjectLE(value, index * cardEntrySize, 1, mask) == 1) [cards addIndex:index];
                        result.npcLeagueCards = cards;
                    }
                    break;
                case 0xD224F9AC:
                    if (size == wardrobeSize) { wardrobe = value; wardrobeMask = mask; }
                    break;
                case 0xF25C070E:
                    if (size > 0xA4) shield = readObjectLE(value, 0xA4, 1, mask) == 45;
                    if (size == 0x110) {
                        wardrobeGender = (uint8_t)readObjectLE(value, 0xA5, 1, mask);
                        static NSString *const colors[] = {
                            @"Normal", @"Fire", @"Water", @"Bug", @"Fairy", @"Electric",
                            @"Psychic", @"Ghost", @"Poison", @"Flying", @"Dragon", @"Dark",
                            @"Ground", @"Grass", @"Steel", @"Fighting", @"Rock", @"Ice",
                        };
                        unsigned color = (unsigned)readObjectLE(value, 5, 1, mask);
                        if (color > 0 && color <= sizeof(colors) / sizeof(colors[0]))
                            result.cyclingOutfitType = colors[color - 1];
                    }
                    if (size >= 0xB0 + sizeof(trainer.name)) {
                        trainer.id = (uint32_t)readObjectLE(value, 0xA0, 4, mask);
                        trainer.gender = (uint8_t)readObjectLE(value, 0xA5, 1, mask);
                        for (size_t i = 0; i < 0xB0; i++) maskByte(&mask);
                        for (size_t i = 0; i < sizeof(trainer.name); i++)
                            trainer.name[i] = value[0xB0 + i] ^ maskByte(&mask);
                    }
                    break;
            }
        } else if (type == u8) {
            switch (key) {
                case towerSinglesPoints: case towerDoublesPoints:
                case towerSinglesHighest: case towerDoublesHighest:
                    work[@(key)] = @(decodeLE(value, 1, &mask));
                    break;
            }
        } else if (type == u16 && (key == towerSinglesRewardWins || key == towerDoublesRewardWins)) {
            uint64_t wins = decodeLE(value, 2, &mask);
            if (wins <= 300) work[@(key)] = @(wins);
        } else if (type == u32) {
            if (key == 0xBB7B57FB) result.mainPhase = @(decodeLE(value, 4, &mask));
            if (key == 0xC4F35C2E) result.guidance = @(decodeLE(value, 4, &mask));
            if (key == 0xAA86248B) result.minccinoStage = @(decodeLE(value, 4, &mask));
            if (key == 0xC10889B1) result.hulburyDelivery = @(decodeLE(value, 4, &mask));
            switch (key) {
                case letterProgress: case detectiveProgress: case riddleProgress: case outfitProgress: case applinProgress:
                case birthdayMonth: case birthdayDay: case marnieSmileProgress:
                case rallyHighScore: case bikeChargeLimit: case diggingBestSkill: case diggingBestStamina: case weatherLesson:
                case championTournamentWins: case masterBallGiftStage: case fireMissionScore:
                case cafeMotostokeRoll: case cafeHammerlockeRoll: case cafeWyndonRoll:
                case marketToday: case marketYesterday: case marketTomorrow: case buyerItem:
                case 0x6701AF09: case typeNullGiftProgress:
                case hulburyIncident: case motostokeIncident: case hammerlockeIncident: case stowIncident:
                case ballonleaIncident: case circhesterIncident:
                    work[@(key)] = @(decodeLE(value, 4, &mask));
                    break;
            }
        } else if (type == boolFalse || type == boolTrue) {
            if (key == cafeMotostokeUsed || key == cafeHammerlockeUsed || key == cafeWyndonUsed)
                [cafeFlags addIndex:key];
            if (key == 0xED6E814D) result.pokedexUnlocked = @(type == boolTrue);
            if (key == 0x4F1AFB66) result.motostokeTrade = @(type == boolTrue);
            if (key == 0x42FF3B26) result.motostokeFountain = @(type == boolTrue);
            if (key == 0x4F18C076) result.hulburyTrade = type == boolTrue;
            if (key == 0xC41B40F7) result.toxelGiftConversation = type == boolTrue;
            if (key == buyerRequestOutstanding) result.marketRequestOutstanding = @(type == boolTrue);
            if (key == fireBadge) result.hasFireBadge = @(type == boolTrue);
            if (key == gameClear) result.isChampion = @(type == boolTrue);
            if (key == bikeWaterUnlock) result.waterModeRecorded = @(type == boolTrue);
            for (NSUInteger index = 0; index < shieldGymCount; index++) {
                const ShieldGym *gym = &shieldGyms[index];
                if (key == gym->missionFlag || key == gym->badgeFlag) {
                    [gymFlags addIndex:key];
                    break;
                }
            }
            if (type == boolTrue) [flags addIndex:key];
        }
        offset += size;
    }
    if (!shield) return nil;
    if (wardrobe && wardrobeGender < 2) {
        result.wardrobeAvatar = wardrobeGender;
        result.wardrobeOwnership = wardrobeOwnership(wardrobe, wardrobeMask);
        result.uniformsInWardrobe = ownedUniforms(result.wardrobeOwnership.bytes, wardrobeGender);
    }
    result.savedFlags = flags;
    result.knownGymFlags = gymFlags;
    result.knownCafeFlags = cafeFlags;
    result.activityWork = work;
    result.permanentHiddenPickups = permanentHidden;
    result.hiddenPickupsAwaitingRespawn = hiddenAwaitingRespawn;
    result.knownBaseRecurringPickups = knownBaseRecurring;
    ShieldCollection collection = {0};
    NSMutableDictionary<NSNumber *, NSNumber *> *heldItems = [NSMutableDictionary dictionary];
    if (party) scanPokemonCollection(party, partyCount, partyMask, &trainer, false, &collection, heldItems);
    if (boxes) scanPokemonCollection(boxes, boxSlots, boxMask, &trainer, true, &collection, heldItems);
    result.heldItemQuantities = heldItems;
    result.pokemonCollectionKnown = party && boxes;
    NSMutableDictionary<NSNumber *, NSString *> *rotomForms = [NSMutableDictionary dictionary];
    for (NSUInteger form = 0; form < rotomFormCount; form++) {
        NSString *position = pokemonPositionLabel(collection.rotomForms[form]);
        if (position) rotomForms[@(form)] = position;
    }
    result.rotomForms = rotomForms;
    NSMutableDictionary<NSNumber *, NSString *> *gigantamax = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < gigantamaxSpeciesCount; i++) {
        NSString *position = pokemonPositionLabel(collection.gigantamax[i]);
        if (position) gigantamax[@(i)] = position;
    }
    result.gigantamaxPositions = gigantamax;
    NSMutableDictionary<NSNumber *, NSString *> *alcremie = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < alcremieFormCount; i++) {
        NSString *position = pokemonPositionLabel(collection.alcremieForms[i]);
        if (position) alcremie[@(i)] = position;
    }
    result.alcremiePositions = alcremie;
    NSMutableDictionary<NSNumber *, NSString *> *sinistea = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSNumber *, NSString *> *polteageist = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < teaFormCount; i++) {
        NSString *base = pokemonPositionLabel(collection.sinisteaForms[i]);
        NSString *evolved = pokemonPositionLabel(collection.polteageistForms[i]);
        if (base) sinistea[@(i)] = base;
        if (evolved) polteageist[@(i)] = evolved;
    }
    result.sinisteaPositions = sinistea;
    result.polteageistPositions = polteageist;
    result.pokemonActivities = collection.activities;
    result.friendshipRibbonCandidate = pokemonPositionLabel(collection.friendshipCandidate);
    result.effortRibbonCandidate = pokemonPositionLabel(collection.effortCandidate);
    result.applinCandidate = pokemonPositionLabel(collection.applinCandidate);
    [result resolveMap:map zone:zone];
    return result;
}

- (void)resolveMap:(uint64_t)map zone:(uint64_t)zone {
    const WildSubarea *subarea = wildSubareaForPlacement(map, zone);
    self.wildSubarea = subarea ? @(subarea->index) : nil;
    if (subarea) {
        self.area = subarea->area;
        self.location = [DMShieldGuide wildSubareasInArea:self.area][subarea->index];
        self.placementBasedLocation = YES;
        return;
    }
    self.location = openingLocation(map, zone);
    self.area = guideArea(map, zone, self.location);
    self.placementBasedLocation = self.location == nil && self.area != DMGuideAreaUnknown;
    if (self.placementBasedLocation) self.location = DMShieldGuide.areaNames[self.area];
}

- (BOOL)hasWaterMode {
    return [self.savedFlags containsIndex:bikeWaterUnlock] && [self.giftItems containsIndex:waterBike];
}

- (NSString *)hintForActivity:(DMGuideActivity *)activity {
    if (activity.waterModeHint && [self hasWaterMode]) return activity.waterModeHint;
    return activity.hint;
}

- (NSString *)activityEvidenceForKey:(NSString *)key {
    const ShieldCardBackgroundTarget *target = cardBackgroundTargetForKey(key);
    if (target) {
        NSNumber *count = self.cardBackgroundRecords[@(target->record)];
        if (count && count.unsignedIntValue < target->target) {
            NSString *current = [NSNumberFormatter localizedStringFromNumber:count numberStyle:NSNumberFormatterDecimalStyle];
            NSString *goal = [NSNumberFormatter localizedStringFromNumber:@(target->target) numberStyle:NSNumberFormatterDecimalStyle];
            return [NSString stringWithFormat:@"%@ of %@", current, goal];
        }
    }
    NSInteger nursery = nurseryIndexForKey(key);
    if (nursery != NSNotFound) {
        NurseryStatus status = _nurseries[nursery];
        if (status.eggReady && status.deposits == 1) return @"1 of 2 Pokémon at the Nursery · Egg ready to collect";
        if (status.eggReady) return @"Egg ready to collect";
        if (status.deposits == 1) return @"1 of 2 Pokémon at the Nursery";
    }
    if ([key isEqualToString:@"motostoke.gym-mission"] && self.mainPhase.intValue == 785) {
        NSNumber *score = self.activityWork[@(fireMissionScore)];
        if (score && score.unsignedIntValue <= 6) {
            unsigned points = score.unsignedIntValue;
            return points >= 5 ? [NSString stringWithFormat:@"5-point target reached · %u points recorded", points] :
                [NSString stringWithFormat:@"%u of 5 mission points", points];
        }
    }
    const ShieldPostgameStadium *stadium = postgameStadiumForKey(key);
    if (stadium) {
        switch ([self resolutionForStadium:stadium]) {
            case StadiumReady: return @"Incident ready";
            case StadiumDebriefPending: return @"Finish the stadium debrief";
            default: break;
        }
    }
    const HiddenPickup *pickup = hiddenPickupForKey(key);
    if (pickup && !pickup->recurring) {
        NSUInteger total;
        NSUInteger collected = [self collectedCountForHiddenPickup:pickup total:&total];
        if (collected > 0 && collected < total)
            return [NSString stringWithFormat:@"%lu of %lu sparkles collected", collected, total];
    }
    if (self.hulburyTrade && [key isEqualToString:@"hulbury.trade"]) return @"Trade recorded in save";
    if ([key isEqualToString:@"hammerlocke.friendship-ribbon"] && self.friendshipRibbonCandidate)
        return [self.friendshipRibbonCandidate stringByAppendingString:@" · maximum friendship"];
    if ([key isEqualToString:@"hammerlocke.effort-ribbon"] && self.effortRibbonCandidate)
        return [self.effortRibbonCandidate stringByAppendingString:@" · 510 total base points"];
    if ([key isEqualToString:@"hammerlocke.applin"]) {
        int stage = self.activityWork[@(applinProgress)].intValue;
        BOOL requestRecorded = stage == 1 || stage == 2;
        if (self.applinCandidate) {
            NSString *available = [self.applinCandidate stringByAppendingString:@" · Applin available"];
            return requestRecorded ? [available stringByAppendingString:@" · Request discussed"] : available;
        }
        if (requestRecorded) return @"Request discussed";
    }
    if ([key isEqualToString:@"wild-area.chloe"]) {
        if (self.isChampion.boolValue) return @"Champion team · Lv. 60 Inteleon, Rillaboom and Cinderace";
        if (self.isChampion && self.hasFireBadge) {
            return self.hasFireBadge.boolValue ? @"Fire Badge team · Lv. 30 Raboot, Drizzile and Thwackey" :
                @"Opening team · Lv. 13 Grookey, Scorbunny and Sobble";
        }
    }
    if ([key hasPrefix:@"route6.fossil."] && self.bagQuantities) {
        for (NSUInteger index = 0; index < fossilRecipeCount; index++) {
            const ShieldFossilRecipe *recipe = &fossilRecipes[index];
            if (![key isEqualToString:recipe->key]) continue;
            unsigned upper = self.bagQuantities[@(recipe->upperPiece)].unsignedIntValue;
            unsigned lower = self.bagQuantities[@(recipe->lowerPiece)].unsignedIntValue;
            return [NSString stringWithFormat:@"%@ · %@ ×%u, %@ ×%u", upper && lower ? @"Enough for this recipe" : @"In your Bag",
                    fossilPieceName(recipe->upperPiece), upper, fossilPieceName(recipe->lowerPiece), lower];
        }
    }
    if ([key isEqualToString:@"hammerlocke.weather-gifts"]) {
        NSUInteger count = [self weatherRewardCount];
        if ([self.savedFlags containsIndex:weatherBonus])
            return [NSString stringWithFormat:@"%lu of %d weather rewards recorded · Bonus visit recorded",
                    count, weatherRewardCount];
        NSNumber *lesson = self.activityWork[@(weatherLesson)];
        NSArray *weather = @[@"Harsh sunlight", @"Rain", @"Hail", @"Sandstorm"];
        if (lesson && lesson.unsignedIntegerValue < weather.count)
            return [NSString stringWithFormat:@"%lu of %d weather rewards recorded · Next lesson is %@",
                    count, weatherRewardCount, weather[lesson.unsignedIntegerValue]];
        if (count)
            return [NSString stringWithFormat:@"%lu of %d weather rewards recorded", count, weatherRewardCount];
    }
    if (self.toxelGiftConversation && [key isEqualToString:@"route5.toxel"]) return @"Gift conversation recorded";
    if ([key hasPrefix:@"hulbury.delivery-"]) return DMGuideHulburyDeliveryEvidence(key, self.hulburyDelivery);
    NSInteger ballGuy = self.activityWork[@0x6701AF09].integerValue;
    if ([key isEqualToString:@"motostoke.ball-guy"] && (ballGuy == 1 || ballGuy == 2)) return @"Introduction gift interaction recorded";
    if ([key isEqualToString:@"motostoke.ball-guy-card"] && ballGuy == 2) return @"Champion card interaction recorded";
    if ([key isEqualToString:@"battle-tower.type-null"] && self.activityWork[@(typeNullGiftProgress)].integerValue == 1)
        return @"Type: Null gift sequence recorded";
    if ([key isEqualToString:@"battle-tower.memories"]) {
        BOOL giftRecorded = self.activityWork[@(typeNullGiftProgress)].integerValue == 1;
        NSUInteger count = self.ownedSilvallyMemoryCount;
        if (self.memoryInventoryKnown || count) {
            NSString *status = [NSString stringWithFormat:@"%lu of %d Memories found", count, silvallyMemoryCount];
            return giftRecorded ? [status stringByAppendingString:@" · Gift sequence recorded"] : status;
        }
        if (giftRecorded) return @"Gift sequence recorded";
    }
    NSInteger letter = self.activityWork[@(letterProgress)].integerValue;
    if ([key isEqualToString:@"hammerlocke.letter"] && letter >= 2 && letter <= 4) return @"Letter accepted";
    if ([key isEqualToString:@"ballonlea.letter"] && (letter == 3 || letter == 4)) return @"Letter delivery recorded";
    if ([key isEqualToString:@"hammerlocke.letter-return"] && letter == 4) return @"Return visit recorded";
    if ([key isEqualToString:@"circhester.detective"] && self.activityWork[@(detectiveProgress)].integerValue == 5) return @"Case resolution recorded";
    if ([key isEqualToString:@"turffield.riddle"] && self.activityWork[@(riddleProgress)].integerValue == 4) return @"Riddle resolution recorded";
    if ([key isEqualToString:@"ballonlea.fire-outfit"] && self.activityWork[@(outfitProgress)].integerValue == 2) return @"Outfit request follow-up recorded";
    if ([key isEqualToString:@"wild-area.camp-toys"]) {
        NSUInteger count = self.unlockedCampToyCount;
        if (count) return [NSString stringWithFormat:@"%lu of %d bonus camp toys unlocked", count, campToyCount];
    }
    NSUInteger buyerRequest = self.activityWork[@(buyerItem)].unsignedIntegerValue;
    if ([key isEqualToString:@"stow.buyer"] && [self.savedFlags containsIndex:dailyBuyerInitialized] &&
        self.marketRequestOutstanding && buyerRequest > 0 && buyerRequest < marketBuyerItemCount)
        return self.marketRequestOutstanding.boolValue ? @"Buyer request open at the last save" : @"Sale recorded in the last save";
    NSUInteger teaForm = teaFormForActivity(key);
    if (teaForm != NSNotFound) {
        NSString *position = self.sinisteaPositions[@(teaForm)];
        if (position) {
            NSNumber *item = @(teaEvolutions[teaForm].item);
            if (self.bagQuantities[item].unsignedIntegerValue)
                return [NSString stringWithFormat:@"%@ · %@ in Bag", position, teaEvolutions[teaForm].pot];
            if (self.heldItemQuantities[item].unsignedIntegerValue)
                return [NSString stringWithFormat:@"%@ · %@ held by a Pokémon", position, teaEvolutions[teaForm].pot];
            return [position stringByAppendingString:@" · Sinistea available"];
        }
    }
    if ([key isEqualToString:@"north-wild.rally-volt-switch"]) {
        int best = self.activityWork[@(rallyHighScore)].intValue;
        if (best > 0 && ![self.savedFlags containsIndex:rallyVoltSwitch]) {
            NSString *status = best > rallyVoltSwitchScore ? @" · point target reached" : @"";
            return [NSString stringWithFormat:@"Best score %d%@", best, status];
        }
    }
    if ([key isEqualToString:@"north-wild.rally-fast-ball"] && self.rallyFinishes)
        return [NSString stringWithFormat:@"%d of %d runs finished", MIN(self.rallyFinishes.intValue, rallyFastBallFinishes),
            rallyFastBallFinishes];
    if ([key isEqualToString:@"north-wild.bike-turbo"]) {
        NSInteger level = self.bikeTurboLevel;
        if (level >= 0 && level < bikeUpgradeCount) {
            NSArray<NSString *> *prices = @[@"1,000", @"3,000", @"5,000"];
            return [NSString stringWithFormat:@"%ld of %d upgrades · next costs %@ W", (long)level, bikeUpgradeCount, prices[level]];
        }
    }
    if ([key isEqualToString:@"circhester.shiny-charm"] && self.galarDexCaught &&
        ![self.savedFlags containsIndex:shinyCharmVisit]) {
        if (self.galarDexCaught.count == galarDexCount) return @"Galar Pokédex complete · visit the director";
        return [NSString stringWithFormat:@"%lu of %d Galar Pokémon caught", self.galarDexCaught.count, galarDexCount];
    }
    for (size_t i = 0; i < giftRewardCount; i++)
        if ([key isEqualToString:giftRewards[i].key] && [self.savedFlags containsIndex:giftRewards[i].flag])
            return giftRewards[i].eventLabel;
    static const struct { __unsafe_unretained NSString *key, *label; uint32_t flag; } bindings[] = {
        {@"turffield.trade", @"Trade recorded in save", 0x4F18BEC3},
        {@"hammerlocke.trade", @"Trade recorded in save", 0x4F18C229},
        {@"stow.trade", @"Trade recorded in save", 0x4F18C58F},
        {@"ballonlea.trade", @"Trade recorded in save", 0x4F18C742},
        {@"circhester.trade", @"Trade recorded in save", 0x4F18CAA8},
        {@"spikemuth.trade", @"Trade recorded in save", 0x4F18CC5B},
        {@"wyndon.trade", @"Trade recorded in save", 0x4F1AFD19},
        {@"turffield.ball-guy", @"Friend Ball gift interaction recorded", 0x433FE7E3},
        {@"hulbury.ball-guy", @"Lure Ball gift interaction recorded", 0xA0FD1A06},
        {@"hammerlocke.ball-guy", @"Level Ball gift interaction recorded", 0x972FAA6D},
        {@"stow.ball-guy", @"Heavy Ball gift interaction recorded", 0x04E4442C},
        {@"ballonlea.ball-guy", @"Love Ball gift interaction recorded", 0xA90E5370},
        {@"circhester.ball-guy", @"Moon Ball gift interaction recorded", 0xEED31C0A},
        {@"wyndon.ball-guy", @"Dream Ball gift interaction recorded", 0x4209950F},
        {@"stow.fossils", @"Gift interaction recorded", stowFossilGift},
        {@"circhester.morimoto", @"First-win reward recorded", morimotoFirstWin},
        {@"spikemuth.marnie", @"First exhibition win recorded", marnieFirstWin},
        {@"galar-mine.rose-card", @"Card conversation recorded", 0x78F966F2},
        {@"wild-area.lets-go-pikachu", @"Gift claim recorded", letsGoPikachuClaim},
        {@"wild-area.lets-go-eevee", @"Gift claim recorded", letsGoEeveeClaim},
        {@"wild-area.poke-dolls", @"Gift interaction recorded", pokeDollGift},
        {@"postwick.master-ball", @"Magnolia’s gift scene recorded", masterBallGift},
        {@"stow.beast-ball", @"Champion gift interaction recorded", beastBallGift},
        {@"motostoke.battle-cafe", @"Challenge used when last saved", cafeMotostokeUsed},
        {@"hammerlocke.cafe", @"Challenge used when last saved", cafeHammerlockeUsed},
        {@"wyndon.cafe", @"Challenge used when last saved", cafeWyndonUsed},
        {@"spikemuth.marnie-daily", @"Rematch used when last saved", 0x51FA4131},
        {@"circhester.morimoto-rematch", @"Rematch used when last saved", 0x4CBC0D12},
        {@"turffield.loto-id", @"Entry used when last saved", 0x87C05A15},
        {@"wyndon.tournament-reward", @"Daily reward branch recorded in last save", 0xC5244701},
        {@"stow.bargain", @"Purchase recorded in the last save", marketBoughtToday},
    };
    for (size_t i = 0; i < sizeof(bindings) / sizeof(bindings[0]); i++)
        if ([key isEqualToString:bindings[i].key] && [self.savedFlags containsIndex:bindings[i].flag]) return bindings[i].label;
    return DMGuideMotostokeEvidence(key, self.minccinoStage, self.motostokeTrade, self.motostokeFountain);
}

- (NSUInteger)weatherRewardCount {
    NSUInteger count = 0;
    for (size_t i = 0; i < weatherRewardCount; i++) {
        unsigned item = weatherRewards[i];
        if ([self.recordedBagItems containsIndex:item] || self.heldItemQuantities[@(item)].unsignedIntegerValue) count++;
    }
    return count;
}

- (NSUInteger)ownedSilvallyMemoryCount {
    NSUInteger count = 0;
    for (NSUInteger index = 0; index < silvallyMemoryCount; index++) {
        NSUInteger item = firstSilvallyMemory + index;
        if ([self.giftItems containsIndex:item] || self.heldItemQuantities[@(item)].unsignedIntegerValue) count++;
    }
    return count;
}

- (BOOL)memoryInventoryKnown {
    return self.bagQuantities && self.pokemonCollectionKnown;
}

- (NSUInteger)quantityInCollection:(unsigned)item {
    return self.bagQuantities[@(item)].unsignedIntegerValue + self.heldItemQuantities[@(item)].unsignedIntegerValue;
}

- (NSUInteger)unlockedCampToyCount {
    NSUInteger count = 0;
    for (size_t i = 0; i < sizeof(campingRewards) / sizeof(campingRewards[0]); i++)
        if (campingRewards[i].kind == CampingToy && [self.savedFlags containsIndex:campingRewards[i].flag]) count++;
    return count;
}

- (NSInteger)bikeTurboLevel {
    switch (self.activityWork[@(bikeChargeLimit)].intValue) {
        case 128: return 0;
        case 104: return 1;
        case 84: return 2;
        case 64: return bikeUpgradeCount;
        default: return -1;
    }
}

- (NSNumber *)cookedCurryCount {
    return self.cookedCurryRecipes ? @(self.cookedCurryRecipes.count) : nil;
}

- (NSNumber *)galarDexCaughtCount {
    return self.galarDexCaught ? @(self.galarDexCaught.count) : nil;
}

- (NSSet<NSString *> *)missingGalarSpecies {
    if (!self.galarDexCaught) return nil;
    NSMutableSet<NSString *> *missing = [NSMutableSet setWithCapacity:galarDexCount - self.galarDexCaught.count];
    for (NSUInteger index = 0; index < galarDexCount; index++) {
        if (![self.galarDexCaught containsIndex:index]) [missing addObject:@(galarDexSpecies[index])];
    }
    return missing;
}

+ (NSArray<NSString *> *)galarDexRangesWithSavedContext:(DMGuideSavedContext *)saved {
    NSMutableArray<NSString *> *ranges = [NSMutableArray array];
    for (NSUInteger start = 0; start < galarDexCount; start += galarDexRangeSize) {
        NSRange range = NSMakeRange(start, MIN(galarDexRangeSize, galarDexCount - start));
        NSString *label = [NSString stringWithFormat:@"%03lu–%03lu", start + 1, NSMaxRange(range)];
        if (saved.galarDexCaught) {
            NSUInteger missing = range.length - [saved.galarDexCaught countOfIndexesInRange:range];
            label = [label stringByAppendingFormat:@" · %lu missing", missing];
        }
        [ranges addObject:label];
    }
    return ranges;
}

+ (NSArray<NSString *> *)galarDexEntriesInRange:(NSInteger)range missingOnly:(BOOL)missingOnly
    savedContext:(DMGuideSavedContext *)saved {
    return [[self galarDexRowsInRange:range missingOnly:missingOnly savedContext:saved] valueForKey:@"label"];
}

+ (NSArray<DMGuideGalarDexEntry *> *)galarDexRowsInRange:(NSInteger)range missingOnly:(BOOL)missingOnly
    savedContext:(DMGuideSavedContext *)saved {
    if ((NSUInteger)range >= (galarDexCount + galarDexRangeSize - 1) / galarDexRangeSize) return @[];
    NSUInteger start = (NSUInteger)range * galarDexRangeSize;
    NSMutableArray<DMGuideGalarDexEntry *> *entries = [NSMutableArray array];
    for (NSUInteger index = start; index < MIN(start + galarDexRangeSize, galarDexCount); index++) {
        bool caught = [saved.galarDexCaught containsIndex:index];
        if (missingOnly && caught) continue;
        DMGuideGalarDexEntry *entry = [DMGuideGalarDexEntry new];
        entry.number = (NSInteger)index + 1;
        entry.species = @(galarDexSpecies[index]);
        NSString *name = [NSString stringWithFormat:@"%03lu %@", index + 1, entry.species];
        NSString *status = caught ? @"Caught" : [saved.galarDexSeen containsIndex:index] ? @"Seen" : @"Unseen";
        entry.label = saved.galarDexCaught ? [name stringByAppendingFormat:@" · %@", status] : name;
        [entries addObject:entry];
    }
    return entries;
}

static const struct { __unsafe_unretained NSString *name, *ingredient; } curryGroups[] = {
    {@"Curry", @"Cook with Berries only."},
    {@"Sausage Curry", @"Use Sausages."},
    {@"Juicy Curry", @"Use Bob’s Food Tin. It comes from Pokémon Sword."},
    {@"Rich Curry", @"Use Bach’s Food Tin."},
    {@"Bean Medley Curry", @"Use a Tin of Beans."},
    {@"Toast Curry", @"Use Bread."},
    {@"Pasta Curry", @"Use Pasta."},
    {@"Mushroom Medley Curry", @"Use Mixed Mushrooms."},
    {@"Smoked-Tail Curry", @"Use Smoke-Poke Tail."},
    {@"Leek Curry", @"Use a Large Leek."},
    {@"Apple Curry", @"Use a Fancy Apple."},
    {@"Bone Curry", @"Use Brittle Bones."},
    {@"Plenty-of-Potato Curry", @"Use a Pack of Potatoes."},
    {@"Herb Medley Curry", @"Use a Pungent Root."},
    {@"Salad Curry", @"Use Salad Mix."},
    {@"Fried-Food Curry", @"Use Fried Food."},
    {@"Boiled-Egg Curry", @"Use a Boiled Egg."},
    {@"Tropical Curry", @"Use a Fruit Bunch."},
    {@"Cheese-Covered Curry", @"Use Moomoo Cheese."},
    {@"Seasoned Curry", @"Use Spice Mix."},
    {@"Whipped-Cream Curry", @"Use Fresh Cream."},
    {@"Decorative Curry", @"Use Packaged Curry."},
    {@"Coconut Curry", @"Use Coconut Milk."},
    {@"Instant-Noodle Curry", @"Use Instant Noodles."},
    {@"Burger-Steak Curry", @"Use a Precooked Burger."},
    {@"Gigantamax Curry", @"Use Gigantamix with any Berry flavor."},
};
enum { curryGroupCount = sizeof(curryGroups) / sizeof(curryGroups[0]) };

+ (NSArray<NSString *> *)curryRecipeGroups {
    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:curryGroupCount];
    for (NSUInteger i = 0; i < curryGroupCount; i++) [names addObject:curryGroups[i].name];
    return names;
}

+ (NSString *)curryIngredientInGroup:(NSInteger)group {
    return (NSUInteger)group < curryGroupCount ? curryGroups[group].ingredient : nil;
}

+ (NSArray<NSString *> *)curryRecipesInGroup:(NSInteger)group savedContext:(DMGuideSavedContext *)saved {
    if ((NSUInteger)group >= curryGroupCount) return @[];
    NSArray<NSString *> *flavors = @[@"", @"Spicy ", @"Dry ", @"Sweet ", @"Bitter ", @"Sour "];
    NSUInteger start = (NSUInteger)group * curryFlavorCount;
    NSUInteger count = MIN(curryFlavorCount, curryRecipeCount - start);
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        NSString *name = [flavors[i] stringByAppendingString:curryGroups[group].name];
        NSString *status = [saved.cookedCurryRecipes containsIndex:start + i] ? @"Cooked" : @"Missing";
        [rows addObject:saved.cookedCurryRecipes ? [NSString stringWithFormat:@"%@ · %@", name, status] : name];
    }
    return rows;
}

+ (NSArray<NSString *> *)campingRewardsWithSavedContext:(DMGuideSavedContext *)saved {
    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    NSNumber *cooked = saved.cookedCurryCount;
    for (size_t i = 0; i < sizeof(campingRewards) / sizeof(campingRewards[0]); i++) {
        NSUInteger threshold = campingRewards[i].threshold;
        NSString *status = nil;
        if ([saved.savedFlags containsIndex:campingRewards[i].flag])
            status = campingRewards[i].kind == CampingIngredient ? @"Reward visit recorded" : @"Unlocked";
        else if (cooked && cooked.unsignedIntegerValue >= threshold)
            status = @"Ready for assessment";
        NSString *requirement = threshold == 1 ? @"1 recipe" : [NSString stringWithFormat:@"%lu recipes", threshold];
        NSString *title = [NSString stringWithFormat:@"%@ · %@", campingRewards[i].name, requirement];
        [rows addObject:status ? [NSString stringWithFormat:@"%@ · %@", title, status] : title];
    }
    return rows;
}

- (NSUInteger)collectedCountForHiddenPickup:(const HiddenPickup *)pickup total:(NSUInteger *)total {
    NSIndexSet *collected = pickup->recurring ? self.hiddenPickupsAwaitingRespawn : self.permanentHiddenPickups;
    NSUInteger count = 0;
    *total = 0;
    for (size_t i = 0; i < sizeof(pickup->indices) / sizeof(pickup->indices[0]) && pickup->indices[i]; i++) {
        if ([collected containsIndex:pickup->indices[i]]) count++;
        (*total)++;
    }
    return count;
}

+ (NSArray<NSString *> *)wildSparklesInArea:(DMGuideArea)area subarea:(NSInteger)subarea
    savedContext:(DMGuideSavedContext *)saved {
    subarea = sparkleSubareaIndex(area, subarea);
    if (subarea < 0) return @[];

    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    NSUInteger allSpots = 0, allKnown = 0, allCollected = 0;
    for (size_t i = 0; i < sizeof(wildSparkles) / sizeof(wildSparkles[0]); i++) {
        if (wildSparkles[i].subarea != subarea) continue;
        const uint16_t *indices = wildSparkles[i].indices;
        NSUInteger spots = 0, known = 0, collected = 0;
        for (size_t j = 0; j < sizeof(wildSparkles[i].indices) / sizeof(indices[0]) && indices[j]; j++) {
            spots++;
            if ([saved.knownBaseRecurringPickups containsIndex:indices[j]]) known++;
            if ([saved.hiddenPickupsAwaitingRespawn containsIndex:indices[j]]) collected++;
        }
        allSpots += spots;
        allKnown += known;
        allCollected += collected;
        NSString *status = known == spots ? [NSString stringWithFormat:@"%lu of %lu awaiting respawn", collected, spots] :
            [NSString stringWithFormat:@"%lu %@", spots, spots == 1 ? @"spot" : @"spots"];
        [rows addObject:[NSString stringWithFormat:@"%@ · %@", wildSparkles[i].rewards, status]];
    }
    if (allSpots == 0) return @[];
    NSString *summary = allKnown == allSpots ?
        [NSString stringWithFormat:@"%lu of %lu spots awaiting respawn in the last save", allCollected, allSpots] :
        [NSString stringWithFormat:@"%lu spots · Full save status unavailable", allSpots];
    [rows insertObject:summary atIndex:0];
    return rows;
}

+ (DMGuideSparkleMap *)wildSparkleMapInArea:(DMGuideArea)area subarea:(NSInteger)subarea
    savedContext:(DMGuideSavedContext *)saved {
    subarea = sparkleSubareaIndex(area, subarea);
    if (subarea < 0) return nil;
    NSMutableDictionary<NSNumber *, NSString *> *rewardsByActor = [NSMutableDictionary dictionary];
    for (size_t i = 0; i < sizeof(wildSparkles) / sizeof(wildSparkles[0]); i++) {
        if (wildSparkles[i].subarea != subarea) continue;
        const uint16_t *indices = wildSparkles[i].indices;
        for (size_t j = 0; j < sizeof(wildSparkles[i].indices) / sizeof(indices[0]) && indices[j]; j++)
            rewardsByActor[@(indices[j])] = wildSparkles[i].rewards;
    }
    NSMutableArray<DMGuideSparkleSpot *> *spots = [NSMutableArray arrayWithCapacity:rewardsByActor.count];
    for (size_t i = 0; i < sizeof(sparklePositions) / sizeof(sparklePositions[0]); i++) {
        const SparklePosition *actor = &sparklePositions[i];
        NSString *rewards = rewardsByActor[@(actor->index)];
        if (!rewards) continue;
        DMGuideSparkleSpot *spot = [DMGuideSparkleSpot new];
        spot.title = [NSString stringWithFormat:@"Spot %lu · %@", spots.count + 1, rewards];
        spot.point = sparklePoint(actor->point);
        if ([saved.hiddenPickupsAwaitingRespawn containsIndex:actor->index]) {
            spot.state = SparkleAwaitingRespawn;
            spot.saveStatus = @"Awaiting respawn in the last save";
        } else if ([saved.knownBaseRecurringPickups containsIndex:actor->index]) {
            spot.state = SparkleNotCollected;
            spot.saveStatus = @"Not awaiting respawn in the last save";
        } else {
            spot.saveStatus = @"Save status unavailable";
        }
        CGFloat nearestDistance = CGFLOAT_MAX;
        for (size_t j = 0; j < sizeof(sparkleDenPositions) / sizeof(sparkleDenPositions[0]); j++) {
            const SparkleDenPosition *den = &sparkleDenPositions[j];
            if (den->subarea != subarea) continue;
            CGPoint point = sparklePoint(den->point);
            CGFloat dx = point.x - spot.point.x, dy = point.y - spot.point.y;
            CGFloat distance = dx * dx + dy * dy;
            if (distance < nearestDistance) {
                nearestDistance = distance;
                spot.nearestDen = den->number;
                spot.denReference = sparkleDenReference(den->number, -dx, -dy);
            }
        }
        [spots addObject:spot];
    }
    if (!spots.count) return nil;
    DMGuideSparkleMap *map = [DMGuideSparkleMap new];
    map.spots = spots;
    map.subarea = subarea;
    return map;
}

- (NSString *)activityCompletionForKey:(NSString *)key {
    if ([key isEqualToString:@"fashion.hairstyle"] && self.cardBackgroundRecords[@(cardHairServiceRecord)].intValue > 0)
        return @"Hair service recorded";
    if ([key hasPrefix:@"uniform."]) {
        for (NSUInteger index = 0; index < shieldUniformCount; index++) {
            if ([key isEqualToString:shieldUniforms[index].key] && [self.uniformsInWardrobe containsIndex:index])
                return @"Full uniform in your wardrobe";
        }
    }
    for (NSUInteger index = 0; index < sizeof(shieldCardBackgrounds) / sizeof(shieldCardBackgrounds[0]); index++) {
        const ShieldCardBackground *background = &shieldCardBackgrounds[index];
        if ([key isEqualToString:background->key] && [self.savedFlags containsIndex:background->flag])
            return cardBackgroundUnlockLabel(background);
    }
    const ShieldCardBackgroundTarget *target = cardBackgroundTargetForKey(key);
    if (target && self.cardBackgroundRecords[@(target->record)].unsignedIntValue >= target->target)
        return @"1 Card Maker background unlocked";
    if ([key hasSuffix:@".gym-mission"] || [key hasSuffix:@".gym-badge"]) {
        for (NSUInteger index = 0; index < shieldGymCount; index++) {
            const ShieldGym *gym = &shieldGyms[index];
            if ([key isEqualToString:gym->missionKey] && [self.savedFlags containsIndex:gym->missionFlag])
                return @"Gym mission clear recorded";
            if ([key isEqualToString:gym->badgeKey] && [self.savedFlags containsIndex:gym->badgeFlag])
                return @"Badge earned";
        }
    }
    if ([key isEqualToString:@"wyndon.champion-cup"] && [self.savedFlags containsIndex:gameClear])
        return @"Champion Cup clear recorded";
    if ([key isEqualToString:@"postwick.hop-first-win"] && [self.savedFlags containsIndex:0x598B8A31])
        return @"First Hop battle win recorded";
    if ([key isEqualToString:@"route2.hop-win"] && [self.savedFlags containsIndex:0x12277F11])
        return @"Route 2 Hop battle win recorded";

    // Shield 1.3.2 field Trainer flags. Doubles require both opponents.
    // Result-path limits and the stable-key crosswalk are in batch-3-tracking-audit.md.
    static const struct {
        __unsafe_unretained NSString *key;
        uint32_t primaryFlag;
        uint32_t partnerFlag;
    } trainers[] = {
        {@"galar-mine.trainer-georgia", 0x45EF41B0, 0x00000000}, // TRID_WORKERF_02
        {@"galar-mine.trainer-keith", 0xAC6F1AFE, 0x00000000}, // TRID_WORKERM_01
        {@"galar-mine.trainer-russel", 0xAC6F194B, 0x00000000}, // TRID_WORKERM_02
        {@"galar-mine.trainer-sandra", 0x45EF46C9, 0x00000000}, // TRID_WORKERF_01
        {@"glimwood.trainer-derek", 0xD2A4D98A, 0x00000000}, // TRID_CHEF_02
        {@"glimwood.trainer-judy", 0x2DCF8518, 0x00000000}, // TRID_MADAM_02
        {@"glimwood.trainer-robert", 0xDE01DBF1, 0xDE01D6D8}, // TRID_WKIMODAMESHI_01 / TRID_WKIMODAMESHI_02
        {@"mine2.trainer-francis", 0xAC6F1798, 0x00000000}, // TRID_WORKERM_03
        {@"mine2.trainer-vincent", 0xBE91A407, 0x00000000}, // TRID_RAILROADMAN_01
        {@"mine2.trainer-yvonne", 0x45EF4363, 0x00000000}, // TRID_WORKERF_03
        {@"outskirts.trainer-caroline", 0x2DCF8A31, 0x00000000}, // TRID_MADAM_01
        {@"outskirts.trainer-raymond", 0x47E7245D, 0x00000000}, // TRID_POLICE_01
        {@"route10.trainer-donald", 0x591DDB8E, 0x00000000}, // TRID_YAMAOTOKO_02
        {@"route10.trainer-douglas", 0x591DD9DB, 0x00000000}, // TRID_YAMAOTOKO_01
        {@"route10.trainer-geoffrey", 0x8D9E64A8, 0x00000000}, // TRID_DRIBER_02
        {@"route10.trainer-gillian", 0xBE5F7997, 0xBE5F747E}, // TRID_WREPORTERS01_03 / TRID_WREPORTERS01_04
        {@"route10.trainer-glenn", 0xA8642C04, 0x00000000}, // TRID_GENTLEMAN_01
        {@"route10.trainer-graham", 0xE17D9D05, 0x00000000}, // TRID_DOCTER_02
        {@"route10.trainer-harper", 0xB3A3D176, 0x00000000}, // TRID_POSTMAN_02
        {@"route10.trainer-ronald", 0x88674E61, 0x00000000}, // TRID_BUSINESS_01
        {@"route2.benjamin", 0x9F8D8FD8, 0x00000000}, // TRID_TANPAN_02
        {@"route2.jake", 0x9F8D94F1, 0x00000000}, // TRID_TANPAN_01
        {@"route2.lauren", 0x30939AC6, 0x00000000}, // TRID_MINI_01
        {@"route3.trainer-hannah", 0x9E58D0A7, 0x00000000}, // TRID_SCHOOLF_01
        {@"route3.trainer-kayleigh", 0x9E58D25A, 0x00000000}, // TRID_SCHOOLF_02
        {@"route3.trainer-marvin", 0xAF60A3C8, 0x00000000}, // TRID_SCHOOLM_01
        {@"route3.trainer-peter", 0xAF60A8E1, 0x00000000}, // TRID_SCHOOLM_02
        {@"route3.trainer-rei", 0x30939913, 0x00000000}, // TRID_MINI_02
        {@"route3.trainer-tad", 0xB3A3CFC3, 0x00000000}, // TRID_POSTMAN_01
        {@"route4.trainer-bradley", 0x573947AE, 0x00000000}, // TRID_BREEDERM_02
        {@"route4.trainer-jaime", 0x573945FB, 0x00000000}, // TRID_BREEDERM_01
        {@"route4.trainer-mia", 0xA7581C24, 0x00000000}, // TRID_GOKKOF_01
        {@"route4.trainer-rhys", 0x9765B076, 0x00000000}, // TRID_GOKKOM_02
        {@"route4.trainer-shane", 0x9765AEC3, 0x00000000}, // TRID_GOKKOM_01
        {@"route4.trainer-sunny", 0xA758213D, 0x00000000}, // TRID_GOKKOF_02
        {@"route5.trainer-adrian", 0x57394961, 0x00000000}, // TRID_BREEDERM_03
        {@"route5.trainer-debra", 0x2C18796C, 0x00000000}, // TRID_BREEDERF_01
        {@"route5.trainer-denise", 0x2C187E85, 0x00000000}, // TRID_BREEDERF_02
        {@"route5.trainer-gabrielle", 0xF7E7F3BA, 0x00000000}, // TRID_OL_01
        {@"route5.trainer-gillian", 0xBE5F7CFD, 0xBE5F77E4}, // TRID_WREPORTERS01_01 / TRID_WREPORTERS01_02
        {@"route5.trainer-stuart", 0xD2A4D7D7, 0x00000000}, // TRID_CHEF_01
        {@"route6.trainer-anita", 0x9192D303, 0x00000000}, // TRID_ADULTGIRL_01
        {@"route6.trainer-diane", 0x2BC5BF48, 0x00000000}, // TRID_BACKPACKER_01
        {@"route6.trainer-duncan", 0xE7E898FE, 0x00000000}, // TRID_ARTIST_01
        {@"route6.trainer-iwan", 0xFE18B16C, 0xFE18B685}, // TRID_WDOCTERS_01 / TRID_WDOCTERS_02
        {@"route6.trainer-nicola", 0xF98A4322, 0x00000000}, // TRID_MODEL_01
        {@"route6.trainer-ruth", 0x2BC5C461, 0x00000000}, // TRID_BACKPACKER_02
        {@"route7.trainer-bruce", 0x8D9E69C1, 0x00000000}, // TRID_DRIBER_01
        {@"route7.trainer-caden", 0xA864311D, 0x00000000}, // TRID_GENTLEMAN_02
        {@"route7.trainer-mila", 0xF98A416F, 0x00000000}, // TRID_MODEL_02
        {@"route8.trainer-barbara", 0x2BC5C2AE, 0x00000000}, // TRID_BACKPACKER_03
        {@"route8.trainer-bobby", 0x47E71F44, 0x00000000}, // TRID_POLICE_02
        {@"route8.trainer-charles", 0x05EF26B0, 0x00000000}, // TRID_MUSICIAN_01
        {@"route8.trainer-joanna", 0x4E84DF2A, 0x00000000}, // TRID_NURSE_01
        {@"route8.trainer-jordan", 0x33562A4B, 0x33562BFE}, // TRID_WCOLLEAGUE_01 / TRID_WCOLLEAGUE_02
        {@"route9.trainer-carter", 0x7487CA84, 0x00000000}, // TRID_KARATE_02
        {@"route9.trainer-harriet", 0x836FEF92, 0x00000000}, // TRID_ANGLER_01
        {@"route9.trainer-jacob", 0x522B8BD8, 0x00000000}, // TRID_KAIPAN_02
        {@"route9.trainer-layla", 0x0D19C1BE, 0x00000000}, // TRID_BIKINI_02
        {@"route9.trainer-logan", 0x522B90F1, 0x00000000}, // TRID_KAIPAN_01
        {@"route9.trainer-marina", 0x836FEDDF, 0x00000000}, // TRID_ANGLER_02
        {@"route9.trainer-owen", 0x5C71FC31, 0x5C71F718}, // TRID_WMUSICUNIT_01 / TRID_WMUSICUNIT_02
        {@"route9.trainer-reece", 0x7487CF9D, 0x00000000}, // TRID_KARATE_01
        {@"route9.trainer-scarlett", 0x0D19C00B, 0x00000000}, // TRID_BIKINI_01
        {@"route9.trainer-zoe", 0x20982EC6, 0x00000000}, // TRID_DANCER_01
    };
    for (size_t index = 0; index < sizeof(trainers) / sizeof(trainers[0]); index++) {
        if ([key isEqualToString:trainers[index].key] &&
            [self.savedFlags containsIndex:trainers[index].primaryFlag] &&
            (!trainers[index].partnerFlag || [self.savedFlags containsIndex:trainers[index].partnerFlag]))
            return @"Trainer defeat · estimated from save";
    }

    const ShieldPostgameStadium *stadium = postgameStadiumForKey(key);
    if (stadium && [self resolutionForStadium:stadium] == StadiumResolved)
        return @"Stadium resolution recorded";

    const HiddenPickup *hidden = hiddenPickupForKey(key);
    if (hidden) {
        NSUInteger total;
        NSUInteger collected = [self collectedCountForHiddenPickup:hidden total:&total];
        if (hidden->recurring)
            return collected ? @"Collected before respawn · estimated from save" : nil;
        return collected == total ? @"Collected · estimated from save" : nil;
    }

    static const struct { __unsafe_unretained NSString *key; uint32_t flag; } pickups[] = {
#include "shield_guide_pickup_flags.inc"
    };
    for (size_t i = 0; i < sizeof(pickups) / sizeof(pickups[0]); i++) {
        if ([key isEqualToString:pickups[i].key] && [self.savedFlags containsIndex:pickups[i].flag])
            return [key hasPrefix:@"route1."] ? @"Collected · recorded in save" : @"Collected · estimated from save";
    }

    // Use the record for the action described in the checklist.
    NSInteger nursery = nurseryIndexForKey(key);
    if (nursery != NSNotFound && _nurseries[nursery].deposits == 2)
        return _nurseries[nursery].eggReady ? @"2 Pokémon at the Nursery · Egg ready to collect" : @"2 Pokémon at the Nursery";
    if ([key isEqualToString:@"nursery.hatch-egg"] && self.eggsHatched.intValue > 0) {
        int count = self.eggsHatched.intValue;
        return count == 1 ? @"1 Egg hatched" : [NSString stringWithFormat:@"%d Eggs hatched", count];
    }
    if ([key isEqualToString:@"route5.rotom-bike"] &&
        ([self.giftItems containsIndex:landBike] || [self.giftItems containsIndex:waterBike]))
        return @"Rotom Bike in your Key Items";
    if ([key isEqualToString:@"route9.bike-water-mode"] && [self hasWaterMode])
        return @"Water Mode unlocked";
    if ([key isEqualToString:@"wild-area.bike-outfit"] && self.cyclingOutfitType)
        return [NSString stringWithFormat:@"%@-type cycling outfit equipped", self.cyclingOutfitType];
    if ([key isEqualToString:@"weald.sonia-book"] && [self.giftItems containsIndex:soniasBook])
        return @"Sonia’s Book in your Key Items";
    if ([key isEqualToString:@"wedgehurst.lab-potion"] && self.pokedexUnlocked.boolValue) {
        // These opening saves were verified across the Potion event and the next two stops.
        // The main phase is reused elsewhere and is not a lifetime progress counter.
        switch (self.mainPhase.intValue) {
            case 220: case 240: case 250: case 270:
                return @"Post-lab Potion event recorded · estimated from save";
        }
    }
    if ([key isEqualToString:@"motostoke.minccino-return"]) {
        NSInteger stage = self.minccinoStage.integerValue;
        if (stage == 2 || stage == 3) return @"Minccino returned · estimated from save";
    }
    if ([key isEqualToString:@"motostoke.minccino-reward"] && self.minccinoStage.integerValue == 3)
        return @"Owner follow-up · estimated from save";
    if ([key isEqualToString:@"motostoke.fountain"] && self.motostokeFountain.boolValue)
        return @"Fountain encounter · estimated from save";
    if ([key hasSuffix:@".trade"] || [key isEqualToString:@"hammerlocke.letter"]) {
        if ([self activityEvidenceForKey:key]) return @"Completed · estimated from save";
    }
    if ([key hasSuffix:@".ball-guy"] && [self activityEvidenceForKey:key])
        return @"Met Ball Guy · estimated from save";
    if (DMGuideHulburyDeliveryComplete(key, self.hulburyDelivery))
        return @"Delivery and chef follow-up · estimated from save";

    NSInteger letter = self.activityWork[@(letterProgress)].integerValue;
    if ([key isEqualToString:@"ballonlea.letter"] && (letter == 3 || letter == 4))
        return @"Letter delivered · estimated from save";
    if ([key isEqualToString:@"hammerlocke.letter-return"] && letter == 4)
        return @"Return visit completed · estimated from save";
    if ([key isEqualToString:@"circhester.detective"] && self.activityWork[@(detectiveProgress)].integerValue == 5)
        return @"Case solved · estimated from save";
    if ([key isEqualToString:@"turffield.riddle"] && self.activityWork[@(riddleProgress)].integerValue == 4)
        return @"Riddle solved · estimated from save";
    if ([key isEqualToString:@"ballonlea.fire-outfit"] && self.activityWork[@(outfitProgress)].integerValue == 2)
        return @"Outfit shown · estimated from save";
    if ([key isEqualToString:@"hammerlocke.weather-gifts"] && [self.savedFlags containsIndex:weatherBonus] &&
        [self weatherRewardCount] == weatherRewardCount)
        return @"All five weather rewards recorded · Bonus visit recorded";
    if ([key isEqualToString:@"motostoke.marnie-smile"] && self.activityWork[@(marnieSmileProgress)].integerValue == 20)
        return @"Scene viewed · estimated from save";
    if ([key isEqualToString:@"wedgehurst.birthday"]) {
        static const uint8_t daysInMonth[] = {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
        NSUInteger month = self.activityWork[@(birthdayMonth)].unsignedIntegerValue;
        NSUInteger day = self.activityWork[@(birthdayDay)].unsignedIntegerValue;
        if (month >= 1 && month <= sizeof(daysInMonth) && day >= 1 && day <= daysInMonth[month - 1])
            return @"Birthday registered · estimated from save";
    }
    if ([key isEqualToString:@"north-wild.rally"]) {
        int finishes = self.rallyFinishes.intValue;
        int best = self.activityWork[@(rallyHighScore)].intValue;
        if (finishes > 0) {
            NSString *record = finishes == 1 ? @"1 Rally finish recorded" :
                [NSString stringWithFormat:@"%d Rally finishes recorded", finishes];
            return best > 0 ? [record stringByAppendingFormat:@" · Best score %d", best] : record;
        }
        if (best > 0) return [NSString stringWithFormat:@"Rally run recorded · Best score %d", best];
    }
    if ([key isEqualToString:@"north-wild.bike-turbo"] && self.bikeTurboLevel == bikeUpgradeCount)
        return @"All three turbo upgrades installed · estimated from save";
    if ([key isEqualToString:@"north-wild.digging-duo"]) {
        int skill = self.activityWork[@(diggingBestSkill)].intValue;
        int stamina = self.activityWork[@(diggingBestStamina)].intValue;
        NSMutableArray<NSString *> *records = [NSMutableArray arrayWithCapacity:2];
        if (skill > 0) [records addObject:[NSString stringWithFormat:@"Skill best %d", skill]];
        if (stamina > 0) [records addObject:[NSString stringWithFormat:@"Stamina best %d", stamina]];
        if (records.count) return [@"Best treasures in one run · " stringByAppendingString:[records componentsJoinedByString:@" · "]];
    }
    if ([key isEqualToString:@"wild-area.raid-battle"] && self.raidBattles.intValue > 0) {
        int count = self.raidBattles.intValue;
        return count == 1 ? @"1 Max Raid battle recorded" : [NSString stringWithFormat:@"%d Max Raid battles recorded", count];
    }
    if ([key isEqualToString:@"wild-area.first-raid"] && self.raidCaptures.intValue > 0) {
        int count = self.raidCaptures.intValue;
        return count == 1 ? @"1 Max Raid catch recorded" : [NSString stringWithFormat:@"%d Max Raid catches recorded", count];
    }
    if ([key isEqualToString:@"route1.first-catch"] && (self.pokemonActivities & route1Capture))
        return @"Route 1 catch in your collection";
    if ([key isEqualToString:@"route2.first-catch"] && (self.pokemonActivities & route2Capture))
        return @"Route 2 catch in your collection";
    if ([key isEqualToString:@"route5.toxel"] && self.toxelGiftConversation && (self.pokemonActivities & nurseryToxel))
        return @"Nursery gift Pokémon in your collection";
    if ([key isEqualToString:@"battle-tower.type-null"] && self.activityWork[@(typeNullGiftProgress)].integerValue == 1 &&
        (self.pokemonActivities & towerTypeNull))
        return @"Battle Tower gift Pokémon in your collection";
    if ([key isEqualToString:@"battle-tower.memories"] && self.activityWork[@(typeNullGiftProgress)].integerValue == 1 &&
        self.ownedSilvallyMemoryCount == silvallyMemoryCount)
        return @"All 17 Memories in your collection · Gift sequence recorded";
    if ([key isEqualToString:@"hammerlocke.friendship-ribbon"] && (self.pokemonActivities & bestFriendsRibbon))
        return @"Best Friends Ribbon in your collection";
    if ([key isEqualToString:@"hammerlocke.effort-ribbon"] && (self.pokemonActivities & effortRibbon))
        return @"Effort Ribbon in your collection";
    if ([key isEqualToString:@"battle-tower.master-ribbon"] && (self.pokemonActivities & towerMasterRibbon))
        return @"Tower Master Ribbon in your collection";
    if ([key isEqualToString:@"battle-tower.hyper-training"] && (self.pokemonActivities & hyperTrained))
        return @"Hyper-Trained Pokémon in your collection";
    NSString *tutorCompletion = tutorMoveCompletion(key, self.pokemonActivities);
    if (tutorCompletion) return tutorCompletion;
    if ([key isEqualToString:@"wild-area.first-berries"] && [self.positiveActivityRecords containsIndex:berryGatherRecord])
        return @"Berries gathered · estimated from save";
    if ([key isEqualToString:@"wild-area.first-curry"] &&
        (self.cookedCurryCount.unsignedIntegerValue > 0 || [self.positiveActivityRecords containsIndex:curryCookedRecord]))
        return @"Curry cooked · estimated from save";
    if ([key isEqualToString:@"wild-area.camp-toys"] && self.unlockedCampToyCount == campToyCount)
        return @"All six bonus toys unlocked · estimated from save";
    if ([key isEqualToString:@"wild-area.golden-cookware"] && [self.savedFlags containsIndex:goldenCookwareUnlocked])
        return @"Golden cookware unlocked · estimated from save";
    if ([key isEqualToString:@"wyndon.champion-tournament"] && self.activityWork[@(championTournamentWins)].intValue > 0)
        return @"Tournament win · estimated from save";
    // The new-game setup also hides this object. Champion setup resets its flag.
    if ([key isEqualToString:@"postwick.charmander"] &&
        [self.savedFlags containsIndex:gameClear] && [self.savedFlags containsIndex:charmanderGiftBall])
        return @"Gift ball collected · estimated from save";
    if ([key isEqualToString:@"route6.fossil-revival"] && [self.positiveActivityRecords containsIndex:fossilRevivalRecord])
        return @"Fossil revival recorded · estimated from save";
    if ([key hasPrefix:@"route6.fossil."]) {
        for (NSUInteger index = 0; index < fossilRecipeCount; index++) {
            const ShieldFossilRecipe *recipe = &fossilRecipes[index];
            if (![key isEqualToString:recipe->key]) continue;
            if ((self.pokemonActivities & (1u << (firstFossilBit + index))) &&
                [self.positiveActivityRecords containsIndex:fossilRevivalRecord])
                return @"Route 6 revival in your collection";
            if ([self.galarDexCaught containsIndex:recipe->galarNumber - 1])
                return @"Registered in your Galar Pokédex";
            break;
        }
    }
    if ([key isEqualToString:@"stow.fossils"] && [self.savedFlags containsIndex:stowFossilGift] &&
        [self quantityInCollection:fossilizedDrake] >= 2)
        return @"Fossilized Drakes in your collection · Gift visit recorded";
    NSUInteger teaForm = teaFormForActivity(key);
    if (teaForm != NSNotFound) {
        NSString *position = self.polteageistPositions[@(teaForm)];
        if (position) return [NSString stringWithFormat:@"%@ Polteageist · %@", teaEvolutions[teaForm].form, position];
    }
    if ([key isEqualToString:@"power-plant.eternatus"]) {
        if (self.pokemonActivities & eternatusCatch) return @"Your Energy Plant Eternatus is in your collection";
        if ([self.galarDexCaught containsIndex:eternatusDexNumber - 1]) return @"Registered in your Galar Pokédex";
    }
    if ([key isEqualToString:@"power-plant.zamazenta"]) {
        if (self.pokemonActivities & zamazentaCatch) return @"Your Energy Plant Zamazenta is in your collection";
        if ([self.galarDexCaught containsIndex:zamazentaDexNumber - 1]) return @"Registered in your Galar Pokédex";
    }
    if ([key isEqualToString:@"weald.postgame-epilogue"] && [self.savedFlags containsIndex:wealdEpilogue])
        return @"Weald epilogue recorded";
    if ([key isEqualToString:@"wild-area.poke-dolls"] && [self.savedFlags containsIndex:pokeDollGift] &&
        [self quantityInCollection:pokeDollItem] >= 5)
        return @"Five Poké Dolls in your collection · Gift visit recorded";
    if ([key isEqualToString:@"postwick.master-ball"] && [self.savedFlags containsIndex:masterBallGift] &&
        self.activityWork[@(masterBallGiftStage)].intValue == 20) {
        if ([self quantityInCollection:masterBallItem]) return @"Master Ball in your collection · Gift scene recorded";
        if (self.pokemonActivities & masterBallCatch) return @"Master Ball catch in your collection · Gift scene recorded";
        if ([self.recordedBagItems containsIndex:masterBallItem]) return @"Past Master Ball recorded in Bag · Gift scene recorded";
    }
    if ([key isEqualToString:@"stow.beast-ball"] && [self.savedFlags containsIndex:beastBallGift]) {
        if ([self quantityInCollection:beastBallItem]) return @"Beast Ball in your collection · Gift visit recorded";
        if (self.pokemonActivities & beastBallCatch) return @"Beast Ball catch in your collection · Gift visit recorded";
        if ([self.recordedBagItems containsIndex:beastBallItem]) return @"Past Beast Ball recorded in Bag · Gift visit recorded";
    }
    if ([key isEqualToString:@"motostoke.poke-jobs"] && [self.positiveActivityRecords containsIndex:pokeJobReturnRecord])
        return @"Poké Job return recorded · estimated from save";
    if ([key isEqualToString:@"battle-tower.first-win"] &&
        ([self.positiveActivityRecords containsIndex:towerSinglesWinRecord] ||
         [self.positiveActivityRecords containsIndex:towerDoublesWinRecord]))
        return @"Tower win recorded · estimated from save";
    if ([key isEqualToString:@"battle-tower.singles-master"] &&
        self.activityWork[@(towerSinglesHighest)].intValue == 33)
        return @"Singles Master Ball Tier reached · estimated from save";
    if ([key isEqualToString:@"battle-tower.doubles-master"] &&
        self.activityWork[@(towerDoublesHighest)].intValue == 33)
        return @"Doubles Master Ball Tier reached · estimated from save";

    for (size_t i = 0; i < giftRewardCount; i++) {
        unsigned item = giftRewards[i].item;
        if (![key isEqualToString:giftRewards[i].key] || ![self.savedFlags containsIndex:giftRewards[i].flag]) continue;
        if ([self.giftItems containsIndex:item]) return @"Reward in your Bag · estimated from save";
        if (giftRewards[i].holdable && self.heldItemQuantities[@(item)].unsignedIntegerValue)
            return @"Reward held by a Pokémon · estimated from save";
        if (giftRewards[i].holdable && [self.recordedBagItems containsIndex:item])
            return @"Gift visit and past Bag entry recorded · estimated from save";
    }

    for (NSUInteger index = 0; index < shieldLeagueCardCount; index++)
        if ([key isEqualToString:shieldLeagueCards[index].key] &&
            [self.npcLeagueCards containsIndex:shieldLeagueCards[index].slot])
            return @"Card in your League Card album";

    static const struct { __unsafe_unretained NSString *key, *label; uint32_t flag; } finished[] = {
        {@"spikemuth.marnie", @"First win · estimated from save", marnieFirstWin},
        {@"circhester.morimoto", @"First win · estimated from save", morimotoFirstWin},
        {@"wild-area.lets-go-pikachu", @"Gift claimed · estimated from save", letsGoPikachuClaim},
        {@"wild-area.lets-go-eevee", @"Gift claimed · estimated from save", letsGoEeveeClaim},
        {@"north-wild.rally-fast-ball", @"Fast Ball reward event recorded · estimated from save", rallyFastBall},
        {@"battle-tower.judge", @"Judge function unlocked · estimated from save", towerJudgeUnlocked},
        {@"hammerlocke.sonia-lock", @"Locked-door conversation recorded", 0x5EDFE4F5},
        {@"weald.sonia-shrine", @"Shrine conversation recorded", 0x476DEBD1},
        {@"route3.campsite-taxi", @"Campsite Flying Taxi stop unlocked", 0x0EDEC7B9},
        {@"route4.campsite-taxi", @"Campsite Flying Taxi stop unlocked", 0xEA8770E2},
        {@"route5.campsite-taxi", @"Campsite Flying Taxi stop unlocked", 0x5907C6A7},
        {@"route6.campsite-taxi", @"Campsite Flying Taxi stop unlocked", 0x82A60018},
        {@"route7.campsite-taxi", @"Campsite Flying Taxi stop unlocked", 0x356177FD},
        {@"route8.campsite-taxi", @"Campsite Flying Taxi stop unlocked", 0x761607C6},
        {@"route9.campsite-taxi", @"Campsite Flying Taxi stop unlocked", 0xB598DB42},
        {@"route10.campsite-taxi", @"Campsite Flying Taxi stop unlocked", 0x81615D96},
        {@"route5.nursery-taxi", @"Nursery Flying Taxi stop unlocked", 0x1FC1D317},
        {@"north-wild.nursery-taxi", @"Nursery Flying Taxi stop unlocked", 0x957B3E05},
    };
    for (size_t i = 0; i < sizeof(finished) / sizeof(finished[0]); i++)
        if ([key isEqualToString:finished[i].key] && [self.savedFlags containsIndex:finished[i].flag]) return finished[i].label;
    return nil;
}

+ (NSString *)leagueCardAlbumTitleWithSavedContext:(DMGuideSavedContext *)saved {
    if (!saved.npcLeagueCards) return @"League Card album";
    NSUInteger owned = 0;
    for (NSUInteger index = 0; index < shieldLeagueCardCount; index++)
        if ([saved.npcLeagueCards containsIndex:shieldLeagueCards[index].slot]) owned++;
    return [NSString stringWithFormat:@"League Card album · %lu of %d owned", owned, shieldLeagueCardCount];
}

+ (NSArray<NSString *> *)leagueCardAlbumRowsWithSavedContext:(DMGuideSavedContext *)saved {
    NSArray<NSString *> *areas = DMShieldGuide.areaNames;
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:shieldLeagueCardCount];
    for (NSUInteger index = 0; index < shieldLeagueCardCount; index++) {
        const ShieldLeagueCard *card = &shieldLeagueCards[index];
        NSString *title = card->name;
        if (saved.npcLeagueCards)
            title = [title stringByAppendingString:[saved.npcLeagueCards containsIndex:card->slot] ? @" · Owned" : @" · Missing"];
        [rows addObject:[NSString stringWithFormat:@"%@\n%@ · %@", title, areas[card->area], card->directions]];
    }
    return rows;
}

+ (NSArray<NSString *> *)cardMakerRowsWithSavedContext:(DMGuideSavedContext *)saved {
    NSUInteger backgrounds = [saved.savedFlags containsIndex:cardStarterFlag] ? cardStarterBackgrounds : 0;
    NSUInteger backgroundTotal = cardStarterBackgrounds + 4; // Four Battle Tower thresholds.
    for (NSUInteger index = 0; index < sizeof(shieldCardBackgrounds) / sizeof(shieldCardBackgrounds[0]); index++) {
        const ShieldCardBackground *background = &shieldCardBackgrounds[index];
        backgroundTotal += background->count;
        if ([saved.savedFlags containsIndex:background->flag]) backgrounds += background->count;
    }
    for (NSUInteger index = 0; index < sizeof(shieldCardBackgroundTargets) / sizeof(shieldCardBackgroundTargets[0]); index++) {
        const ShieldCardBackgroundTarget *target = &shieldCardBackgroundTargets[index];
        backgroundTotal++;
        if (saved.cardBackgroundRecords[@(target->record)].unsignedIntValue >= target->target) backgrounds++;
    }
    backgrounds += (saved.towerSinglesWins.intValue >= cardTowerSinglesGoal);
    backgrounds += (saved.towerDoublesWins.intValue >= cardTowerDoublesGoal);
    backgrounds += (saved.towerSinglesWins.intValue >= cardTowerFinalGoal);
    backgrounds += (saved.towerDoublesWins.intValue >= cardTowerFinalGoal);

    NSUInteger available[ShieldCardStyleCategoryCount] = {0}, totals[ShieldCardStyleCategoryCount] = {0};
    for (NSUInteger index = 0; index < sizeof(shieldCardStyleUnlocks) / sizeof(shieldCardStyleUnlocks[0]); index++) {
        const ShieldCardStyleUnlock *styles = &shieldCardStyleUnlocks[index];
        BOOL unlocked = [saved.savedFlags containsIndex:styles->flag];
        for (NSUInteger category = 0; category < ShieldCardStyleCategoryCount; category++) {
            totals[category] += styles->counts[category];
            if (unlocked) available[category] += styles->counts[category];
        }
    }
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithObject:
        @"Use Card Maker at Rotomi in a Pokémon Center. Some coatings have a printing fee."];
    [rows addObject:saved ? [NSString stringWithFormat:@"Backgrounds · %lu of %lu available", backgrounds, backgroundTotal] :
        [NSString stringWithFormat:@"Backgrounds · %lu options", backgroundTotal]];
    for (NSUInteger category = 0; category < ShieldCardStyleCategoryCount; category++) {
        NSString *name = cardStylePlural[category].capitalizedString;
        [rows addObject:saved ? [NSString stringWithFormat:@"%@ · %lu of %lu available", name, available[category], totals[category]] :
            [NSString stringWithFormat:@"%@ · %lu options", name, totals[category]]];
    }
    return rows;
}

+ (NSString *)uniformWardrobeTitleWithSavedContext:(DMGuideSavedContext *)saved {
    if (!saved.uniformsInWardrobe) return @"Uniform wardrobe";
    return [NSString stringWithFormat:@"Uniform wardrobe · %lu of %d owned", saved.uniformsInWardrobe.count, shieldUniformCount];
}

+ (NSArray<NSString *> *)uniformWardrobeRowsWithSavedContext:(DMGuideSavedContext *)saved {
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:shieldUniformCount];
    for (NSUInteger index = 0; index < shieldUniformCount; index++) {
        const ShieldUniform *uniform = &shieldUniforms[index];
        NSString *title = uniform->name;
        if (saved.uniformsInWardrobe) {
            NSString *status = [saved.uniformsInWardrobe containsIndex:index] ? @"Owned" : @"Missing pieces";
            title = [title stringByAppendingFormat:@" · %@", status];
        }
        NSString *source = uniform->source ?: @"Buy at a stadium’s uniform shop for 18,000 Pokédollars.";
        [rows addObject:[NSString stringWithFormat:@"%@\n%@", title, source]];
    }
    return rows;
}
- (StadiumResolution)resolutionForStadium:(const ShieldPostgameStadium *)stadium {
    if (stadium->area == DMGuideAreaTurffield) {
        if ([self.savedFlags containsIndex:turffieldDebrief]) return StadiumResolved;
        switch (self.mainPhase.intValue) {
            case 3050: case 3051: return StadiumReady;
            case 3060: return StadiumDebriefPending;
            default: return StadiumUnobserved;
        }
    }
    switch (self.activityWork[@(stadium->work)].intValue) {
        case 1: return StadiumReady;
        case 100: return StadiumResolved;
        default: return StadiumUnobserved;
    }
}

+ (NSString *)postgameStadiumTitleWithSavedContext:(DMGuideSavedContext *)saved {
    if (!saved) return @"Postgame stadiums";
    NSUInteger resolved = 0;
    for (NSUInteger index = 0; index < postgameStadiumCount; index++)
        if ([saved resolutionForStadium:&postgameStadiums[index]] == StadiumResolved) resolved++;
    return [NSString stringWithFormat:@"Postgame stadiums · %lu of %d recorded", resolved, postgameStadiumCount];
}

+ (NSArray<NSString *> *)postgameStadiumRowsWithSavedContext:(DMGuideSavedContext *)saved {
    NSArray<NSString *> *areas = DMShieldGuide.areaNames;
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:postgameStadiumCount];
    for (NSUInteger index = 0; index < postgameStadiumCount; index++) {
        const ShieldPostgameStadium *stadium = &postgameStadiums[index];
        NSString *title = areas[stadium->area];
        if (saved) {
            NSString *status;
            switch ([saved resolutionForStadium:stadium]) {
                case StadiumResolved: status = @"Resolution recorded"; break;
                case StadiumReady: status = @"Ready"; break;
                case StadiumDebriefPending: status = @"Debrief pending"; break;
                case StadiumUnobserved: status = @"Status unknown"; break;
            }
            title = [NSString stringWithFormat:@"%@ · %@", title, status];
        }
        [rows addObject:[NSString stringWithFormat:@"%@\n%@", title, stadium->hint]];
    }
    return rows;
}

+ (NSString *)boutiqueTitleInArea:(DMGuideArea)area savedContext:(DMGuideSavedContext *)saved {
    unsigned shop = boutiqueShopInArea(area);
    if (!shop) return nil;
    if (!saved.wardrobeOwnership) return @"Boutique";
    NSUInteger total = 0, owned = 0, count;
    const ShieldBoutiquePart *stock = boutiqueStockForAvatar(saved.wardrobeAvatar, &count);
    const uint8_t *ownership = saved.wardrobeOwnership.bytes;
    BOOL hasStyleCard = [saved.giftItems containsIndex:styleCard];
    for (NSUInteger index = 0; index < count; index++) {
        const ShieldBoutiquePart *item = &stock[index];
        if (item->shop != shop || (item->styleCardRequired && !hasStyleCard)) continue;
        total++;
        if (hasWardrobePart(ownership, item->category, item->part)) owned++;
    }
    return [NSString stringWithFormat:@"Boutique · %lu of %lu owned", owned, total];
}

+ (NSArray<DMGuideBoutiqueCategory *> *)boutiqueCategoriesInArea:(DMGuideArea)area savedContext:(DMGuideSavedContext *)saved {
    unsigned shop = boutiqueShopInArea(area);
    if (!shop || !saved.wardrobeOwnership) return @[];
    NSMutableArray<NSMutableArray<NSString *> *> *items = [NSMutableArray arrayWithCapacity:boutiqueTabCount];
    for (NSUInteger tab = 0; tab < boutiqueTabCount; tab++) [items addObject:[NSMutableArray array]];
    NSUInteger owned[boutiqueTabCount] = {0}, count;
    const ShieldBoutiquePart *stock = boutiqueStockForAvatar(saved.wardrobeAvatar, &count);
    const uint8_t *ownership = saved.wardrobeOwnership.bytes;
    BOOL hasStyleCard = [saved.giftItems containsIndex:styleCard];
    NSNumberFormatter *prices = [NSNumberFormatter new];
    prices.numberStyle = NSNumberFormatterDecimalStyle;
    for (NSUInteger index = 0; index < count; index++) {
        const ShieldBoutiquePart *item = &stock[index];
        if (item->shop != shop || (item->styleCardRequired && !hasStyleCard)) continue;
        NSUInteger tab = item->tab - 1;
        BOOL inWardrobe = hasWardrobePart(ownership, item->category, item->part);
        if (inWardrobe) owned[tab]++;
        NSString *status = inWardrobe ? @"Owned" :
            [NSString stringWithFormat:@"%@ Pokédollars", [prices stringFromNumber:@(item->price)]];
        [items[tab] addObject:[NSString stringWithFormat:@"%@ · %@ · %@", @(item->name), @(item->color), status]];
    }
    NSMutableArray<DMGuideBoutiqueCategory *> *categories = [NSMutableArray array];
    for (NSUInteger tab = 0; tab < boutiqueTabCount; tab++) {
        if (!items[tab].count) continue;
        DMGuideBoutiqueCategory *category = [DMGuideBoutiqueCategory new];
        category.identifier = (NSInteger)tab;
        category.title = [NSString stringWithFormat:@"%@ · %lu of %lu owned", boutiqueTabs[tab], owned[tab], items[tab].count];
        category.items = items[tab];
        [categories addObject:category];
    }
    return categories;
}

+ (NSString *)tmTitleInArea:(DMGuideArea)area savedContext:(DMGuideSavedContext *)saved {
    BOOL wholeCase = area == DMGuideAreaUnknown;
    NSUInteger total = 0, owned = 0;
    for (NSUInteger number = 0; number < technicalMachineCount; number++) {
        if (!wholeCase && technicalMachines[number].area != area) continue;
        total++;
        if ([saved.ownedTMs containsIndex:number]) owned++;
    }
    if (!total) return nil;
    NSString *title = wholeCase ? @"TM case" : @"Local TMs";
    return saved.ownedTMs ? [NSString stringWithFormat:@"%@ · %lu of %lu owned", title, owned, total] : title;
}

+ (NSArray<NSString *> *)tmRowsInArea:(DMGuideArea)area savedContext:(DMGuideSavedContext *)saved {
    BOOL wholeCase = area == DMGuideAreaUnknown;
    NSArray<NSString *> *areaNames = DMShieldGuide.areaNames;
    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    NSNumberFormatter *prices = [NSNumberFormatter new];
    prices.numberStyle = NSNumberFormatterDecimalStyle;
    for (NSUInteger number = 0; number < technicalMachineCount; number++) {
        DMGuideArea source = technicalMachines[number].area;
        if (!wholeCase && source != area) continue;
        NSMutableString *row = [NSMutableString stringWithFormat:@"TM%02lu %@", number, technicalMachines[number].move];
        if (saved.ownedTMs)
            [row appendString:[saved.ownedTMs containsIndex:number] ? @" · Owned" : @" · Missing"];
        if (wholeCase) [row appendFormat:@" · %@", areaNames[source]];
        if (technicalMachines[number].price)
            [row appendFormat:@" · %@ Pokédollars", [prices stringFromNumber:@(technicalMachines[number].price)]];
        [row appendFormat:@"\n%@", technicalMachines[number].hint];
        [rows addObject:row];
    }
    return rows;
}

+ (NSString *)trTitleWithSavedContext:(DMGuideSavedContext *)saved {
    if (!saved.recordedBagItems) return @"Technical Records";
    NSUInteger obtained = [saved.recordedBagItems countOfIndexesInRange:NSMakeRange(firstTRItem, technicalRecordCount)];
    return [NSString stringWithFormat:@"Technical Records · %lu of %d obtained", obtained, technicalRecordCount];
}

+ (NSString *)trSourcesInArea:(DMGuideArea)area {
    NSString *traders;
    if (area == DMGuideAreaWildArea)
        traders = @"Watt Traders at the Meetup Spot, Dappled Grove, East Lake Axewell by Motostoke and Giant’s Seat.";
    else if (area == DMGuideAreaNorthWild)
        traders = @"Watt Traders by the Bridge Field Nursery, at Giant’s Cap and near the Hammerlocke entrance.";
    else
        return nil;
    return [traders stringByAppendingString:
        @"\nTheir five TRs rotate daily. Max Raid Battles can also award TRs. Teaching a move uses one copy."];
}

+ (NSArray<NSString *> *)trRowsWithSavedContext:(DMGuideSavedContext *)saved {
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:technicalRecordCount];
    NSNumberFormatter *prices = [NSNumberFormatter new];
    prices.numberStyle = NSNumberFormatterDecimalStyle;
    for (NSUInteger number = 0; number < technicalRecordCount; number++) {
        NSString *price = [prices stringFromNumber:@(technicalRecords[number].watts)];
        NSString *row = [NSString stringWithFormat:@"TR%02lu %@ · %@ · %@ W", number,
            technicalRecords[number].move, technicalRecords[number].type, price];
        if (saved.bagQuantities) {
            NSUInteger item = firstTRItem + number;
            NSUInteger quantity = saved.bagQuantities[@(item)].unsignedIntegerValue;
            row = [row stringByAppendingFormat:@" · %lu in Bag", quantity];
            if (!quantity && [saved.recordedBagItems containsIndex:item])
                row = [row stringByAppendingString:@" · Previously obtained"];
        }
        [rows addObject:row];
    }
    return rows;
}

static NSInteger battleTowerRank(NSNumber *points) {
    static const uint8_t thresholds[] = {0, 2, 4, 6, 9, 12, 15, 19, 23, 27, 33};
    NSUInteger value = points.unsignedIntegerValue;
    if (!points || value > thresholds[sizeof(thresholds) - 1]) return 0;
    for (NSUInteger i = sizeof(thresholds) - 1; i > 0; i--) {
        if (value >= thresholds[i]) return (NSInteger)i + 1;
    }
    return 1;
}

static NSString *battleTowerRankLabel(NSInteger rank) {
    if (rank == 11) return @"MAX · Master Ball Tier";
    NSString *tier = rank == 10 ? @"Ultra Ball" : rank >= 7 ? @"Great Ball" : rank >= 4 ? @"Poké Ball" : @"Beginner";
    return [NSString stringWithFormat:@"Rank %ld · %@ Tier", (long)rank, tier];
}

- (NSArray<NSString *> *)battleTowerProgressForDoubles:(BOOL)doubles {
    NSInteger current = battleTowerRank(self.activityWork[@(doubles ? towerDoublesPoints : towerSinglesPoints)]);
    NSInteger highest = battleTowerRank(self.activityWork[@(doubles ? towerDoublesHighest : towerSinglesHighest)]);
    NSNumber *wins = doubles ? self.towerDoublesWins : self.towerSinglesWins;
    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    if (current) [rows addObject:battleTowerRankLabel(current)];
    if (highest > current)
        [rows addObject:[@"Highest reached · " stringByAppendingString:battleTowerRankLabel(highest)]];
    if (wins) {
        [rows addObject:[NSString stringWithFormat:@"%@ total %@", wins, wins.intValue == 1 ? @"win" : @"wins"]];
        int earlyGoal = doubles ? cardTowerDoublesGoal : cardTowerSinglesGoal;
        for (NSNumber *goal in @[@(earlyGoal), @(cardTowerFinalGoal)]) {
            int remaining = goal.intValue - wins.intValue;
            NSString *status = remaining <= 0 ? @"Target reached" :
                [NSString stringWithFormat:@"%d %@ to go", remaining, remaining == 1 ? @"win" : @"wins"];
            [rows addObject:[NSString stringWithFormat:@"League Card background · %@ wins · %@", goal, status]];
        }
    }
    return rows;
}

+ (NSString *)rotomFormsTitleWithSavedContext:(DMGuideSavedContext *)saved {
    NSUInteger count = saved.rotomForms.count;
    if (saved.pokemonCollectionKnown)
        return [NSString stringWithFormat:@"Rotom forms · %lu of %d in collection", count, rotomFormCount];
    return count ? [NSString stringWithFormat:@"Rotom forms · %lu found", count] : @"Rotom forms";
}

+ (NSArray<NSString *> *)rotomFormRowsWithSavedContext:(DMGuideSavedContext *)saved {
    static NSString *const forms[rotomFormCount] = {
        @"Rotom · Electric/Ghost\nRecall",
        @"Heat Rotom · Electric/Fire\nMicrowave oven · Overheat",
        @"Wash Rotom · Electric/Water\nWashing machine · Hydro Pump",
        @"Frost Rotom · Electric/Ice\nRefrigerator · Blizzard",
        @"Fan Rotom · Electric/Flying\nElectric fan · Air Slash",
        @"Mow Rotom · Electric/Grass\nLawnmower · Leaf Storm",
    };
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:rotomFormCount];
    for (NSUInteger form = 0; form < rotomFormCount; form++) {
        NSString *status = saved.rotomForms[@(form)];
        if (!status && saved.galarDexSeen)
            status = (saved.rotomSeenForms & (1u << form)) ? @"Seen in Pokédex" : @"Unseen in Pokédex";
        [rows addObject:status ? [forms[form] stringByAppendingFormat:@"\n%@", status] : forms[form]];
    }
    return rows;
}

+ (NSString *)teaEvolutionTitleWithSavedContext:(DMGuideSavedContext *)saved {
    NSUInteger count = saved.polteageistPositions.count;
    if (saved.pokemonCollectionKnown)
        return [NSString stringWithFormat:@"Sinistea evolutions · %lu of %d owned", count, teaFormCount];
    return count ? [NSString stringWithFormat:@"Sinistea evolutions · %lu found", count] : @"Sinistea evolutions";
}

+ (NSArray<NSString *> *)teaEvolutionRowsWithSavedContext:(DMGuideSavedContext *)saved {
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithObject:
        @"Find both Sinistea forms in random encounters in Glimwood Tangle. Antique cups have an authenticity mark underneath."];
    for (NSUInteger form = 0; form < teaFormCount; form++) {
        NSMutableString *row = [NSMutableString stringWithFormat:@"%@ · %@\n%@", teaEvolutions[form].form,
            teaEvolutions[form].pot, teaEvolutions[form].source];
        NSNumber *item = @(teaEvolutions[form].item);
        if (saved.bagQuantities)
            [row appendFormat:@"\n%lu in Bag", saved.bagQuantities[item].unsignedIntegerValue];
        NSUInteger held = saved.heldItemQuantities[item].unsignedIntegerValue;
        if (held) [row appendFormat:@"\n%lu held by Pokémon", held];
        NSString *sinistea = saved.sinisteaPositions[@(form)];
        NSString *polteageist = saved.polteageistPositions[@(form)];
        if (sinistea) [row appendFormat:@"\nSinistea · %@", sinistea];
        else if (saved.pokemonCollectionKnown) [row appendString:@"\nSinistea · Missing"];
        if (polteageist) [row appendFormat:@"\nPolteageist · %@", polteageist];
        else if (saved.pokemonCollectionKnown) [row appendString:@"\nPolteageist · Missing"];
        [rows addObject:row];
    }
    return rows;
}

+ (NSArray<NSString *> *)stowMarketRowsWithSavedContext:(DMGuideSavedContext *)saved {
    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    NSNumberFormatter *prices = [NSNumberFormatter new];
    prices.numberStyle = NSNumberFormatterDecimalStyle;
    if ([saved.savedFlags containsIndex:marketStockInitialized] && [saved.savedFlags containsIndex:marketFirstVisit]) {
        NSUInteger today = saved.activityWork[@(marketToday)].unsignedIntegerValue;
        NSUInteger yesterday = saved.activityWork[@(marketYesterday)].unsignedIntegerValue;
        NSUInteger tomorrow = saved.activityWork[@(marketTomorrow)].unsignedIntegerValue;
        if ([saved.savedFlags containsIndex:marketBoughtToday])
            [rows addObject:@"Today’s bargain · Purchased when last saved"];
        else if (today && today < marketBargainCount)
            [rows addObject:[NSString stringWithFormat:@"Today · %@ · %@ Pokédollars", marketBargains[today].name,
                [prices stringFromNumber:@(marketCurrentPrice)]]];
        if (yesterday && yesterday < marketBargainCount) {
            NSString *status = [saved.savedFlags containsIndex:marketBoughtYesterday] ? @"Purchased when last saved" :
                [NSString stringWithFormat:@"%@ Pokédollars", [prices stringFromNumber:@(marketPreviousPrice)]];
            [rows addObject:[NSString stringWithFormat:@"Yesterday · %@ · %@", marketBargains[yesterday].name, status]];
        }
        if (tomorrow && tomorrow < marketBargainCount)
            [rows addObject:[NSString stringWithFormat:@"Tomorrow’s preview · %@", marketBargains[tomorrow].name]];
    }
    if (rows.count) {
        [rows insertObject:@"Bargains as of the last save" atIndex:0];
    } else {
        [rows addObject:@"Talk to the seller at the right stall to see the current bargain."];
    }
    NSUInteger request = saved.activityWork[@(buyerItem)].unsignedIntegerValue;
    if ([saved.savedFlags containsIndex:dailyBuyerInitialized] && saved.marketRequestOutstanding &&
        request && request < marketBuyerItemCount) {
        NSString *status = saved.marketRequestOutstanding.boolValue ? @"Buyer wants" : @"Sale recorded when last saved";
        NSString *price = [prices stringFromNumber:@(marketBuyerItems[request].price)];
        [rows addObject:[NSString stringWithFormat:@"%@ · %@ · %@ Pokédollars", status, marketBuyerItems[request].name, price]];
        if (saved.marketRequestOutstanding.boolValue && saved.bagQuantities) {
            NSUInteger count = saved.bagQuantities[@(marketBuyerItems[request].item)].unsignedIntegerValue;
            [rows addObject:[NSString stringWithFormat:@"%lu in Bag", count]];
        }
    } else {
        [rows addObject:@"Ask the buyer at the left stall which treasure he wants."];
    }
    return rows;
}

+ (NSArray<NSString *> *)stowBargainStock {
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:marketBargainCount - 1];
    for (NSUInteger offer = 1; offer < marketBargainCount; offer++)
        [rows addObject:[NSString stringWithFormat:@"%@ · %u%%", marketBargains[offer].name, marketBargains[offer].weight]];
    return rows;
}

+ (NSArray<NSString *> *)stowBuyerPrices {
    NSNumberFormatter *prices = [NSNumberFormatter new];
    prices.numberStyle = NSNumberFormatterDecimalStyle;
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:marketBuyerItemCount - 1];
    for (NSUInteger request = 1; request < marketBuyerItemCount; request++)
        [rows addObject:[NSString stringWithFormat:@"%@ · %@ Pokédollars", marketBuyerItems[request].name,
            [prices stringFromNumber:@(marketBuyerItems[request].price)]]];
    return rows;
}

+ (NSString *)cafePrizeTitleInArea:(DMGuideArea)area {
    return cafeIndexForArea(area) == NSNotFound ? nil : @"Battle Café prizes";
}

+ (NSArray<NSString *> *)cafePrizeRowsInArea:(DMGuideArea)area savedContext:(DMGuideSavedContext *)saved {
    NSUInteger cafe = cafeIndexForArea(area);
    if (cafe == NSNotFound) return @[];
    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    uint32_t flag = battleCafes[cafe].dailyFlag;
    if ([saved.knownCafeFlags containsIndex:flag])
        [rows addObject:[saved.savedFlags containsIndex:flag] ? @"Challenge used when last saved" : @"Challenge unused when last saved"];
    NSUInteger roll = saved.activityWork[@(battleCafes[cafe].rollKey)].unsignedIntegerValue;
    NSUInteger cumulative = 0;
    NSString *next = nil;
    for (NSUInteger prize = 0; prize < sizeof(cafePrizes) / sizeof(cafePrizes[0]); prize++) {
        unsigned weight = cafePrizes[prize].weight[cafe];
        if (!weight) continue;
        cumulative += weight;
        NSString *name = cafePrizes[prize].name;
        if (!next && roll > 0 && roll <= cumulative) next = name;
        [rows addObject:[NSString stringWithFormat:@"%@ · %u%%", name, weight]];
    }
    if (next) [rows insertObject:[NSString stringWithFormat:@"Next prize from saved roll · %@", next] atIndex:0];
    return rows;
}

+ (NSString *)alcremieTitleWithSavedContext:(DMGuideSavedContext *)saved {
    NSUInteger count = saved.alcremiePositions.count;
    if (saved.pokemonCollectionKnown)
        return [NSString stringWithFormat:@"Alcremie collection · %lu of %d owned", count, alcremieFormCount];
    return count ? [NSString stringWithFormat:@"Alcremie collection · %lu found", count] : @"Alcremie collection";
}

+ (NSArray<NSString *> *)alcremieSweetTitlesWithSavedContext:(DMGuideSavedContext *)saved {
    NSMutableArray<NSString *> *titles = [NSMutableArray arrayWithCapacity:alcremieSweetCount];
    for (NSUInteger sweet = 0; sweet < alcremieSweetCount; sweet++) {
        NSUInteger count = 0;
        for (NSUInteger flavor = 0; flavor < alcremieFlavorCount; flavor++)
            count += saved.alcremiePositions[@(sweet * alcremieFlavorCount + flavor)] != nil;
        NSString *title = alcremieSweets[sweet];
        if (saved.pokemonCollectionKnown)
            title = [title stringByAppendingFormat:@" · %lu of %d owned", count, alcremieFlavorCount];
        else if (count)
            title = [title stringByAppendingFormat:@" · %lu found", count];
        [titles addObject:title];
    }
    return titles;
}

+ (NSArray<NSString *> *)alcremieRowsForSweet:(NSInteger)sweet savedContext:(DMGuideSavedContext *)saved {
    if (sweet < 0 || sweet >= alcremieSweetCount) return @[];
    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    if (sweet == 0) [rows addObject:@"Find one in Hammerlocke or win it at a Battle Café."];
    else if (sweet < 5) [rows addObject:@"Possible daily reward at the Battle Cafés in Motostoke, Hammerlocke and Wyndon."];
    else [rows addObject:@"Try the Cram-o-matic on the Isle of Armor or trade for one. These Sweets were also rewards in special Milcery raids."];
    NSNumber *item = @(firstAlcremieSweet + sweet);
    NSUInteger held = saved.heldItemQuantities[item].unsignedIntegerValue;
    NSMutableArray<NSString *> *stock = [NSMutableArray arrayWithCapacity:2];
    if (saved.bagQuantities)
        [stock addObject:[NSString stringWithFormat:@"%lu in Bag", saved.bagQuantities[item].unsignedIntegerValue]];
    if (saved.pokemonCollectionKnown || held)
        [stock addObject:[NSString stringWithFormat:@"%lu held by Pokémon", held]];
    if (stock.count) [rows addObject:[stock componentsJoinedByString:@" · "]];
    for (NSUInteger flavor = 0; flavor < alcremieFlavorCount; flavor++) {
        NSString *position = saved.alcremiePositions[@(sweet * alcremieFlavorCount + flavor)];
        NSString *status = position ?: (saved.pokemonCollectionKnown ? @"Missing" : nil);
        NSString *row = [NSString stringWithFormat:@"%@\n%@", alcremieFlavors[flavor].flavor, alcremieFlavors[flavor].spin];
        if (status) row = [row stringByAppendingFormat:@"\n%@", status];
        [rows addObject:row];
    }
    return rows;
}

+ (NSString *)gigantamaxTitleWithSavedContext:(DMGuideSavedContext *)saved {
    NSUInteger count = saved.gigantamaxPositions.count;
    if (saved.pokemonCollectionKnown)
        return [NSString stringWithFormat:@"Gigantamax collection · %lu of %d owned", count, gigantamaxSpeciesCount];
    return count ? [NSString stringWithFormat:@"Gigantamax collection · %lu found", count] : @"Gigantamax collection";
}

+ (NSArray<NSString *> *)gigantamaxRowsWithSavedContext:(DMGuideSavedContext *)saved {
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:gigantamaxSpeciesCount];
    for (NSUInteger i = 0; i < gigantamaxSpeciesCount; i++) {
        NSString *name = gigantamaxSpecies[i].name;
        NSString *position = saved.gigantamaxPositions[@(i)];
        NSMutableString *row = [name mutableCopy];
        if (position) [row appendFormat:@" · Owned · %@", position];
        else if (saved.pokemonCollectionKnown) [row appendString:@" · Missing"];
        if (gigantamaxSpecies[i].source) [row appendFormat:@"\n%@", gigantamaxSpecies[i].source];
        NSArray<NSString *> *dens = [DMShieldGuide gigantamaxRaidLocationsForSpecies:name];
        if (dens.count) [row appendFormat:@"\n%@", [dens componentsJoinedByString:@"\n"]];
        [rows addObject:row];
    }
    return rows;
}

+ (NSString *)silvallyMemoryTitleWithSavedContext:(DMGuideSavedContext *)saved {
    NSUInteger count = saved.ownedSilvallyMemoryCount;
    if (!saved.memoryInventoryKnown && !count) return @"Silvally Memories";
    return [NSString stringWithFormat:@"Silvally Memories · %lu of %d found", count, silvallyMemoryCount];
}

+ (NSArray<NSString *> *)silvallyMemoryRowsWithSavedContext:(DMGuideSavedContext *)saved {
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:silvallyMemoryCount];
    for (NSUInteger index = 0; index < silvallyMemoryCount; index++) {
        NSUInteger item = firstSilvallyMemory + index;
        NSString *status = @"";
        if ([saved.giftItems containsIndex:item]) status = @" · In Bag";
        else if (saved.heldItemQuantities[@(item)].unsignedIntegerValue) status = @" · Held by a Pokémon";
        else if (saved) status = saved.memoryInventoryKnown ? @" · Missing" : @" · Unknown";
        [rows addObject:[NSString stringWithFormat:@"%@ Memory%@", silvallyMemoryTypes[index], status]];
    }
    return rows;
}

+ (NSArray<NSString *> *)battleTowerRankRewardsForDoubles:(BOOL)doubles savedContext:(DMGuideSavedContext *)saved {
    static NSString *const rewards[] = {
        @"Rare Candy · 3 BP",
        @"Rare Candy · 3 BP",
        @"Rare Candy ×2 · Random mint · Bottle Cap · 5 BP",
        @"Rare Candy ×2 · Random mint · 5 BP",
        @"Rare Candy ×2 · Random mint · 5 BP",
        @"Rare Candy ×3 · Random mint · Bottle Cap · 10 BP",
        @"Rare Candy ×3 · Random mint · 10 BP",
        @"Rare Candy ×3 · Random mint · 10 BP",
        @"Rare Candy ×5 · Random mint · Bottle Cap ×2 · Ability Capsule · 20 BP",
        @"Rare Candy ×10 · Random mint · Bottle Cap ×3 · Ability Capsule · Gold Bottle Cap · 50 BP",
    };
    NSInteger current = battleTowerRank(saved.activityWork[@(doubles ? towerDoublesPoints : towerSinglesPoints)]);
    NSInteger highest = battleTowerRank(saved.activityWork[@(doubles ? towerDoublesHighest : towerSinglesHighest)]);
    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    for (NSUInteger index = 0; index < sizeof(rewards) / sizeof(rewards[0]); index++) {
        NSInteger rank = (NSInteger)index + 2;
        NSString *status = MAX(highest, current) >= rank ? @" · Reached" : highest ? @" · Ahead" : @"";
        [rows addObject:[NSString stringWithFormat:@"%@%@\n%@", battleTowerRankLabel(rank), status, rewards[index]]];
    }
    return rows;
}

typedef struct {
    unsigned target;
    __unsafe_unretained NSString *reward;
} TowerWinReward;

+ (NSArray<NSString *> *)battleTowerWinRewardsForDoubles:(BOOL)doubles repeating:(BOOL)repeating
    savedContext:(DMGuideSavedContext *)saved {
    static const TowerWinReward first[] = {
        {10, @"PP Up"}, {20, @"Random mint"}, {30, @"Bottle Cap"}, {40, @"PP Max"},
        {50, @"Gold Bottle Cap"}, {100, @"Lansat Berry"}, {200, @"Starf Berry"},
    };
    static const TowerWinReward repeat[] = {
        {210, @"Random mint"}, {220, @"PP Max"}, {230, @"Bottle Cap"}, {240, @"Ability Capsule"},
        {250, @"Lansat Berry"}, {275, @"Gold Bottle Cap"}, {300, @"Starf Berry"},
    };
    const TowerWinReward *rewards = repeating ? repeat : first;
    NSUInteger count = repeating ? sizeof(repeat) / sizeof(repeat[0]) : sizeof(first) / sizeof(first[0]);
    NSNumber *counter = saved.activityWork[@(doubles ? towerDoublesRewardWins : towerSinglesRewardWins)];
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger index = 0; index < count; index++) {
        const TowerWinReward *reward = &rewards[index];
        NSString *milestone = repeating ? [NSString stringWithFormat:@"Cycle step %u", reward->target - 200] :
            [NSString stringWithFormat:@"%u wins", reward->target];
        NSString *status = @"";
        if (counter) {
            NSInteger remaining = (NSInteger)reward->target - counter.integerValue;
            status = remaining <= 0 ? (repeating ? @" · Reached this cycle" : @" · Reached") :
                [NSString stringWithFormat:@" · %ld %@ to go", (long)remaining, remaining == 1 ? @"win" : @"wins"];
        }
        [rows addObject:[NSString stringWithFormat:@"%@ · %@%@", milestone, reward->reward, status]];
    }
    return rows;
}

+ (NSString *)gymChallengeTitleWithSavedContext:(DMGuideSavedContext *)saved {
    if (!saved) return @"Gym Challenge";
    NSUInteger badges = 0;
    for (NSUInteger index = 0; index < shieldGymCount; index++)
        if ([saved.savedFlags containsIndex:shieldGyms[index].badgeFlag]) badges++;
    return [NSString stringWithFormat:@"Gym Challenge · %lu of %d badges", badges, shieldGymCount];
}

+ (NSArray<NSString *> *)gymChallengeRowsWithSavedContext:(DMGuideSavedContext *)saved {
    NSArray<NSString *> *areas = DMShieldGuide.areaNames;
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithCapacity:shieldGymCount];
    for (NSUInteger index = 0; index < shieldGymCount; index++) {
        const ShieldGym *gym = &shieldGyms[index];
        NSString *row = [NSString stringWithFormat:@"%@ · %@ · %@", areas[gym->area], gym->leader, gym->badge];
        if (saved) {
            NSString *mission = @"Mission status unknown";
            NSString *badge = @"Badge status unknown";
            if ([saved.knownGymFlags containsIndex:gym->missionFlag])
                mission = [saved.savedFlags containsIndex:gym->missionFlag] ? @"Mission cleared" : @"Mission pending";
            if ([saved.knownGymFlags containsIndex:gym->badgeFlag])
                badge = [saved.savedFlags containsIndex:gym->badgeFlag] ? @"Badge earned" : @"Badge pending";
            row = [row stringByAppendingFormat:@"\n%@ · %@", mission, badge];
        }
        [rows addObject:row];
    }
    return rows;
}

- (NSString *)objective {
    return DMGuideOpeningObjective(self.guidance.integerValue);
}

- (NSString *)nextStep {
    if (self.guidance.integerValue != 250) return nil;
    if (self.area == DMGuideAreaWedgehurst) return @"Take the uphill road from Wedgehurst to Route 2.";
    if (self.area == DMGuideAreaRoute2) return @"Follow Route 2 to Professor Magnolia’s house.";
    return nil;
}
@end

typedef int (*OpenCommittedMain)(void);
static _Atomic(OpenCommittedMain) openCommittedMain;

void dm_shield_guide_configure(const char *build, OpenCommittedMain openFile) {
    bool supported = dm_shield_guide_available() && !strcmp(build, DM_SHIELD_GUIDE_BUILD);
    atomic_store(&openCommittedMain, supported ? openFile : NULL);
}

static bool sameFile(struct stat a, struct stat b) {
    return a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_size == b.st_size &&
        a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec &&
        a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec;
}

static NSData *readSnapshot(int fd, struct stat before) {
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)before.st_size];
    uint8_t *bytes = data.mutableBytes;
    size_t offset = 0;
    while (offset < data.length) {
        ssize_t count = pread(fd, bytes + offset, data.length - offset, (off_t)offset);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return nil;
        offset += (size_t)count;
    }
    struct stat after;
    return fstat(fd, &after) == 0 && sameFile(before, after) ? data : nil;
}

@implementation DMGuideSaveMonitor {
    BOOL _loading;
    struct stat _observed;
    BOOL _hasObserved;
}

- (instancetype)init {
    if ((self = [super init])) _status = @"Looking for a committed Shield save…";
    return self;
}

- (void)refresh:(void (^)(void))changed {
    if (_loading) return;
    OpenCommittedMain openFile = atomic_load(&openCommittedMain);
    _loading = YES;
    struct stat observed = _observed;
    BOOL hasObserved = _hasObserved;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        struct stat info = {0};
        int fd = openFile ? openFile() : -1;
        BOOL usable = fd >= 0 && fstat(fd, &info) == 0 && S_ISREG(info.st_mode) && info.st_size > 0 && info.st_size <= maxSaveSize;
        BOOL unchanged = usable && hasObserved && sameFile(observed, info);
        NSData *data = usable && !unchanged ? readSnapshot(fd, info) : nil;
        if (fd >= 0) close(fd);
        DMGuideSavedContext *context = data ? [DMGuideSavedContext decode:data] : nil;
        // Recheck after decoding. The next visible refresh picks up a newer inode.
        BOOL superseded = NO;
        if (data) {
            int latest = openFile();
            struct stat current;
            superseded = latest < 0 || fstat(latest, &current) != 0 || !sameFile(info, current);
            if (latest >= 0) close(latest);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_loading = NO;
            if (unchanged || superseded) return;
            self->_observed = info;
            self->_hasObserved = data != nil;
            if (context) self->_context = context;
            BOOL stale = !context && self->_context != nil;
            NSString *status = context ? @"Based on your last save" :
                stale ? @"Last known save · refresh unavailable" :
                !openFile ? @"Saved guidance requires Shield 1.3.2" :
                fd < 0 ? @"Waiting for a committed Shield save" : @"This Shield save could not be read";
            if (context || stale != self->_stale || ![status isEqualToString:self->_status]) {
                self->_stale = stale;
                self->_status = status;
                changed();
            }
        });
    });
}
@end

// Batch 4 presentation policy shared by AppKit and SwiftUI. Access describes a
// researched prerequisite only; it never establishes the activity's outcome.
static BOOL championActivity(NSString *key) {
    return [@[@"stow.beast-ball", @"postwick.charmander", @"postwick.master-ball",
        @"motostoke.marnie-smile", @"motostoke.steel-beam",
        @"weald.sonia-book", @"circhester.morimoto", @"circhester.morimoto-rematch",
        @"circhester.oval-charm", @"wyndon.champion-tournament", @"wyndon.tournament-reward",
        @"hulbury.delivery-station", @"hulbury.delivery-swirlix", @"hulbury.delivery-market"] containsObject:key]
        || [key hasPrefix:@"battle-tower."] || [key hasSuffix:@".postgame-stadium"]
        || [@[@"hammerlocke.sonia-lock", @"weald.sonia-shrine", @"weald.postgame-epilogue",
            @"power-plant.zamazenta", @"spikemuth.marnie", @"spikemuth.marnie-daily"] containsObject:key];
}

static NSString *activityRequirement(DMGuideActivity *activity) {
    // Story-only return conditions have no promoted access predicate. Keep them
    // in planning until independent evidence is available, rather than ranking
    // Motostoke's Fire Gym ahead of its first-visit gifts.
    if ([activity.key hasSuffix:@".gym-mission"]) return @"the local Gym story visit";
    if ([activity.key hasSuffix:@".gym-badge"]) return @"the local Gym mission";
    NSDictionary<NSString *, NSString *> *returns = @{
        @"wedgehurst.galarian-slowpoke": @"the first Wild Area visit",
        @"motostoke.hop-win": @"the opening ceremony",
        @"postwick.sonia-revives": @"the Champion Cup return to Postwick",
        @"weald.misty-seed": @"the open path beyond the fog barrier",
        @"weald.phantom-force": @"the open path beyond the fog barrier",
        @"motostoke.minccino-reward": @"Minccino’s return"
    };
    if (returns[activity.key]) return returns[activity.key];
    if (championActivity(activity.key)) return @"Champion status";
    if ([activity.key hasPrefix:@"weald."]) return @"the open path beyond the fog barrier";
    if (activity.waterModeHint) return @"Water Mode on Route 9";
    if ([activity.key isEqualToString:@"ballonlea.letter"]) return @"Paula’s letter from Hammerlocke";
    if ([activity.key isEqualToString:@"hammerlocke.letter-return"]) return @"Letter delivery in Ballonlea";
    return nil;
}

static NSNumber *requirementRecorded(DMGuideActivity *activity, DMGuideSavedContext *saved) {
    if (!saved) return nil;
    if ([activity.key hasSuffix:@".gym-badge"]) {
        for (NSUInteger i = 0; i < shieldGymCount; i++) {
            const ShieldGym *gym = &shieldGyms[i];
            if (![activity.key isEqualToString:gym->badgeKey]) continue;
            return [saved.knownGymFlags containsIndex:gym->missionFlag] ? @([saved.savedFlags containsIndex:gym->missionFlag]) : nil;
        }
    }
    if ([activity.key isEqualToString:@"motostoke.minccino-reward"])
        return saved.minccinoStage && saved.minccinoStage.integerValue >= 0 && saved.minccinoStage.integerValue <= 3 ?
            @(saved.minccinoStage.integerValue >= 2) : nil;
    // Water Mode alone cannot establish the later Weald path's access.
    if ([activity.key hasPrefix:@"weald."] && !championActivity(activity.key)) return nil;
    if (activity.waterModeHint) {
        if (!saved.waterModeRecorded || (saved.waterModeRecorded.boolValue && !saved.giftItems)) return nil;
        return @([saved hasWaterMode]);
    }
    if (championActivity(activity.key)) return saved.isChampion;
    if ([activity.key isEqualToString:@"ballonlea.letter"] ||
        [activity.key isEqualToString:@"hammerlocke.letter-return"]) {
        NSNumber *letter = saved.activityWork[@(letterProgress)];
        if (!letter || letter.integerValue < 0 || letter.integerValue > 4) return nil;
        return @(letter.integerValue >= ([activity.key isEqualToString:@"ballonlea.letter"] ? 2 : 3));
    }
    return nil;
}

@implementation DMGuideActivityRow
- (instancetype)initWithActivity:(DMGuideActivity *)activity saved:(DMGuideSavedContext *)saved
    guide:(DMShieldGuide *)guide readOnly:(BOOL)readOnly {
    if ((self = [super init])) {
        _activity = activity;
        _hint = [saved hintForActivity:activity] ?: activity.hint;
        NSString *completion = [saved activityCompletionForKey:activity.key];
        BOOL marked = !readOnly && [guide isChecked:activity];
        _completed = completion != nil || marked;
        NSString *evidence = [saved activityEvidenceForKey:activity.key];
        _status = readOnly ? @"Archive reference · read only" : completion ?: (marked ?
            (activity.isDaily ? @"Checked off by you today" : @"Checked off by you") :
            evidence ? [@"Last saved state · " stringByAppendingString:evidence] : @"Player confirmation available");
        NSString *requirement = activityRequirement(activity);
        NSNumber *recorded = requirementRecorded(activity, saved);
        _later = !_completed && requirement && !recorded.boolValue;
        _access = !requirement ? @"Access not checked · see details" : !recorded ?
            [@"Access unknown · requires " stringByAppendingString:requirement] : !recorded.boolValue ?
            [@"Not unlocked in this save · requires " stringByAppendingString:requirement] :
            [requirement stringByAppendingString:@" recorded · check local conditions"];
        NSString *key = activity.key;
        if ([key isEqualToString:@"hammerlocke.letter"] || [key isEqualToString:@"hammerlocke.letter-return"])
            _relatedAreas = @[@(DMGuideAreaBallonlea)];
        else if ([key isEqualToString:@"ballonlea.letter"]) _relatedAreas = @[@(DMGuideAreaHammerlocke)];
        else if (activity.waterModeHint) _relatedAreas = @[@(DMGuideAreaRoute9)];
        else if ([key isEqualToString:@"route9.bike-water-mode"]) _relatedAreas = @[@(DMGuideAreaRoute2), @(DMGuideAreaNorthWild)];
        else _relatedAreas = @[];
    }
    return self;
}
@end

@implementation DMGuidePresentation
+ (instancetype)resolveSource:(DMGuideSource)source manualArea:(DMGuideArea)area
    saved:(DMGuideSavedContext *)saved stale:(BOOL)stale status:(NSString *)status
    live:(DMGuideLiveLocation *)live preview:(DMGuideSnapshot *)preview {
    DMGuidePresentation *result = [self new];
    result->_area = area >= 0 && area < (NSInteger)DMShieldGuide.areaNames.count ? area : DMGuideAreaWedgehurst;
    result->_readOnly = source == DMGuideSourceArchive;
    result->_progress = !result.readOnly && !stale ? saved : nil;
    NSMutableArray<NSString *> *summary = [NSMutableArray array];
    if (result.readOnly && preview) {
        result->_area = preview.area;
        [summary addObject:[@"Archived location · " stringByAppendingString:DMShieldGuide.areaNames[preview.area]]];
        [summary addObject:[@"Archived objective · " stringByAppendingString:preview.objective ?: @"Unknown"]];
        [summary addObject:preview.nextStep];
        [summary addObject:[@"Archived party · " stringByAppendingString:[preview.party componentsJoinedByString:@", "]]];
        [summary addObject:@"Read-only archive reference · current progress and player marks are hidden"];
    } else {
        live = source == DMGuideSourceCurrent ? live : nil;
        BOOL savedArea = source != DMGuideSourceManual && !stale && saved && saved.area >= 0;
        if (live) {
            result->_area = live.area;
            result->_wildSubarea = live.wildSubarea;
            [summary addObject:[(live.placementBased ? @"Live location estimate · " : @"Live location · ") stringByAppendingString:live.name]];
        } else {
            if (source == DMGuideSourceCurrent) [summary addObject:@"Live location unavailable"];
            if (savedArea) { result->_area = saved.area; result->_wildSubarea = saved.wildSubarea; }
        }
        result->_canChooseArea = !live && !savedArea && !result.readOnly;
        if (result.canChooseArea) [summary addObject:[@"Browsing · " stringByAppendingString:DMShieldGuide.areaNames[result.area]]];
        [summary addObject:status];
        if (saved) {
            NSString *prefix = stale ? @"Last-known saved location · " :
                saved.placementBasedLocation ? @"Saved location estimate · " : @"Saved location · ";
            [summary addObject:[prefix stringByAppendingString:saved.location ?: @"Unknown"]];
            [summary addObject:[(stale ? @"Last-known saved objective · " : @"Last saved objective · ")
                stringByAppendingString:saved.objective ?: @"Unknown"]];
            if (!stale && saved.area == result.area && saved.nextStep) [summary addObject:saved.nextStep];
            else if (live && saved.area != result.area)
                [summary addObject:@"You have moved since saving · local story directions wait for a matching save"];
        }
        [summary addObject:result.progress ? @"Checklist and collection progress · last readable game save; player marks are stored on this device" :
            @"Automatic progress unavailable · player marks are stored on this device"];
    }
    result->_summary = summary;
    return result;
}

- (NSArray<DMGuideActivityRow *> *)rowsWithGuide:(DMShieldGuide *)guide query:(NSString *)query incompleteOnly:(BOOL)incompleteOnly {
    NSMutableArray<DMGuideActivityRow *> *rows = [NSMutableArray array];
    NSString *trimmed = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    for (DMGuideActivity *activity in [DMShieldGuide activitiesInArea:self.area]) {
        DMGuideActivityRow *row = [[DMGuideActivityRow alloc] initWithActivity:activity saved:self.progress guide:guide readOnly:self.readOnly];
        if (incompleteOnly && row.completed) continue;
        NSString *search = [NSString stringWithFormat:@"%@ %@ %@", activity.title, activity.hint, activity.directions];
        if (trimmed.length && [search rangeOfString:trimmed options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location == NSNotFound) continue;
        [rows addObject:row];
    }
    return rows;
}

+ (NSArray<NSString *> *)servicesInArea:(DMGuideArea)area {
    // Landmark index, official guide town maps and handbook pp. 194–205,
    // 224–248, 281–297, 354, 356/358, 381–382; see final-source-audit.md. No new pins.
    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    if ([@[@(DMGuideAreaWedgehurst), @(DMGuideAreaMotostoke), @(DMGuideAreaTurffield), @(DMGuideAreaHulbury),
        @(DMGuideAreaHammerlocke), @(DMGuideAreaStow), @(DMGuideAreaBallonlea), @(DMGuideAreaCirchester),
        @(DMGuideAreaSpikemuth), @(DMGuideAreaWyndon)] containsObject:@(area)])
    {
        [rows addObject:@"Pokémon Center · heal your team, visit the Poké Mart, and use Rotomi for Boxes, Poké Jobs and Loto-ID. Jobs and the daily lottery have story unlocks; Loto-ID opens after meeting Milo on Route 4."];
        [rows addObject:@"Jack’s counter · inside the Pokémon Center, ask Jack to remember or forget moves or review a nickname. After three Gym Badges he can also describe a Pokémon’s memories."];
    }
    // Official guide pp. 281–297: original summaries, independent of saved outcomes.
    if ([@[@(DMGuideAreaRoute3), @(DMGuideAreaRoute4), @(DMGuideAreaRoute5), @(DMGuideAreaRoute6),
        @(DMGuideAreaRoute7), @(DMGuideAreaRoute8), @(DMGuideAreaRoute9), @(DMGuideAreaRoute10)] containsObject:@(area)])
        [rows addObject:@"Camping and visitors · use Pokémon Camp from the game menu on dry land. Cooking and play raise friendship; sociable party Pokémon may attract a wild visitor at an eligible camp. Check the visitor’s prompt rather than assuming a catch. When cooking at another Trainer’s camp, the host chooses the main ingredient and you contribute Berries."];
    switch (area) {
        case DMGuideAreaWedgehurst: [rows addObject:@"Station and boutique · rail travel is on the south side of town; visit the clothing shop along the main street."]; break;
        case DMGuideAreaMotostoke: [rows addObject:@"Battle Café and record shops · explore the main street before taking the lift. The move tutor is by the canal below the Budew Drop Inn."]; break;
        case DMGuideAreaHulbury: [rows addObject:@"Herb stall · visit Hulbury’s market for Energy Powder (500 Pokédollars), Energy Root (1,200), Heal Powder (300) and Revival Herb (2,800). These bitter medicines lower friendship when used."]; [rows addObject:@"Market and restaurant · buy incense at the market; find the Captain’s Table by the main street. The chef’s deliveries are Champion return visits."]; break;
        case DMGuideAreaHammerlocke: [rows addObject:@"BP shop · the central Pokémon Center sells training and evolution items. Destiny Knot, Sachet, Whipped Dream, Protector, Razor Claw and Reaper Cloth cost 10 BP each. Buy the item here, then follow the species’ evolution recipe; ownership alone does not perform the evolution."]; [rows addObject:@"Battle Café · west of the central Pokémon Center. Friendship and ribbon checks are in the house by that Center. Find the pledge tutor by the moat."]; break;
        case DMGuideAreaStow: [rows addObject:@"Street Market · the two stalls near the entrance offer a daily bargain and a requested-item buyer. Inspect their saved state and stock below."]; break;
        case DMGuideAreaCirchester: [rows addObject:@"Hotel Ionia and Hero’s Bath · the west hotel has the director and Morimoto; the east hotel has the detective. Find the Draco Meteor tutor west of the bath."]; break;
        case DMGuideAreaWyndon: [rows addObject:@"Battle Café and move tutor · the café is in south Wyndon; the starter move tutor is in the eastern park near the court. Champion Tournaments are at the stadium."]; break;
        case DMGuideAreaRoute5: [rows addObject:@"Nursery · stop by the route building for deposits and Eggs. Both Nurseries share your saved hatch count."]; break;
        case DMGuideAreaNorthWild: [rows addObject:@"Bridge Field · Nursery, Digging Duo and Rotom Rallyists. Check subarea landmarks, weather and standard den pools below."]; break;
        case DMGuideAreaWildArea: [rows addObject:@"Camping King · by the steps to Motostoke, ask to change your tent color. The lead Pokémon’s type determines the available color; a dual-type lead offers two choices. Curry Dex assessment and its rewards are separate options."]; [rows addObject:@"Wild Area services · Watt Traders, ingredient sellers, Camping King and Rotom Rallyists. Choose a subarea for landmarks, weather and standard den pools."]; break;
        case DMGuideAreaBattleTower: [rows addObject:@"BP counters · the left counter sells Mints for 50 BP each. The right counter sells Ability Capsules (50 BP), Bottle Caps (25 BP) and battle held items. Hyper Training requires a Lv. 100 Pokémon; a Bottle Cap trains one stat and a Gold Bottle Cap all eligible stats."]; [rows addObject:@"Battle Tower lobby · register at the main counter, try the rental desk, and browse BP shops, TMs and Hyper Training. Battle facilities open after becoming Champion."]; break;
        default: break;
    }
    return rows;
}
@end
