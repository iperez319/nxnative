// Schematic terrain in the same north-up coordinate space as the den index.
// Major shorelines, ridges and crossings are generalized from the guide maps.
static const CGPoint southLand[] = {
    {-18, 621}, {52, 621}, {112, 601}, {216, 601}, {260, 609}, {305, 603},
    {467, 615}, {470, 948}, {431, 1000}, {377, 1021}, {300, 1011}, {254, 1060},
    {135, 1060}, {105, 1026}, {25, 1022}, {-17, 967}
};
static const CGPoint northLand[] = {
    {108, 54}, {157, 20}, {223, 12}, {353, 8}, {394, 44}, {453, 64}, {467, 153},
    {427, 200}, {406, 270}, {389, 341}, {407, 395}, {371, 431}, {354, 485},
    {426, 523}, {436, 592}, {393, 612}, {322, 607}, {302, 550}, {320, 457},
    {271, 450}, {192, 397}, {177, 344}, {176, 264}, {129, 212}, {121, 157},
    {82, 121}, {86, 82}
};
static const CGPoint axewell[] = {
    {60, 817}, {69, 769}, {90, 732}, {121, 729}, {141, 766}, {159, 752},
    {182, 714}, {208, 694}, {241, 708}, {253, 743}, {265, 798}, {278, 844},
    {268, 878}, {239, 889}, {214, 860}, {184, 841}, {154, 823}, {137, 827},
    {146, 856}, {122, 881}, {88, 882}, {56, 861}
};
static const CGPoint axewsEye[] = {
    {191, 781}, {206, 773}, {220, 787}, {224, 812}, {211, 826}, {190, 810}
};
static const CGPoint miloch[] = {
    {279, 703}, {320, 692}, {355, 698}, {409, 728}, {409, 760}, {397, 801},
    {386, 844}, {395, 883}, {408, 913}, {404, 946}, {377, 953}, {347, 936},
    {326, 891}, {316, 849}, {324, 820}, {346, 825}, {366, 872}, {375, 845},
    {393, 794}, {385, 769}, {369, 756}, {339, 763}, {305, 750}, {282, 727}
};
static const CGPoint outrage[] = {{126, 140}, {104, 115}, {119, 90}, {142, 83}, {149, 61},
    {166, 50}, {172, 69}, {163, 101}, {148, 139}, {137, 166}};
static const CGPoint dustPond[] = {{208, 148}, {218, 130}, {234, 130}, {231, 147}, {222, 160}, {211, 160}};
static const CGPoint mirrorPond[] = {{390, 170}, {406, 163}, {416, 176}, {406, 196}, {392, 192}};
static const CGPoint bridgePond[] = {{295, 397}, {314, 386}, {325, 392}, {311, 411}, {308, 434}, {291, 431}, {285, 414}};
static const CGPoint riverbank[] = {{169, 469}, {236, 468}, {293, 462}, {331, 462},
    {353, 471}, {382, 469}, {396, 474}, {373, 482}, {337, 479}, {292, 478}, {245, 487}, {178, 486}};
static const CGPoint bowl[] = {{196, 116}, {246, 104}, {316, 113}, {377, 126},
    {375, 174}, {358, 223}, {336, 266}, {286, 264}, {244, 265}, {206, 259}, {191, 201}};
static const CGPoint southTrail[] = {{225, 1038}, {222, 991}, {253, 952}, {277, 907},
    {296, 842}, {286, 791}, {269, 737}, {252, 691}, {221, 674}, {221, 625}};
static const CGPoint northTrail[] = {{352, 583}, {347, 546}, {325, 515}, {335, 469},
    {340, 438}, {326, 398}, {305, 364}, {302, 320}, {295, 281}, {267, 232},
    {250, 181}, {242, 132}, {246, 92}, {273, 58}, {278, 34}};

typedef struct {
    CGPoint point;
    const char *name;
} RaidMapLandmark;

