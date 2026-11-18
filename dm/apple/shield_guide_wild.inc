// Individual slots are grouped by encounter method at display time, keeping
// distinct level ranges and forms that share a species name.
typedef NS_ENUM(uint8_t, WildMethod) {
    WildVisible, WildGrass, WildGround, WildFlying, WildWater, WildStrong, WildChampion, WildTree, WildFish, WildMethodCount
};

static const struct {
    uint8_t subarea, method;
    uint16_t weather;
    uint8_t minLevel, maxLevel;
    const char *name;
} wildSlots[] = {
#include "shield_guide_wild_data.inc"
#include "shield_guide_wanderer_data.inc"
};

typedef struct {
    uint8_t subarea, number, pool[2];
    uint16_t x, y;
} RaidDen;

typedef struct {
    uint8_t pool, chance[5];
    const char *name;
} RaidSlot;

#include "shield_guide_raid_data.inc"

typedef struct {
    NSString *name;
    NSString *directions;
} ShieldWildSubarea;

static const ShieldWildSubarea southWildSubareas[] = {
    {@"Rolling Fields", @"From the Meetup Spot, head north into the fields. Find the ingredient seller toward Lake Miloch and TM84 in the hollow log by a den. Chloe can appear here."},
    {@"Dappled Grove", @"Head west from Rolling Fields and look for the Watt Trader by the Berry tree. Check sparkles for Fancy Apples and look for the White Herb by the border with Watchtower Ruins."},
    {@"Watchtower Ruins", @"Climb the northwest bluff to the broken tower. Look at the tower base for Max Revive and check the dead log southwest of it for White Herb."},
    {@"East Lake Axewell", @"Follow the north shore toward the Motostoke staircase. The Camping King and Watt Trader stand east of the entrance. Chloe can appear around the lake."},
    {@"West Lake Axewell", @"Cross the footbridge over the narrow part of the lake. Check the banks for fishing spots and sparkles. The subarea extends north to the Motostoke wall."},
    {@"Axew’s Eye", @"Use Water Mode to reach the island in the middle of Lake Axewell. Look for TM95 at the west end, Sweet Apple by the tree and Rare Candy by the east-shore rocks. Chloe can appear here."},
    {@"South Lake Miloch", @"Follow the south shore toward the footbridge to Giant’s Seat. Look for pearl sparkles near the water, including spots that can yield a Prism Scale."},
    {@"Giant’s Seat", @"Cross the footbridge from South Lake Miloch. The Watt Trader is near the bridge. Follow the cliff wall behind the rock spire for TM81 and look by the northeast tree for Leftovers. Chloe can appear here."},
    {@"North Lake Miloch", @"Check the high east bank overlooking Giant’s Seat for the Thunder Stone. The bridge east of Motostoke leads north from this side of the river."},
};

static const ShieldWildSubarea northWildSubareas[] = {
    {@"Motostoke Riverbank", @"Cross the bridge east of Motostoke from North Lake Miloch. Check along the city wall and the large pipes for the Fire Stone and TM39."},
    {@"Bridge Field", @"Follow the eastern edge between the bridges to the Nursery and Digging Duo. Look along the city wall for Water Stone and use Water Mode for TM75. Chloe can appear here."},
    {@"Stony Wilderness", @"Head north under the Route 5 bridge. Check around the standing rocks and dens for sparkles that can yield Stardust or Star Pieces. Chloe can appear here."},
    {@"Dusty Bowl", @"Descend into the central basin. Look for fossils and the stone arch where Galarian Yamask evolves. Use Water Mode for TM73 on the island in the north pond. Chloe can appear here."},
    {@"Giant’s Mirror", @"Follow the east edge above the Route 5 bridge. Look for the Watt Trader on the way up and check by the rocks for treasure sparkles."},
    {@"Hammerlocke Hills", @"Follow the city wall to Hammerlocke’s entrance. You need the Fire Badge to enter the city. The Watt Trader and ingredient seller stand near the gate."},
    {@"Giant’s Cap", @"Follow the hill along the east bank of the Lake of Outrage. Check the southern slope above the Dusty Bowl for the Dawn Stone."},
    {@"Lake of Outrage", @"Use Water Mode to cross from Giant’s Cap. Check the circle of standing stones on the bluff for recurring Evolution stones, and the northern shelf for TM65."},
};

