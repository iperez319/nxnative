#pragma once
#import <Foundation/Foundation.h>

enum { fossilizedBird = 1105, fossilizedFish, fossilizedDrake, fossilizedDino };

typedef struct {
    NSString *key;
    NSString *species;
    unsigned nationalNumber;
    unsigned galarNumber;
    unsigned upperPiece;
    unsigned lowerPiece;
} ShieldFossilRecipe;

static const ShieldFossilRecipe fossilRecipes[] = {
    {@"route6.fossil.dracozolt", @"Dracozolt", 880, 374, fossilizedBird, fossilizedDrake},
    {@"route6.fossil.arctozolt", @"Arctozolt", 881, 375, fossilizedBird, fossilizedDino},
    {@"route6.fossil.dracovish", @"Dracovish", 882, 376, fossilizedFish, fossilizedDrake},
    {@"route6.fossil.arctovish", @"Arctovish", 883, 377, fossilizedFish, fossilizedDino},
};
enum { fossilRecipeCount = sizeof(fossilRecipes) / sizeof(fossilRecipes[0]) };

static inline NSString *fossilPieceName(unsigned item) {
    static NSString *const names[] = {@"Fossilized Bird", @"Fossilized Fish", @"Fossilized Drake", @"Fossilized Dino"};
    return names[item - fossilizedBird];
}
