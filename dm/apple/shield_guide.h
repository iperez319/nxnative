#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdbool.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DMGuideArea) {
    DMGuideAreaUnknown = -1,
    DMGuideAreaWedgehurst = 0,
    DMGuideAreaRoute2,
    DMGuideAreaMotostoke,
    DMGuideAreaWildArea,
    DMGuideAreaRoute3,
    DMGuideAreaGalarMine,
    DMGuideAreaRoute4,
    DMGuideAreaTurffield,
    DMGuideAreaRoute5,
    DMGuideAreaHulbury,
    DMGuideAreaMine2,
    DMGuideAreaOutskirts,
    DMGuideAreaNorthWild,
    DMGuideAreaHammerlocke,
    DMGuideAreaRoute6,
    DMGuideAreaStow,
    DMGuideAreaGlimwood,
    DMGuideAreaBallonlea,
    DMGuideAreaRoute7,
    DMGuideAreaRoute8,
    DMGuideAreaCirchester,
    DMGuideAreaRoute9,
    DMGuideAreaSpikemuth,
    DMGuideAreaRoute10,
    DMGuideAreaWyndon,
    DMGuideAreaRoseTower,
    DMGuideAreaPostwick,
    DMGuideAreaRoute1,
    DMGuideAreaWeald,
    DMGuideAreaPowerPlant,
    DMGuideAreaBattleTower,
};

@interface DMGuideRaidMapMarker : NSObject
@property (nonatomic, readonly) NSInteger den;
@property (nonatomic, readonly) CGPoint position;
@end

// Marker anchors are normalized. Laid-out marker positions are in view points.
// Both use the upper left as the origin.
@interface DMGuideRaidMap : NSObject
@property (nonatomic, readonly) NSArray<DMGuideRaidMapMarker *> *markers;
@property (nonatomic, readonly) CGFloat aspectRatio;
- (NSArray<DMGuideRaidMapMarker *> *)markersLaidOutInSize:(CGSize)size
    NS_SWIFT_NAME(markersLaidOut(in:));
- (void)drawInContext:(CGContextRef)context size:(CGSize)size;
@end

@interface DMGuideEncounterLocations : NSObject
@property (nonatomic, readonly) NSArray<NSString *> *routes;
@property (nonatomic, readonly) NSArray<NSString *> *wildArea;
@property (nonatomic, readonly) NSArray<NSString *> *raids;
@property (nonatomic, readonly) NSArray<NSString *> *other;
@end

@interface DMGuideActivity : NSObject
@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *hint;
@property (nonatomic, readonly, nullable) NSString *waterModeHint;
@property (nonatomic, readonly) NSString *directions;
@property (nonatomic, readonly, getter=isDaily) BOOL daily;
@end

// Static handbook facts are available without a save and never imply completion.
@interface DMGuideReferenceEntry : NSObject
@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readonly) NSString *category;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *body;
@property (nonatomic, readonly) NSString *citation;
@end

@interface DMShieldReference : NSObject
@property (class, nonatomic, readonly) NSArray<NSString *> *categories;
@property (class, nonatomic, readonly) NSArray<DMGuideReferenceEntry *> *allEntries;
+ (NSArray<DMGuideReferenceEntry *> *)entriesInCategory:(NSString *)category query:(NSString *)query
    NS_SWIFT_NAME(entries(category:query:));
@end

@interface DMGuideSnapshot : NSObject
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) DMGuideArea area;
@property (nonatomic, readonly) NSInteger mainPhase;
@property (nonatomic, readonly) NSInteger guidance;
@property (nonatomic, readonly, nullable) NSString *objective;
@property (nonatomic, readonly) NSString *nextStep;
@property (nonatomic, readonly) NSArray<NSString *> *party;
@end

@interface DMShieldGuide : NSObject
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
@property (nonatomic) DMGuideArea selectedArea;
@property (class, nonatomic, readonly) NSArray<NSString *> *areaNames;
@property (class, nonatomic, readonly) NSArray<DMGuideSnapshot *> *previews;
+ (NSArray<DMGuideActivity *> *)activitiesInArea:(DMGuideArea)area;
+ (BOOL)hasUniformWardrobeInArea:(DMGuideArea)area NS_SWIFT_NAME(hasUniformWardrobe(in:));
+ (BOOL)hasAlcremieCollectionInArea:(DMGuideArea)area NS_SWIFT_NAME(hasAlcremieCollection(in:));
+ (NSString *)alcremieDirections;
+ (NSString *)directionsInArea:(DMGuideArea)area;
+ (NSArray<NSString *> *)encounterGroupsInArea:(DMGuideArea)area;
// A nil species set includes every slot. An empty set includes none. Names are base Pokédex species.
+ (NSArray<NSString *> *)encounterGroupsInArea:(DMGuideArea)area matchingSpecies:(nullable NSSet<NSString *> *)species;
+ (BOOL)hasWildEncountersInArea:(DMGuideArea)area;
+ (NSArray<NSString *> *)wildSubareasInArea:(DMGuideArea)area;
+ (NSString *)wildDirectionsInArea:(DMGuideArea)area subarea:(NSInteger)subarea NS_SWIFT_NAME(wildDirections(in:subarea:));
@property (class, nonatomic, readonly) NSArray<NSString *> *wildWeatherNames;
@property (class, nonatomic, readonly) NSString *wildWeatherHelp;
+ (NSArray<NSString *> *)wildEncountersInArea:(DMGuideArea)area subarea:(NSInteger)subarea weather:(NSInteger)weather;
+ (NSArray<NSString *> *)wildEncountersInArea:(DMGuideArea)area subarea:(NSInteger)subarea weather:(NSInteger)weather
    matchingSpecies:(nullable NSSet<NSString *> *)species;
+ (NSArray<NSNumber *> *)raidDensInArea:(DMGuideArea)area subarea:(NSInteger)subarea;
+ (NSArray<NSString *> *)gigantamaxRaidLocationsForSpecies:(NSString *)species;
+ (nullable DMGuideRaidMap *)raidMapInArea:(DMGuideArea)area subarea:(NSInteger)subarea;
+ (NSArray<NSString *> *)raidEncountersInArea:(DMGuideArea)area subarea:(NSInteger)subarea
    den:(NSInteger)den rare:(BOOL)rare stars:(NSInteger)stars;
+ (NSArray<NSString *> *)raidEncountersInArea:(DMGuideArea)area subarea:(NSInteger)subarea
    den:(NSInteger)den rare:(BOOL)rare stars:(NSInteger)stars matchingSpecies:(nullable NSSet<NSString *> *)species;
+ (DMGuideEncounterLocations *)encounterLocationsForSpecies:(NSString *)species
    NS_SWIFT_NAME(encounterLocations(forSpecies:));
- (BOOL)isChecked:(DMGuideActivity *)activity;
- (void)setChecked:(BOOL)checked forActivity:(DMGuideActivity *)activity;
@end

bool dm_shield_guide_available(void);
NSString * _Nullable DMGuideOpeningObjective(NSInteger token);
NSString * _Nullable DMGuideMotostokeEvidence(NSString *activityKey, NSNumber * _Nullable minccinoStage,
                                           NSNumber * _Nullable trade, NSNumber * _Nullable fountain);
NSString * _Nullable DMGuideHulburyDeliveryEvidence(NSString *activityKey, NSNumber * _Nullable stage);
BOOL DMGuideHulburyDeliveryComplete(NSString *activityKey, NSNumber * _Nullable stage);

NS_ASSUME_NONNULL_END