static const RaidMapLandmark southLandmarks[] = {
    {{223, 625}, "Motostoke"}, {{342, 625}, "To North Wild Area"},
    {{206, 1020}, "Meetup Spot"}, {{105, 794}, "West Lake Axewell"},
    {{215, 735}, "East Lake Axewell"}, {{206, 801}, "Axew’s Eye"},
    {{371, 734}, "North Lake Miloch"}, {{352, 880}, "South Lake Miloch"},
    {{73, 692}, "Watchtower Ruins"}
};
static const RaidMapLandmark northLandmarks[] = {
    {{278, 27}, "Hammerlocke"}, {{131, 112}, "Lake of Outrage"},
    {{226, 178}, "Dusty Bowl"}, {{385, 340}, "Pokémon Nursery"},
    {{260, 304}, "Railway viaduct"}, {{351, 578}, "To South Wild Area"}
};

@interface DMGuideRaidMapMarker ()
- (instancetype)initWithDen:(NSInteger)den position:(CGPoint)position;
@end

@implementation DMGuideRaidMapMarker
- (instancetype)initWithDen:(NSInteger)den position:(CGPoint)position {
    if ((self = [super init])) {
        _den = den;
        _position = position;
    }
    return self;
}
@end

@interface DMGuideRaidMap ()
- (instancetype)initWithMarkers:(NSArray<DMGuideRaidMapMarker *> *)markers viewport:(CGRect)viewport north:(BOOL)north;
@end

static void raidMapPath(CGContextRef context, const CGPoint *points, size_t count, BOOL closed) {
    CGContextBeginPath(context);
    CGContextAddLines(context, points, count);
    if (closed) CGContextClosePath(context);
}

#define RAID_MAP_FILL(points) do { \
    raidMapPath(context, points, sizeof(points) / sizeof(points[0]), YES); \
    CGContextFillPath(context); \
} while (0)

static CGPoint raidMapPin(CGPoint anchor, CGSize size, const CGRect *occupied, NSUInteger count) {
    CGPoint best = anchor;
    CGFloat distance = CGFLOAT_MAX;
    for (NSInteger y = -4; y <= 4; y++) {
        for (NSInteger x = -4; x <= 4; x++) {
            CGPoint candidate = CGPointMake(anchor.x + x * 12, anchor.y + y * 11);
            CGRect box = CGRectMake(candidate.x - 13, candidate.y - 12, 26, 24);
            CGFloat displacement = (x * 12) * (x * 12) + (y * 11) * (y * 11);
            if (displacement >= distance || !CGRectContainsRect((CGRect){CGPointZero, size}, box)) continue;
            BOOL overlaps = NO;
            for (NSUInteger i = 0; i < count; i++) {
                if (CGRectIntersectsRect(occupied[i], box)) {
                    overlaps = YES;
                    break;
                }
            }
            if (!overlaps) {
                best = candidate;
                distance = displacement;
            }
        }
    }
    return best;
}

@implementation DMGuideRaidMap {
    CGRect _viewport;
    BOOL _north;
}

- (instancetype)initWithMarkers:(NSArray<DMGuideRaidMapMarker *> *)markers viewport:(CGRect)viewport north:(BOOL)north {
    if ((self = [super init])) {
        _markers = [markers copy];
        _aspectRatio = viewport.size.width / viewport.size.height;
        _viewport = viewport;
        _north = north;
    }
    return self;
}

- (NSArray<DMGuideRaidMapMarker *> *)markersLaidOutInSize:(CGSize)size {
    NSMutableArray<DMGuideRaidMapMarker *> *pins = [NSMutableArray arrayWithCapacity:_markers.count];
    CGRect occupied[_markers.count];
    for (DMGuideRaidMapMarker *marker in _markers) {
        CGPoint anchor = CGPointMake(marker.position.x * size.width, marker.position.y * size.height);
        CGPoint point = raidMapPin(anchor, size, occupied, pins.count);
        occupied[pins.count] = CGRectMake(point.x - 13, point.y - 12, 26, 24);
        [pins addObject:[[DMGuideRaidMapMarker alloc] initWithDen:marker.den position:point]];
    }
    return pins;
}