+ (BOOL)hasWildEncountersInArea:(DMGuideArea)area {
    return area == DMGuideAreaWildArea || area == DMGuideAreaNorthWild;
}

+ (NSArray<NSString *> *)wildSubareasInArea:(DMGuideArea)area {
    const ShieldWildSubarea *subareas = area == DMGuideAreaWildArea ? southWildSubareas : northWildSubareas;
    NSUInteger count = area == DMGuideAreaWildArea ? sizeof(southWildSubareas) / sizeof(*southWildSubareas) :
        area == DMGuideAreaNorthWild ? sizeof(northWildSubareas) / sizeof(*northWildSubareas) : 0;
    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger index = 0; index < count; index++) [names addObject:subareas[index].name];
    return names;
}

+ (NSArray<NSString *> *)wildWeatherNames {
    return @[@"Clear", @"Overcast", @"Rain", @"Thunderstorm", @"Intense Sun", @"Snow", @"Snowstorm", @"Sandstorm", @"Heavy Fog"];
}

+ (NSString *)wildWeatherHelp {
    return @"Choose the weather you see in-game. Snowstorms and sandstorms unlock after visiting Hammerlocke, and heavy fog after becoming Champion. Levels shown are the base values.";
}

static NSInteger wildSubareaIndex(DMGuideArea area, NSInteger subarea) {
    if (subarea < 0 || (NSUInteger)subarea >= [DMShieldGuide wildSubareasInArea:area].count) return -1;
    return subarea + (area == DMGuideAreaNorthWild ? [DMShieldGuide wildSubareasInArea:DMGuideAreaWildArea].count : 0);
}

+ (NSString *)wildDirectionsInArea:(DMGuideArea)area subarea:(NSInteger)subarea {
    if (wildSubareaIndex(area, subarea) < 0) return @"";
    const ShieldWildSubarea *subareas = area == DMGuideAreaWildArea ? southWildSubareas : northWildSubareas;
    return subareas[subarea].directions;
}

static NSArray<NSString *> *wildMethodNames(void) {
    return @[@"Visible on land", @"Random in grass", @"Ground encounters", @"Flying encounters",
        @"Water surface · water bike required", @"Strong wanderers",
        @"Strong wanderers · after becoming Champion", @"Berry trees", @"Fishing"];
}

+ (NSArray<NSString *> *)wildEncountersInArea:(DMGuideArea)area subarea:(NSInteger)subarea weather:(NSInteger)weather {
    return [self wildEncountersInArea:area subarea:subarea weather:weather matchingSpecies:nil];
}

+ (NSArray<NSString *> *)wildEncountersInArea:(DMGuideArea)area subarea:(NSInteger)subarea weather:(NSInteger)weather
    matchingSpecies:(NSSet<NSString *> *)species {
    NSInteger index = wildSubareaIndex(area, subarea);
    if (index < 0 || weather < 0 || (NSUInteger)weather >= self.wildWeatherNames.count) return @[];
    NSArray<NSString *> *labels = wildMethodNames();
    NSMutableArray<NSString *> *sections = [NSMutableArray array];
    int weatherBit = 1 << weather;
    for (NSUInteger method = 0; method < WildMethodCount; method++) {
        NSMutableOrderedSet<NSString *> *entries = [NSMutableOrderedSet orderedSet];
        for (NSUInteger i = 0; i < sizeof(wildSlots) / sizeof(wildSlots[0]); i++) {
            if (wildSlots[i].subarea != index || wildSlots[i].method != method) continue;
            if (method < WildTree && !(wildSlots[i].weather & weatherBit)) continue;
            NSString *name = @(wildSlots[i].name);
            if (!encounterMatchesSpecies(name, species)) continue;
            unsigned low = wildSlots[i].minLevel, high = wildSlots[i].maxLevel;
            NSString *level = low == high ? [NSString stringWithFormat:@"Lv. %u", low] :
                [NSString stringWithFormat:@"Lv. %u–%u", low, high];
            [entries addObject:[NSString stringWithFormat:@"%@ (%@)", name, level]];
        }
        if (entries.count)
            [sections addObject:[NSString stringWithFormat:@"%@\n%@", labels[method], [entries.array componentsJoinedByString:@", "]]];
    }
    return sections;
}

