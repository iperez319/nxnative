#pragma once
#import "shield_guide.h"

typedef struct {
    NSString *key;
    NSString *name;
    DMGuideArea area; // Unknown denotes stock shared by stadium uniform shops.
    NSString *source;
    uint8_t outfitIndex[2]; // Top, legwear and shoes share this index. Shorts use index + 1.
    int8_t gloveIndex; // -1 indicates the preset does not include a glove.
} ShieldUniform;

// Obtained from the uniform presets and the two avatar clothing tables in Shield 1.3.2.
static const ShieldUniform shieldUniforms[] = {
    {@"uniform.challenger", @"Challenger Uniform", DMGuideAreaMotostoke, @"Register for the Gym Challenge in Motostoke.", {0, 0}, 0},
    {@"uniform.grass", @"Grass Uniform", DMGuideAreaTurffield, @"Earn Milo’s badge at Turffield Stadium.", {1, 6}, 1},
    {@"uniform.water", @"Water Uniform", DMGuideAreaHulbury, @"Earn Nessa’s badge at Hulbury Stadium.", {2, 7}, 2},
    {@"uniform.fire", @"Fire Uniform", DMGuideAreaMotostoke, @"Earn Kabu’s badge at Motostoke Stadium.", {3, 8}, 3},
    {@"uniform.ghost", @"Ghost Uniform", DMGuideAreaStow, @"Earn Allister’s badge at Stow-on-Side Stadium.", {4, 9}, 4},
    {@"uniform.fighting", @"Fighting Uniform", DMGuideAreaUnknown, nil, {5, 10}, 5},
    {@"uniform.fairy", @"Fairy Uniform", DMGuideAreaBallonlea, @"Earn Opal’s badge at Ballonlea Stadium.", {6, 11}, 6},
    {@"uniform.rock", @"Rock Uniform", DMGuideAreaUnknown, nil, {7, 12}, 7},
    {@"uniform.ice", @"Ice Uniform", DMGuideAreaCirchester, @"Earn Melony’s badge at Circhester Stadium.", {8, 13}, 8},
    {@"uniform.dark", @"Dark Uniform", DMGuideAreaSpikemuth, @"Earn Piers’s badge in Spikemuth.", {9, 14}, 9},
    {@"uniform.dragon", @"Dragon Uniform", DMGuideAreaHammerlocke, @"Earn Raihan’s badge at Hammerlocke Stadium.", {10, 15}, 10},
    {@"uniform.bug", @"Bug Uniform", DMGuideAreaUnknown, nil, {11, 16}, 11},
    {@"uniform.steel", @"Steel Uniform", DMGuideAreaUnknown, nil, {12, 17}, 12},
    {@"uniform.psychic", @"Psychic Uniform", DMGuideAreaUnknown, nil, {13, 18}, 13},
    {@"uniform.electric", @"Electric Uniform", DMGuideAreaUnknown, nil, {14, 19}, 14},
    {@"uniform.ground", @"Ground Uniform", DMGuideAreaUnknown, nil, {15, 20}, 15},
    {@"uniform.flying", @"Flying Uniform", DMGuideAreaUnknown, nil, {16, 21}, 16},
    {@"uniform.normal", @"Normal Uniform", DMGuideAreaUnknown, nil, {17, 22}, 17},
    {@"uniform.poison", @"Poison Uniform", DMGuideAreaUnknown, nil, {18, 23}, 18},
    {@"uniform.champion", @"Champion Uniform", DMGuideAreaWyndon, @"Defeat Leon in the Champion Cup at Wyndon Stadium.", {19, 1}, -1},
    {@"uniform.ranked", @"Ranked Battles Uniform", DMGuideAreaBattleTower,
        @"After taking part in a Link Battle, speak to the BP shop clerk at the Battle Tower.", {22, 4}, -1},
    {@"uniform.tower", @"Battle Tower Uniform", DMGuideAreaBattleTower,
        @"Defeat Leon in the Battle Tower’s Ultra Ball Tier promotion battle.", {23, 5}, -1},
};

enum { shieldUniformCount = sizeof(shieldUniforms) / sizeof(shieldUniforms[0]) };
