#pragma once
#import "shield_guide.h"

typedef struct {
    DMGuideArea area;
    NSString *key;
    NSString *name;
    NSString *hint;
    uint32_t flag;
    unsigned count;
} ShieldCardBackground;

// Each group contains backgrounds that share one Unlock flag in the base Card Maker table.
static const ShieldCardBackground shieldCardBackgrounds[] = {
    {DMGuideAreaGalarMine, @"galar-mine.card-background", @"Galar Mine", @"Enter Galar Mine from Route 3.", 0xF582000A, 1},
    {DMGuideAreaTurffield, @"turffield.card-arrival", @"Turffield", @"Arrive in Turffield from Route 4.", 0xB548F355, 1},
    {DMGuideAreaTurffield, @"turffield.card-geoglyph", @"Turffield geoglyph", @"Meet Sonia at the geoglyph overlook.", 0xE24FEA30, 1},
    {DMGuideAreaHulbury, @"hulbury.card-arrival", @"Hulbury", @"Arrive in Hulbury from Route 5.", 0x9CC12CF8, 3},
    {DMGuideAreaMine2, @"mine2.card-arrival", @"Galar Mine No. 2", @"Enter Galar Mine No. 2 from Hulbury.", 0xF1AF2F0C, 1},
    {DMGuideAreaHulbury, @"hulbury.card-departure", @"Captain’s Table visit", @"Talk to Hop outside the Captain’s Table after dinner with Chairman Rose.", 0xFDCC9451, 1},
    {DMGuideAreaHammerlocke, @"hammerlocke.card-arrival", @"Hammerlocke", @"Visit Hammerlocke for the first time.", 0xDCE1AD9B, 2},
    {DMGuideAreaStow, @"stow.card-arrival", @"Stow-on-Side", @"Arrive in Stow-on-Side from Route 6.", 0x98EE6113, 2},
    {DMGuideAreaBallonlea, @"ballonlea.card-arrival", @"Ballonlea", @"Arrive in Ballonlea through Glimwood Tangle.", 0xA749BE2E, 2},
    {DMGuideAreaCirchester, @"circhester.card-arrival", @"Circhester", @"Arrive in Circhester from Route 8.", 0xA2055DC9, 2},
    {DMGuideAreaCirchester, @"circhester.card-invitation", @"Circhester dinner invitation", @"Speak with Sonia after the Ice Gym for the invitation to Bob’s Your Uncle.", 0x80A703C5, 1},
    {DMGuideAreaSpikemuth, @"spikemuth.card-arrival", @"Spikemuth", @"Enter Spikemuth from Route 9.", 0xD85A1D9C, 2},
    {DMGuideAreaWyndon, @"wyndon.card-arrival", @"Wyndon", @"Arrive in Wyndon from Route 10.", 0xE225D7A0, 2},
    {DMGuideAreaTurffield, @"turffield.card-badge", @"Grass Badge", @"Earn Milo’s badge at Turffield Stadium.", 0x299E4801, 1},
    {DMGuideAreaHulbury, @"hulbury.card-badge", @"Water Badge", @"Earn Nessa’s badge at Hulbury Stadium.", 0xFF80169D, 1},
    {DMGuideAreaMotostoke, @"motostoke.card-badge", @"Fire Badge", @"Earn Kabu’s badge at Motostoke Stadium.", 0x7F29D95E, 1},
    {DMGuideAreaStow, @"stow.card-badge", @"Ghost Badge", @"Earn Allister’s badge at Stow-on-Side Stadium.", 0x71BFDED1, 2},
    {DMGuideAreaBallonlea, @"ballonlea.card-badge", @"Fairy Badge", @"Earn Opal’s badge at Ballonlea Stadium.", 0x8BCBBCDE, 1},
    {DMGuideAreaCirchester, @"circhester.card-badge", @"Ice Badge", @"Earn Melony’s badge at Circhester Stadium.", 0xFE5A7D5F, 2},
    {DMGuideAreaSpikemuth, @"spikemuth.card-badge", @"Dark Badge", @"Earn Piers’s badge in Spikemuth.", 0xC90B46C2, 2},
    {DMGuideAreaHammerlocke, @"hammerlocke.card-badge", @"Dragon Badge", @"Earn Raihan’s badge at Hammerlocke Stadium.", 0x375FD6A8, 2},
    {DMGuideAreaWyndon, @"wyndon.card-champion", @"Champion", @"Defeat Leon at Wyndon Stadium.", 0x4DBE8A87, 3},
    {DMGuideAreaMotostoke, @"motostoke.card-ball-guy", @"Ball Guy", @"After becoming Champion, speak to Ball Guy outside Motostoke Stadium.", 0x13007B5C, 1},
    {DMGuideAreaWeald, @"weald.card-epilogue-start", @"Epilogue opening", @"As Champion, meet Hop and Sonia at the shrine.", 0x34B0D5E8, 1},
    {DMGuideAreaWeald, @"weald.card-epilogue-end", @"Epilogue ending", @"Return to the shrine for Hop’s final battle and the conversation afterward.", 0xE4136279, 1},
    {DMGuideAreaTurffield, @"turffield.card-postgame", @"Turffield stadium incident", @"Resolve the stadium incident and finish the debrief.", 0x37AFE5F0, 1},
    {DMGuideAreaHulbury, @"hulbury.card-postgame", @"Hulbury stadium incident", @"Resolve the postgame incident at Hulbury Stadium.", 0x6DB18113, 1},
    {DMGuideAreaMotostoke, @"motostoke.card-postgame", @"Motostoke stadium incident", @"Resolve the postgame incident at Motostoke Stadium.", 0x8CBE6D4B, 1},
    {DMGuideAreaHammerlocke, @"hammerlocke.card-postgame", @"Hammerlocke stadium incident", @"Resolve the postgame incident at Hammerlocke Stadium.", 0x75333DAB, 1},
    {DMGuideAreaStow, @"stow.card-postgame", @"Stow-on-Side stadium incident", @"Resolve the postgame incident at Stow-on-Side Stadium.", 0x3C0A523D, 1},
    {DMGuideAreaCirchester, @"circhester.card-postgame", @"Circhester stadium incident", @"Resolve the postgame incident at Circhester Stadium.", 0x7A67C926, 1},
    {DMGuideAreaWildArea, @"wild-area.card-lets-go-eevee", @"Let’s Go, Eevee!", @"This background uses compatible Let’s Go, Eevee! save data.", 0xC804E4AF, 1},
    {DMGuideAreaWildArea, @"wild-area.card-lets-go-pikachu", @"Let’s Go, Pikachu!", @"This background uses compatible Let’s Go, Pikachu! save data.", 0x1C74460E, 1},
    {DMGuideAreaWildArea, @"wild-area.card-pokemon-quest", @"Pokémon Quest", @"This background uses compatible Pokémon Quest save data.", 0xBF24DDAE, 1},
};