- (void)drawInContext:(CGContextRef)context size:(CGSize)size {
    CGContextSaveGState(context);
    CGContextSetRGBFillColor(context, .13, .22, .19, 1);
    CGContextFillRect(context, (CGRect){CGPointZero, size});
    CGContextClipToRect(context, (CGRect){CGPointZero, size});
    CGContextScaleCTM(context, size.width / _viewport.size.width, size.height / _viewport.size.height);
    CGContextTranslateCTM(context, -_viewport.origin.x, -_viewport.origin.y);

    CGContextSetRGBFillColor(context, .26, .41, .31, 1);
    if (_north) RAID_MAP_FILL(northLand);
    else RAID_MAP_FILL(southLand);
    if (_north) {
        CGContextSetRGBFillColor(context, .46, .38, .24, 1);
        RAID_MAP_FILL(bowl);
    }
    CGContextSetRGBFillColor(context, .15, .33, .43, 1);
    if (_north) {
        RAID_MAP_FILL(outrage);
        RAID_MAP_FILL(dustPond);
        RAID_MAP_FILL(mirrorPond);
        RAID_MAP_FILL(bridgePond);
        RAID_MAP_FILL(riverbank);
    } else {
        RAID_MAP_FILL(axewell);
        RAID_MAP_FILL(miloch);
        CGContextSetRGBFillColor(context, .26, .41, .31, 1);
        RAID_MAP_FILL(axewsEye);
    }

    CGContextSetRGBStrokeColor(context, .80, .68, .48, .70);
    CGContextSetLineWidth(context, 2.0);
    CGFloat dash[] = {4, 3};
    CGContextSetLineDash(context, 0, dash, 2);
    if (_north) raidMapPath(context, northTrail, sizeof(northTrail) / sizeof(northTrail[0]), NO);
    else raidMapPath(context, southTrail, sizeof(southTrail) / sizeof(southTrail[0]), NO);
    CGContextStrokePath(context);

    const RaidMapLandmark *landmarks = _north ? northLandmarks : southLandmarks;
    size_t count = _north ? sizeof(northLandmarks) / sizeof(northLandmarks[0]) :
        sizeof(southLandmarks) / sizeof(southLandmarks[0]);
    CGRect interior = CGRectInset(_viewport, 8, 12);
    CTFontRef font = CTFontCreateUIFontForLanguage(kCTFontUIFontEmphasizedSystem, 9, NULL);
    NSDictionary *attributes = @{(__bridge NSString *)kCTFontAttributeName: (__bridge id)font,
                                 (__bridge NSString *)kCTForegroundColorFromContextAttributeName: @YES};
    CGContextSetRGBFillColor(context, .93, .96, .88, 1);
    for (size_t i = 0; i < count; i++) {
        CGPoint point = landmarks[i].point;
        if (!CGRectContainsPoint(interior, point)) continue;
        NSAttributedString *label = [[NSAttributedString alloc] initWithString:@(landmarks[i].name) attributes:attributes];
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)label);
        CGFloat width = (CGFloat)CTLineGetTypographicBounds(line, NULL, NULL, NULL);
        CGFloat left = MAX(CGRectGetMinX(interior), MIN(point.x - width / 2, CGRectGetMaxX(interior) - width));
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, left, point.y);
        CGContextScaleCTM(context, 1, -1);
        CGContextSetTextMatrix(context, CGAffineTransformIdentity);
        CGContextSetTextPosition(context, 0, 0);
        CTLineDraw(line, context);
        CGContextRestoreGState(context);
        CFRelease(line);
    }
    CFRelease(font);
    CGContextRestoreGState(context);

    CGContextSaveGState(context);
    CGContextSetRGBStrokeColor(context, 1, 1, 1, .85);
    CGContextSetRGBFillColor(context, 1, 1, 1, .85);
    CGContextSetLineWidth(context, 1);
    NSArray<DMGuideRaidMapMarker *> *pins = [self markersLaidOutInSize:size];
    for (NSUInteger i = 0; i < pins.count; i++) {
        CGPoint point = pins[i].position;
        CGPoint source = _markers[i].position;
        CGPoint anchor = CGPointMake(source.x * size.width, source.y * size.height);
        if (CGPointEqualToPoint(point, anchor)) continue;
        CGContextMoveToPoint(context, anchor.x, anchor.y);
        CGContextAddLineToPoint(context, point.x, point.y);
        CGContextStrokePath(context);
        CGContextFillEllipseInRect(context, CGRectMake(anchor.x - 2, anchor.y - 2, 4, 4));
    }
    CGContextRestoreGState(context);
}
@end

#undef RAID_MAP_FILL