static NSArray<NSString *> *allWildSubareas(void) {
    return [[DMShieldGuide wildSubareasInArea:DMGuideAreaWildArea]
        arrayByAddingObjectsFromArray:[DMShieldGuide wildSubareasInArea:DMGuideAreaNorthWild]];
}

static NSArray<NSString *> *wildLocationsForSpecies(NSSet<NSString *> *species) {
    NSArray<NSString *> *subareas = allWildSubareas();
    NSArray<NSString *> *methods = wildMethodNames();
    NSArray<NSString *> *weatherNames = DMShieldGuide.wildWeatherNames;
    uint16_t allWeather = (1u << weatherNames.count) - 1;
    NSMutableArray<NSString *> *sections = [NSMutableArray array];
    for (NSUInteger subarea = 0; subarea < subareas.count; subarea++) {
        NSMutableArray<NSString *> *rows = [NSMutableArray array];
        for (NSUInteger method = 0; method < WildMethodCount; method++) {
            NSMutableDictionary<NSString *, NSNumber *> *weatherByForm = [NSMutableDictionary dictionary];
            for (NSUInteger i = 0; i < sizeof(wildSlots) / sizeof(wildSlots[0]); i++) {
                if (wildSlots[i].subarea != subarea || wildSlots[i].method != method) continue;
                NSString *name = @(wildSlots[i].name);
                if (!encounterMatchesSpecies(name, species)) continue;
                uint16_t mask = method >= WildTree ? allWeather : wildSlots[i].weather;
                weatherByForm[name] = @(weatherByForm[name].unsignedIntValue | mask);
            }
            for (NSString *name in [weatherByForm.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
                uint16_t mask = weatherByForm[name].unsignedIntValue;
                NSMutableArray<NSString *> *weathers = [NSMutableArray array];
                for (NSUInteger i = 0; i < weatherNames.count; i++)
                    if (mask & (1u << i)) [weathers addObject:weatherNames[i]];
                NSString *weather = mask == allWeather ? @"Any weather" : [weathers componentsJoinedByString:@", "];
                [rows addObject:[NSString stringWithFormat:@"%@ · %@ · %@", methods[method], name, weather]];
            }
        }
        if (rows.count)
            [sections addObject:[NSString stringWithFormat:@"%@\n%@", subareas[subarea], [rows componentsJoinedByString:@"\n"]]];
    }
    return sections;
}

static NSArray<NSString *> *raidLocationsForSpecies(NSSet<NSString *> *species, BOOL gigantamaxOnly) {
    uint8_t poolRanks[256] = {0}; // Pool IDs are stored as uint8_t.
    for (NSUInteger i = 0; i < sizeof(raidSlots) / sizeof(raidSlots[0]); i++) {
        NSString *name = @(raidSlots[i].name);
        if (gigantamaxOnly && ![name hasSuffix:@" (Gigantamax)"]) continue;
        if (!encounterMatchesSpecies(name, species)) continue;
        for (NSUInteger rank = 0; rank < 5; rank++)
            if (raidSlots[i].chance[rank]) poolRanks[raidSlots[i].pool] |= 1u << rank;
    }
    NSArray<NSString *> *subareas = allWildSubareas();
    NSMutableArray<NSString *> *sections = [NSMutableArray array];
    for (NSUInteger subarea = 0; subarea < subareas.count; subarea++) {
        NSMutableArray<NSString *> *rows = [NSMutableArray array];
        for (NSUInteger i = 0; i < sizeof(raidDens) / sizeof(raidDens[0]); i++) {
            const RaidDen *den = &raidDens[i];
            if (den->subarea != subarea) continue;
            for (NSUInteger rare = 0; rare < 2; rare++) {
                uint8_t mask = poolRanks[den->pool[rare]];
                if (!mask) continue;
                NSMutableArray<NSString *> *ranks = [NSMutableArray array];
                for (NSUInteger rank = 0; rank < 5; rank++)
                    if (mask & (1u << rank)) [ranks addObject:[NSString stringWithFormat:@"%lu★", rank + 1]];
                [rows addObject:[NSString stringWithFormat:@"Den %u · %@ beam · %@", den->number,
                    rare ? @"Purple" : @"Red", [ranks componentsJoinedByString:@", "]]];
            }
        }
        if (rows.count)
            [sections addObject:[NSString stringWithFormat:@"%@\n%@", subareas[subarea], [rows componentsJoinedByString:@"\n"]]];
    }
    return sections;
}

+ (NSArray<NSString *> *)gigantamaxRaidLocationsForSpecies:(NSString *)species {
    return raidLocationsForSpecies([NSSet setWithObject:species], YES);
}

+ (NSArray<NSNumber *> *)raidDensInArea:(DMGuideArea)area subarea:(NSInteger)subarea {
    NSInteger index = wildSubareaIndex(area, subarea);
    NSMutableArray<NSNumber *> *dens = [NSMutableArray array];
    for (NSUInteger i = 0; i < sizeof(raidDens) / sizeof(raidDens[0]); i++) {
        if (raidDens[i].subarea == index) [dens addObject:@(raidDens[i].number)];
    }
    return dens;
}

+ (DMGuideRaidMap *)raidMapInArea:(DMGuideArea)area subarea:(NSInteger)subarea {
    NSInteger index = wildSubareaIndex(area, subarea);
    if (index < 0) return nil;
    CGRect bounds = CGRectNull;
    for (NSUInteger i = 0; i < sizeof(raidDens) / sizeof(raidDens[0]); i++) {
        const RaidDen *den = &raidDens[i];
        if (den->subarea == index)
            bounds = CGRectUnion(bounds, CGRectMake(den->x, den->y, 1, 1));
    }
    if (CGRectIsNull(bounds)) return nil;
    CGFloat width = MAX(bounds.size.width + 88, 212);
    CGFloat height = MAX(bounds.size.height + 68, 160);
    CGRect viewport = CGRectMake(CGRectGetMidX(bounds) - width / 2, CGRectGetMidY(bounds) - height / 2, width, height);
    NSMutableArray<DMGuideRaidMapMarker *> *markers = [NSMutableArray array];
    for (NSUInteger i = 0; i < sizeof(raidDens) / sizeof(raidDens[0]); i++) {
        const RaidDen *den = &raidDens[i];
        if (den->subarea != index) continue;
        CGPoint position = CGPointMake((den->x - viewport.origin.x) / width, (den->y - viewport.origin.y) / height);
        [markers addObject:[[DMGuideRaidMapMarker alloc] initWithDen:den->number position:position]];
    }
    return [[DMGuideRaidMap alloc] initWithMarkers:markers viewport:viewport north:area == DMGuideAreaNorthWild];
}

+ (NSArray<NSString *> *)raidEncountersInArea:(DMGuideArea)area subarea:(NSInteger)subarea
    den:(NSInteger)den rare:(BOOL)rare stars:(NSInteger)stars {
    return [self raidEncountersInArea:area subarea:subarea den:den rare:rare stars:stars matchingSpecies:nil];
}

+ (NSArray<NSString *> *)raidEncountersInArea:(DMGuideArea)area subarea:(NSInteger)subarea
    den:(NSInteger)den rare:(BOOL)rare stars:(NSInteger)stars matchingSpecies:(NSSet<NSString *> *)species {
    NSInteger index = wildSubareaIndex(area, subarea);
    if (index < 0 || stars < 1 || stars > 5) return @[];
    for (NSUInteger i = 0; i < sizeof(raidDens) / sizeof(raidDens[0]); i++) {
        if (raidDens[i].subarea != index || raidDens[i].number != den) continue;
        uint8_t pool = raidDens[i].pool[rare ? 1 : 0];
        NSMutableArray<NSString *> *matches = [NSMutableArray array];
        for (NSUInteger slot = 0; slot < sizeof(raidSlots) / sizeof(raidSlots[0]); slot++) {
            unsigned chance = raidSlots[slot].chance[stars - 1];
            if (raidSlots[slot].pool != pool || !chance) continue;
            NSString *name = @(raidSlots[slot].name);
            if (encounterMatchesSpecies(name, species))
                [matches addObject:[NSString stringWithFormat:@"%@ · %u%%", name, chance]];
        }
        return matches;
    }
    return @[];
}