typedef struct {
    DMGuideArea area;
    NSString *key;
    NSString *name;
    NSString *hint;
    unsigned record;
    unsigned target;
} ShieldCardBackgroundTarget;

enum {
    firstCardBackgroundRecord = 42, cardHairServiceRecord = 46, lastCardBackgroundRecord = cardHairServiceRecord,
    cardStarterFlag = 0xB39286E2, cardStarterBackgrounds = 9,
    cardTowerSinglesGoal = 30, cardTowerDoublesGoal = 50, cardTowerFinalGoal = 100,
};

static const ShieldCardBackgroundTarget shieldCardBackgroundTargets[] = {
    {DMGuideAreaWildArea, @"wild-area.card-curry", @"Curry Dex recipes", @"Record 15 recipes by cooking at a Pokémon Camp.", 42, 15},
    {DMGuideAreaWildArea, @"wild-area.card-raids", @"Max Raid participation", @"Take part in 30 Max Raid Battles.", 43, 30},
    {DMGuideAreaMotostoke, @"motostoke.card-earnings", @"Lifetime earnings", @"Earn 1,000,000 Pokédollars over your adventure.", 44, 1000000},
    {DMGuideAreaMotostoke, @"motostoke.card-creator", @"League Card designs", @"Make 10 cards using Card Maker at Rotomi.", 45, 10},
    {DMGuideAreaMotostoke, @"motostoke.card-hairstyles", @"Salon visits", @"Use the Hair service 10 times. Start at Motostoke’s hair salon.", cardHairServiceRecord, 10},
};

typedef NS_ENUM(NSUInteger, ShieldCardStyleCategory) {
    ShieldCardStyleEffect,
    ShieldCardStyleFrame,
    ShieldCardStyleExpression,
    ShieldCardStylePose,
    ShieldCardStyleCoating,
    ShieldCardStyleCategoryCount,
};

typedef struct {
    uint32_t flag;
    uint8_t counts[ShieldCardStyleCategoryCount];
    NSString *coatingPrices;
} ShieldCardStyleUnlock;

// Non-background options grouped by the same exact flags used by Card Maker.
// Each count lists effects, frames, expressions, poses, and coatings in order.
static const ShieldCardStyleUnlock shieldCardStyleUnlocks[] = {
    {cardStarterFlag, {4, 3, 23, 7, 2}, nil},
    {0x299E4801, {1, 2, 0, 1, 1}, @"Checkered Foil costs 500 Pokédollars."},
    {0xFF80169D, {2, 1, 0, 1, 0}, nil},
    {0x7F29D95E, {1, 2, 0, 2, 0}, nil},
    {0x71BFDED1, {1, 2, 0, 2, 1}, @"Dot Foil costs 1,000 Pokédollars."},
    {0x8BCBBCDE, {2, 2, 0, 1, 0}, nil},
    {0xFE5A7D5F, {2, 1, 0, 2, 0}, nil},
    {0xC90B46C2, {2, 2, 0, 1, 2}, @"Bubble Foil costs 1,200 Pokédollars and Heart Foil costs 1,600."},
    {0x375FD6A8, {1, 1, 0, 2, 0}, nil},
    {0x4DBE8A87, {3, 1, 7, 1, 2}, @"Starry Foil costs 2,400 Pokédollars and Crosshatch Foil costs 3,600."},
    {0xE4136279, {1, 0, 0, 0, 1}, @"Brilliant Foil costs 5,500 Pokédollars."},
    {0x1C74460E, {0, 1, 0, 0, 0}, nil},
    {0xC804E4AF, {0, 1, 0, 0, 0}, nil},
    {0xBF24DDAE, {0, 1, 0, 0, 0}, nil},
};

static inline const ShieldCardStyleUnlock *cardStyleUnlockForFlag(uint32_t flag) {
    for (NSUInteger index = 0; index < sizeof(shieldCardStyleUnlocks) / sizeof(shieldCardStyleUnlocks[0]); index++) {
        if (shieldCardStyleUnlocks[index].flag == flag) return &shieldCardStyleUnlocks[index];
    }
    return NULL;
}
