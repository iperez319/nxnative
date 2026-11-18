#pragma once
#import "shield_guide.h"

NS_ASSUME_NONNULL_BEGIN

// Called once after the host loads the executable, before the guest mounts its save.
void dm_shield_guide_configure(const char *build, int (*openCommittedMain)(void));
@interface DMGuideLiveLocation : NSObject
@property (nonatomic, readonly) DMGuideArea area;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) BOOL placementBased;
// Zero-based within the reported Wild Area half. Nil outside the listed subareas.
@property (nonatomic, readonly, nullable) NSNumber *wildSubarea;
+ (nullable instancetype)currentLocation NS_SWIFT_NAME(current());
@end

@interface DMGuideSparkleSpot : NSObject
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *saveStatus;
@property (nonatomic, readonly) NSInteger nearestDen;
@property (nonatomic, readonly) NSString *denReference;
@end

@interface DMGuideSparkleMap : NSObject
@property (nonatomic, readonly) NSArray<DMGuideSparkleSpot *> *spots;
- (void)drawInContext:(CGContextRef)context size:(CGSize)size selectedIndex:(NSInteger)selection;
@end

@interface DMGuideGalarDexEntry : NSObject
@property (nonatomic, readonly) NSInteger number;
@property (nonatomic, readonly) NSString *species;
@property (nonatomic, readonly) NSString *label;
@end

@interface DMGuideBoutiqueCategory : NSObject
@property (nonatomic, readonly) NSInteger identifier;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSArray<NSString *> *items;
@end

// A read-only observation. Unknown fields remain nil.
@interface DMGuideSavedContext : NSObject
@property (nonatomic, readonly, nullable) NSString *location;
@property (nonatomic, readonly) BOOL placementBasedLocation;
@property (nonatomic, readonly) DMGuideArea area;
@property (nonatomic, readonly, nullable) NSNumber *wildSubarea;
@property (nonatomic, readonly, nullable) NSNumber *mainPhase;
@property (nonatomic, readonly, nullable) NSNumber *guidance;
@property (nonatomic, readonly, nullable) NSString *objective;
@property (nonatomic, readonly, nullable) NSNumber *pokedexUnlocked;
@property (nonatomic, readonly, nullable) NSString *nextStep;
@property (nonatomic, readonly, nullable) NSNumber *cookedCurryCount;
@property (nonatomic, readonly, nullable) NSNumber *galarDexCaughtCount;
// Nil means the Galar block is unavailable. An empty set means the Pokédex is complete.
@property (nonatomic, readonly, nullable) NSSet<NSString *> *missingGalarSpecies;
- (NSArray<NSString *> *)battleTowerProgressForDoubles:(BOOL)doubles NS_SWIFT_NAME(battleTowerProgress(doubles:));
+ (NSString *)rotomFormsTitleWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(rotomFormsTitle(savedContext:));
+ (NSArray<NSString *> *)rotomFormRowsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(rotomFormRows(savedContext:));
+ (NSString *)gigantamaxTitleWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(gigantamaxTitle(savedContext:));
+ (NSArray<NSString *> *)gigantamaxRowsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(gigantamaxRows(savedContext:));
+ (nullable NSString *)cafePrizeTitleInArea:(DMGuideArea)area NS_SWIFT_NAME(cafePrizeTitle(in:));
+ (NSArray<NSString *> *)cafePrizeRowsInArea:(DMGuideArea)area savedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(cafePrizeRows(in:savedContext:));
+ (NSArray<NSString *> *)stowMarketRowsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(stowMarketRows(savedContext:));
+ (NSArray<NSString *> *)stowBargainStock;
+ (NSArray<NSString *> *)stowBuyerPrices;
+ (NSString *)teaEvolutionTitleWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(teaEvolutionTitle(savedContext:));
+ (NSArray<NSString *> *)teaEvolutionRowsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(teaEvolutionRows(savedContext:));
+ (NSString *)alcremieTitleWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(alcremieTitle(savedContext:));
+ (NSArray<NSString *> *)alcremieSweetTitlesWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(alcremieSweetTitles(savedContext:));
+ (NSArray<NSString *> *)alcremieRowsForSweet:(NSInteger)sweet savedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(alcremieRows(forSweet:savedContext:));
+ (NSString *)silvallyMemoryTitleWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(silvallyMemoryTitle(savedContext:));
+ (NSArray<NSString *> *)silvallyMemoryRowsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(silvallyMemoryRows(savedContext:));
+ (NSArray<NSString *> *)battleTowerRankRewardsForDoubles:(BOOL)doubles savedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(battleTowerRankRewards(doubles:savedContext:));
+ (NSArray<NSString *> *)battleTowerWinRewardsForDoubles:(BOOL)doubles repeating:(BOOL)repeating
    savedContext:(nullable DMGuideSavedContext *)saved NS_SWIFT_NAME(battleTowerWinRewards(doubles:repeating:savedContext:));
+ (NSString *)gymChallengeTitleWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(gymChallengeTitle(savedContext:));
+ (NSArray<NSString *> *)gymChallengeRowsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(gymChallengeRows(savedContext:));
+ (NSString *)leagueCardAlbumTitleWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(leagueCardAlbumTitle(savedContext:));
+ (NSArray<NSString *> *)leagueCardAlbumRowsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(leagueCardAlbumRows(savedContext:));
+ (NSArray<NSString *> *)cardMakerRowsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(cardMakerRows(savedContext:));
+ (NSString *)uniformWardrobeTitleWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(uniformWardrobeTitle(savedContext:));
+ (NSArray<NSString *> *)uniformWardrobeRowsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(uniformWardrobeRows(savedContext:));
+ (nullable NSString *)boutiqueTitleInArea:(DMGuideArea)area savedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(boutiqueTitle(in:savedContext:));
+ (NSArray<DMGuideBoutiqueCategory *> *)boutiqueCategoriesInArea:(DMGuideArea)area
    savedContext:(nullable DMGuideSavedContext *)saved NS_SWIFT_NAME(boutiqueCategories(in:savedContext:));
