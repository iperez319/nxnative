typedef struct { uint16_t x, z; } SparkleWorldPoint;
typedef struct { uint16_t index; SparkleWorldPoint point; } SparklePosition;
typedef struct { uint8_t subarea, number; SparkleWorldPoint point; } SparkleDenPosition;

#include "shield_guide_sparkle_positions.inc"

typedef NS_ENUM(uint8_t, SparkleState) {
    SparkleUnknown, SparkleNotCollected, SparkleAwaitingRespawn
};

@interface DMGuideSparkleSpot ()
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *saveStatus;
@property (nonatomic, readwrite) NSInteger nearestDen;
@property (nonatomic, copy, readwrite) NSString *denReference;
@property (nonatomic) CGPoint point;
@property (nonatomic) SparkleState state;
@end

@implementation DMGuideSparkleSpot
@end

@interface DMGuideSparkleMap ()
@property (nonatomic, copy, readwrite) NSArray<DMGuideSparkleSpot *> *spots;
@property (nonatomic) NSInteger subarea;
@end

static CGPoint sparklePoint(SparkleWorldPoint point) {
    return CGPointMake(point.x, point.z);
}

static NSString *sparkleDenReference(NSInteger den, CGFloat dx, CGFloat dz) {
    if (dx == 0 && dz == 0) return [NSString stringWithFormat:@"By den %ld", (long)den];
    NSArray<NSString *> *directions = @[@"East", @"Southeast", @"South", @"Southwest",
        @"West", @"Northwest", @"North", @"Northeast"];
    NSInteger sector = lround(atan2(dz, dx) * 4 / M_PI);
    return [NSString stringWithFormat:@"%@ of den %ld", directions[(sector + 8) % 8], (long)den];
}

static CGPoint mapPoint(CGPoint point, CGPoint center, CGFloat scale, CGSize size) {
    return CGPointMake(size.width / 2 + (point.x - center.x) * scale,
                       size.height / 2 + (point.y - center.y) * scale);
}

static void drawSparkleDot(CGContextRef context, CGPoint point, SparkleState state) {
    CGRect dot = CGRectMake(point.x - 3.5, point.y - 3.5, 7, 7);
    CGContextSetLineWidth(context, 1.5);
    if (state == SparkleAwaitingRespawn) {
        CGContextSetRGBStrokeColor(context, .46, .85, .72, 1);
        CGContextStrokeEllipseInRect(context, dot);
    } else {
        CGFloat brightness = state == SparkleUnknown ? .64 : .96;
        CGContextSetRGBFillColor(context, brightness, brightness, brightness, 1);
        CGContextFillEllipseInRect(context, dot);
    }
}

@implementation DMGuideSparkleMap
- (void)drawInContext:(CGContextRef)context size:(CGSize)size selectedIndex:(NSInteger)selection {
    CGContextSaveGState(context);
    CGContextSetRGBFillColor(context, .10, .16, .20, 1);
    CGContextFillRect(context, (CGRect){CGPointZero, size});
    CGContextClipToRect(context, (CGRect){CGPointZero, size});

    CGRect bounds = CGRectNull;
    for (DMGuideSparkleSpot *spot in self.spots)
        bounds = CGRectUnion(bounds, (CGRect){spot.point, {1, 1}});
    for (size_t i = 0; i < sizeof(sparkleDenPositions) / sizeof(sparkleDenPositions[0]); i++) {
        if (sparkleDenPositions[i].subarea == self.subarea)
            bounds = CGRectUnion(bounds, (CGRect){sparklePoint(sparkleDenPositions[i].point), {1, 1}});
    }
    CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    CGFloat scale = MAX(0, MIN((size.width - 46) / bounds.size.width, (size.height - 38) / bounds.size.height));

    CGContextSetRGBStrokeColor(context, .88, .95, 1, .13);
    CGContextSetLineWidth(context, 1);
    for (NSUInteger i = 1; i < 6; i++) {
        CGFloat x = size.width * i / 6, y = size.height * i / 6;
        CGContextMoveToPoint(context, x, 0);
        CGContextAddLineToPoint(context, x, size.height);
        CGContextMoveToPoint(context, 0, y);
        CGContextAddLineToPoint(context, size.width, y);
    }
    CGContextStrokePath(context);

    CTFontRef font = CTFontCreateUIFontForLanguage(kCTFontUIFontEmphasizedSystem, 11, NULL);
    NSDictionary *attributes = @{(__bridge NSString *)kCTFontAttributeName: (__bridge id)font,
                                 (__bridge NSString *)kCTForegroundColorFromContextAttributeName: @YES};
    CGContextSetRGBFillColor(context, .56, .75, .90, 1);
    for (size_t i = 0; i < sizeof(sparkleDenPositions) / sizeof(sparkleDenPositions[0]); i++) {
        const SparkleDenPosition *den = &sparkleDenPositions[i];
        if (den->subarea != self.subarea) continue;
        CGPoint point = mapPoint(sparklePoint(den->point), center, scale, size);
        CGContextFillRect(context, CGRectMake(point.x - 2, point.y - 2, 4, 4));
        NSString *label = [NSString stringWithFormat:@"D%u", den->number];
        NSAttributedString *text = [[NSAttributedString alloc] initWithString:label attributes:attributes];
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, point.x + 4, point.y - 3);
        CGContextScaleCTM(context, 1, -1);
        CGContextSetTextMatrix(context, CGAffineTransformIdentity);
        CGContextSetTextPosition(context, 0, 0);
        CTLineDraw(line, context);
        CGContextRestoreGState(context);
        CFRelease(line);
    }
    CFRelease(font);

    for (DMGuideSparkleSpot *spot in self.spots)
        drawSparkleDot(context, mapPoint(spot.point, center, scale, size), spot.state);
    if ((NSUInteger)selection < self.spots.count) {
        DMGuideSparkleSpot *selected = self.spots[selection];
        CGPoint point = mapPoint(selected.point, center, scale, size);
        CGContextSetRGBStrokeColor(context, 1, .79, .34, 1);
        CGContextSetLineWidth(context, 2);
        CGContextStrokeEllipseInRect(context, CGRectMake(point.x - 9, point.y - 9, 18, 18));
        drawSparkleDot(context, point, selected.state);
    }
    CGContextRestoreGState(context);
}
@end
