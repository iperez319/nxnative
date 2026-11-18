// Shield encounter reference. Printed page ranges refer to the Official Galar
// Region Strategy Guide. Groups retain method and subarea without OCR rarity marks.
static NSArray<NSArray<NSString *> *> *routeEncounterGroups(DMGuideArea area) {
    switch (area) {
        case DMGuideAreaRoute1: // p. 39
            return @[
                @[@"Visible in grass ·", @"Rookidee", @"Skwovet", @"Nickit", @"Wooloo"],
                @[@"Random in grass ·", @"Blipbug", @"Caterpie", @"Grubbin", @"Hoothoot", @"Skwovet"]
            ];
        case DMGuideAreaRoute2: // pp. 42–43
            return @[
                @[@"Visible in grass ·", @"Rookidee", @"Skwovet", @"Nickit", @"Galarian Zigzagoon", @"Chewtle", @"Yamper"],
                @[@"Random in grass ·", @"Blipbug", @"Hoothoot", @"Rookidee", @"Lotad", @"Purrloin"],
                @[@"Wandering ·", @"Chewtle", @"Yamper"],
                @[@"Fishing on the near shore ·", @"Chewtle", @"Magikarp", @"Arrokuda"],
                @[@"Far shore, water bike required · Visible in grass:", @"Blipbug", @"Nickit", @"Galarian Zigzagoon", @"Yamper"],
                @[@"Far shore, water bike required · Random in grass:", @"Blipbug", @"Lotad", @"Chewtle", @"Purrloin", @"Gossifleur"],
                @[@"Far shore, water bike required · Wandering:", @"Obstagoon", @"Drednaw"],
                @[@"Far shore, water bike required · Fishing:", @"Chewtle", @"Magikarp", @"Feebas"],
                @[@"Water surface, water bike required ·", @"Gyarados", @"Arrokuda", @"Barraskewda", @"Lapras"]
            ];
        case DMGuideAreaMotostoke: // pp. 50–51
            return @[@[@"Fishing ·", @"Chewtle", @"Magikarp", @"Barboach"]];
        case DMGuideAreaRoute3: // pp. 56–57
            return @[
                @[@"Visible in grass ·", @"Galarian Zigzagoon", @"Growlithe", @"Tyrogue", @"Gossifleur", @"Stunky", @"Trubbish"],
                @[@"West, visible in grass ·", @"Trubbish", @"Rolycoly"],
                @[@"Random in grass ·", @"Rookidee", @"Mudbray", @"Pancham", @"Klink", @"Machop", @"Sizzlipede"],
                @[@"Wandering ·", @"Corvisquire"],
                @[@"Berry trees ·", @"Skwovet", @"Cherubi"]
            ];
        case DMGuideAreaGalarMine: // p. 58
            return @[
                @[@"Visible on the ground ·", @"Rolycoly", @"Diglett", @"Drilbur", @"Roggenrola", @"Timburr", @"Woobat"],
                @[@"Wandering ·", @"Carkol", @"Woobat"]
            ];
        case DMGuideAreaRoute4: // pp. 60–61
            return @[
                @[@"Visible in grass ·", @"Yamper", @"Electrike", @"Galarian Meowth", @"Pumpkaboo (all four sizes)", @"Pikachu", @"Eevee"],
                @[@"Random in grass ·", @"Wooloo", @"Budew", @"Joltik", @"Galarian Meowth", @"Milcery", @"Cutiefly", @"Ferroseed"],
                @[@"Wandering ·", @"Diglett"],
                @[@"Berry trees ·", @"Skwovet"],
                @[@"Fishing ·", @"Chewtle", @"Magikarp", @"Goldeen"]
            ];
        case DMGuideAreaRoute5: // pp. 66–67
            return @[
                @[@"Visible in grass ·", @"Minccino", @"Stufful", @"Drifloon", @"Spritzee", @"Wobbuffet"],
                @[@"Random in grass ·", @"Dottler", @"Lombre", @"Nincada", @"Applin", @"Espurr", @"Spritzee", @"Dewpider"],
                @[@"Wandering ·", @"Eldegoss"],
                @[@"Berry trees ·", @"Skwovet"],
                @[@"Fishing ·", @"Chewtle", @"Magikarp", @"Goldeen"]
            ];
        case DMGuideAreaHulbury: // p. 69
            return @[@[@"Fishing ·", @"Chewtle", @"Basculin (Blue-Striped Form)", @"Wishiwashi", @"Arrokuda", @"Chinchou"]];
        case DMGuideAreaMine2: // p. 73
            return @[
                @[@"Visible on the ground ·", @"Chewtle", @"Noibat", @"Croagunk", @"Shuckle", @"Shellos (East Sea)", @"Wimpod", @"Binacle"],
                @[@"Water surface, water bike required ·", @"Gastrodon (East Sea)"],
                @[@"Wandering ·", @"Drednaw", @"Galarian Stunfisk"],
                @[@"Fishing ·", @"Chewtle", @"Corphish", @"Barboach"]
            ];
        case DMGuideAreaOutskirts: // p. 75
            return @[
                @[@"Visible in grass ·", @"Noctowl", @"Hatenna", @"Salandit", @"Throh", @"Koffing", @"Sudowoodo"],
                @[@"Random in grass ·", @"Chewtle", @"Roggenrola", @"Croagunk", @"Impidimp", @"Pawniard"]
            ];
        case DMGuideAreaRoute6: // pp. 85–86
            return @[
                @[@"Visible in grass ·", @"Dugtrio", @"Maractus", @"Helioptile", @"Trapinch", @"Axew", @"Galarian Yamask"],
                @[@"Random in grass ·", @"Heatmor", @"Hawlucha", @"Duskull", @"Skorupi", @"Torkoal", @"Silicobra", @"Hippopotas", @"Durant"],
                @[@"Fishing ·", @"Drednaw", @"Magikarp", @"Goldeen"],
                @[@"Berry trees ·", @"Greedent"]
            ];
        case DMGuideAreaGlimwood: // pp. 95–96
            return @[
                @[@"Random encounters ·", @"Spritzee", @"Morgrem", @"Hattrem", @"Galarian Ponyta", @"Sinistea (Phony and Antique forms)", @"Indeedee (Female)", @"Phantump", @"Shiinotic", @"Oranguru"],
                @[@"Wandering ·", @"Impidimp", @"Morgrem"]
            ];
        case DMGuideAreaRoute7: // p. 101
            return @[
                @[@"Visible in grass ·", @"Thievul", @"Liepard", @"Galvantula", @"Perrserker", @"Inkay", @"Morpeko"],
                @[@"Random in grass ·", @"Corviknight", @"Liepard", @"Seismitoad", @"Meowstic (Female)", @"Karrablast", @"Shelmet", @"Toxel"],
                @[@"Berry trees ·", @"Greedent"]
            ];
        case DMGuideAreaRoute8: // pp. 103–105
            return @[
                @[@"Ruins, visible in grass ·", @"Golett", @"Boldore", @"Gurdurr", @"Pawniard", @"Vullaby", @"Togedemaru", @"Lunatone"],
                @[@"Ruins, random in grass ·", @"Bronzong", @"Dusclops", @"Haunter", @"Rhyhorn", @"Drapion", @"Sandaconda", @"Hippowdon", @"Falinks"],
                @[@"Ruins, wandering ·", @"Crustle", @"Falinks"],
                @[@"Steamdrift Way, visible in grass ·", @"Vanillish", @"Snorunt", @"Throh", @"Sneasel", @"Snom"],
                @[@"Steamdrift Way, random in grass ·", @"Delibird", @"Snover", @"Sneasel", @"Snom"]
            ];
        case DMGuideAreaRoute9: // pp. 112–115
            return @[
                @[@"North, visible in grass ·", @"Pelipper", @"Pyukumuku", @"Gastrodon (East Sea)", @"Jellicent", @"Mareanie"],
                @[@"North, random in grass ·", @"Kingler", @"Octillery", @"Cramorant", @"Pincurchin"],
                @[@"North, water surface ·", @"Pelipper", @"Qwilfish", @"Jellicent", @"Mantyke"],
                @[@"North, wandering ·", @"Glalie"],
                @[@"North, fishing ·", @"Octillery", @"Wishiwashi", @"Pyukumuku"],
                @[@"Circhester Bay, visible in grass ·", @"Octillery", @"Barbaracle", @"Toxapex", @"Clobbopus", @"Bergmite", @"Dhelmise"],
                @[@"Circhester Bay, random in grass ·", @"Gastrodon (East Sea)", @"Inkay", @"Cramorant", @"Pincurchin"],
                @[@"Circhester Bay, water surface ·", @"Remoraid", @"Grapploct", @"Mantyke", @"Mantine", @"Wailmer"],
                @[@"Circhester Bay, fishing ·", @"Mantyke", @"Mantine", @"Wailmer", @"Wailord", @"Lapras"],
                @[@"Outer Spikemuth, visible in grass ·", @"Jellicent", @"Mareanie", @"Toxapex", @"Clobbopus", @"Bergmite", @"Dhelmise"],
                @[@"Outer Spikemuth, random in grass ·", @"Thievul", @"Liepard", @"Perrserker", @"Morpeko"],
                @[@"Circhester Bay and Outer Spikemuth, Berry trees ·", @"Greedent"]
            ];
        case DMGuideAreaRoute10: // pp. 122–123
            return @[
                @[@"South, visible in grass ·", @"Vanilluxe", @"Glalie", @"Snover", @"Cubchoo", @"Galarian Mr. Mime"],
                @[@"South, random in grass ·", @"Vanillish", @"Klang", @"Rhydon", @"Snom"],
                @[@"North, visible in grass ·", @"Snover", @"Cubchoo", @"Sneasel", @"Galarian Mr. Mime", @"Duraludon"],
                @[@"North, random in grass ·", @"Vanillish", @"Abomasnow", @"Beartic", @"Snom", @"Eiscue"],
                @[@"North, wandering ·", @"Abomasnow", @"Beartic"]
            ];
        case DMGuideAreaWeald: // pp. 140–141
            return @[
                @[@"Free exploration on a later visit"],
                @[@"Visible in grass ·", @"Blipbug", @"Grubbin", @"Rookidee", @"Skwovet"],
                @[@"Random in grass ·", @"Blipbug", @"Grubbin", @"Hoothoot", @"Rookidee", @"Skwovet"],
                @[@"West, visible in grass ·", @"Orbeetle", @"Corviknight", @"Munna", @"Galarian Weezing"],
                @[@"West, random in grass ·", @"Orbeetle", @"Butterfree", @"Corviknight", @"Munna", @"Galarian Stunfisk", @"Galarian Weezing"],
                @[@"On the ground ·", @"Galarian Stunfisk"],
                @[@"West, fishing ·", @"Magikarp", @"Barboach", @"Whiscash"]
            ];
        default: return @[];
    }
}

+ (NSArray<NSString *> *)encounterGroupsInArea:(DMGuideArea)area {
    return [self encounterGroupsInArea:area matchingSpecies:nil];
}

+ (NSArray<NSString *> *)encounterGroupsInArea:(DMGuideArea)area matchingSpecies:(NSSet<NSString *> *)species {
    NSMutableArray<NSString *> *sections = [NSMutableArray array];
    BOOL hasMatches = NO;
    for (NSArray<NSString *> *group in routeEncounterGroups(area)) {
        if (group.count == 1) {
            [sections addObject:group[0]];
            continue;
        }
        NSMutableArray<NSString *> *matches = [NSMutableArray array];
        for (NSUInteger i = 1; i < group.count; i++)
            if (encounterMatchesSpecies(group[i], species)) [matches addObject:group[i]];
        if (!matches.count) continue;
        hasMatches = YES;
        [sections addObject:[NSString stringWithFormat:@"%@ %@", group[0], [matches componentsJoinedByString:@", "]]];
    }
    return hasMatches ? sections : @[];
}