// Pass DMGuideAreaUnknown for the complete TM case. A nil save gives source details alone.
+ (nullable NSString *)tmTitleInArea:(DMGuideArea)area savedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(tmTitle(in:savedContext:));
+ (NSArray<NSString *> *)tmRowsInArea:(DMGuideArea)area savedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(tmRows(in:savedContext:));
+ (NSString *)trTitleWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(trTitle(savedContext:));
+ (nullable NSString *)trSourcesInArea:(DMGuideArea)area NS_SWIFT_NAME(trSources(in:));
+ (NSArray<NSString *> *)trRowsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(trRows(savedContext:));
+ (NSString *)postgameStadiumTitleWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(postgameStadiumTitle(savedContext:));
+ (NSArray<NSString *> *)postgameStadiumRowsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(postgameStadiumRows(savedContext:));
- (nullable NSString *)activityEvidenceForKey:(NSString *)key;
- (NSString *)hintForActivity:(DMGuideActivity *)activity NS_SWIFT_NAME(hint(for:));
// The completion label is derived from this snapshot and is never persisted as a player checkoff.
- (nullable NSString *)activityCompletionForKey:(NSString *)key;
// A summary and reward groups. Pass nil to browse without save status.
+ (NSArray<NSString *> *)wildSparklesInArea:(DMGuideArea)area subarea:(NSInteger)subarea
    savedContext:(nullable DMGuideSavedContext *)saved;
+ (nullable DMGuideSparkleMap *)wildSparkleMapInArea:(DMGuideArea)area subarea:(NSInteger)subarea
    savedContext:(nullable DMGuideSavedContext *)saved;
@property (class, nonatomic, readonly) NSArray<NSString *> *curryRecipeGroups;
+ (nullable NSString *)curryIngredientInGroup:(NSInteger)group NS_SWIFT_NAME(curryIngredient(inGroup:));
+ (NSArray<NSString *> *)curryRecipesInGroup:(NSInteger)group savedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(curryRecipes(inGroup:savedContext:));
+ (NSArray<NSString *> *)campingRewardsWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(campingRewards(savedContext:));
+ (NSArray<NSString *> *)galarDexRangesWithSavedContext:(nullable DMGuideSavedContext *)saved
    NS_SWIFT_NAME(galarDexRanges(savedContext:));
+ (NSArray<NSString *> *)galarDexEntriesInRange:(NSInteger)range missingOnly:(BOOL)missingOnly
    savedContext:(nullable DMGuideSavedContext *)saved NS_SWIFT_NAME(galarDexEntries(inRange:missingOnly:savedContext:));
+ (NSArray<DMGuideGalarDexEntry *> *)galarDexRowsInRange:(NSInteger)range missingOnly:(BOOL)missingOnly
    savedContext:(nullable DMGuideSavedContext *)saved NS_SWIFT_NAME(galarDexRows(inRange:missingOnly:savedContext:));
+ (nullable instancetype)decode:(NSData *)data;
@end

typedef NS_ENUM(NSInteger, DMGuideSource) {
    DMGuideSourceCurrent, DMGuideSourceManual, DMGuideSourceSaved, DMGuideSourceArchive
};

// These are presentation groups, never persisted completion or availability rules.
@interface DMGuideActivityRow : NSObject
@property (nonatomic, readonly) DMGuideActivity *activity;
@property (nonatomic, readonly) NSString *hint;
@property (nonatomic, readonly) NSString *status;
@property (nonatomic, readonly) NSString *access;
@property (nonatomic, readonly) BOOL completed;
@property (nonatomic, readonly) BOOL later;
@property (nonatomic, readonly) NSArray<NSNumber *> *relatedAreas;
@end

// Resolve once for a UI refresh. Every dynamic panel receives the same progress snapshot.
@interface DMGuidePresentation : NSObject
@property (nonatomic, readonly) DMGuideArea area;
@property (nonatomic, readonly, nullable) NSNumber *wildSubarea;
@property (nonatomic, readonly, nullable) DMGuideSavedContext *progress;
@property (nonatomic, readonly) NSArray<NSString *> *summary;
@property (nonatomic, readonly) BOOL canChooseArea;
@property (nonatomic, readonly) BOOL readOnly;
+ (instancetype)resolveSource:(DMGuideSource)source manualArea:(DMGuideArea)area
    saved:(nullable DMGuideSavedContext *)saved stale:(BOOL)stale status:(NSString *)status
    live:(nullable DMGuideLiveLocation *)live preview:(nullable DMGuideSnapshot *)preview
    NS_SWIFT_NAME(resolve(source:manualArea:saved:stale:status:live:preview:));
- (NSArray<DMGuideActivityRow *> *)rowsWithGuide:(DMShieldGuide *)guide query:(NSString *)query
    incompleteOnly:(BOOL)incompleteOnly NS_SWIFT_NAME(rows(guide:query:incompleteOnly:));
+ (NSArray<NSString *> *)servicesInArea:(DMGuideArea)area NS_SWIFT_NAME(services(in:));
@end

// Main-thread API. A failed read can retain a previous result with stale set.
@interface DMGuideSaveMonitor : NSObject
@property (nonatomic, readonly, nullable) DMGuideSavedContext *context;
@property (nonatomic, readonly) BOOL stale;
@property (nonatomic, readonly) NSString *status;
- (void)refresh:(void (^)(void))changed;
@end

NS_ASSUME_NONNULL_END
