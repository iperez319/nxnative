#import <Cocoa/Cocoa.h>
#import "../apple/shield_guide_save.h"

// Keep the guide's controls reachable with Tab even when macOS is configured
// to tab only between text fields. Dynamic disclosure rows rebuild the loop.
@interface DMGuideButton : NSButton
@end
@implementation DMGuideButton
- (BOOL)acceptsFirstResponder { return self.enabled; }
- (BOOL)canBecomeKeyView { return self.enabled && self.window && !self.hiddenOrHasHiddenAncestor; }
@end

@interface DMGuidePopUpButton : NSPopUpButton
@end
@implementation DMGuidePopUpButton
- (BOOL)acceptsFirstResponder { return self.enabled; }
- (BOOL)canBecomeKeyView { return self.enabled && self.window && !self.hiddenOrHasHiddenAncestor; }
@end

#include "shield_guide_reference_mac.inc"

@interface DMGuideRaidMapView : NSView
- (instancetype)initWithMap:(DMGuideRaidMap *)map selectedIndex:(NSInteger)selectedIndex
    target:(id)target action:(SEL)action;
@end

@implementation DMGuideRaidMapView {
    DMGuideRaidMap *_map;
}

- (instancetype)initWithMap:(DMGuideRaidMap *)map selectedIndex:(NSInteger)selectedIndex
    target:(id)target action:(SEL)action {
    if ((self = [super initWithFrame:NSZeroRect])) {
        _map = map;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 8;
        self.layer.masksToBounds = YES;
        [self setAccessibilityRole:NSAccessibilityGroupRole];
        [self setAccessibilityLabel:@"Wild Area den map, north up"];
        [map.markers enumerateObjectsUsingBlock:^(DMGuideRaidMapMarker *marker, NSUInteger index, BOOL *stop) {
            NSString *number = [NSString stringWithFormat:@"%ld", (long)marker.den];
            NSButton *pin = [DMGuideButton buttonWithTitle:number target:target action:action];
            pin.bezelStyle = NSBezelStyleCircular;
            pin.bordered = NO;
            pin.tag = (NSInteger)index;
            BOOL selected = pin.tag == selectedIndex;
            pin.font = [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightSemibold];
            pin.contentTintColor = selected ? NSColor.blackColor : NSColor.whiteColor;
            pin.wantsLayer = YES;
            pin.layer.cornerRadius = 10;
            pin.layer.backgroundColor = (selected ? [NSColor colorWithRed:1 green:.82 blue:.38 alpha:1] :
                [NSColor colorWithRed:.10 green:.16 blue:.16 alpha:1]).CGColor;
            pin.layer.borderColor = NSColor.whiteColor.CGColor;
            pin.layer.borderWidth = selected ? 2 : 1;
            pin.accessibilityLabel = [@"Den " stringByAppendingString:number];
            [pin setAccessibilitySelected:selected];
            [self addSubview:pin];
        }];
    }
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)layout {
    [super layout];
    NSArray<DMGuideRaidMapMarker *> *pins = [_map markersLaidOutInSize:self.bounds.size];
    [self.subviews enumerateObjectsUsingBlock:^(NSView *pin, NSUInteger index, BOOL *stop) {
        CGPoint point = pins[index].position;
        pin.frame = NSMakeRect(point.x - 12, point.y - 10, 24, 20);
    }];
}

- (void)drawRect:(NSRect)dirtyRect {
    [_map drawInContext:NSGraphicsContext.currentContext.CGContext size:self.bounds.size];
}
@end

@interface DMGuideSparkleMapView : NSView
@property (nonatomic) DMGuideSparkleMap *map;
@property (nonatomic) NSInteger selection;
@end

@implementation DMGuideSparkleMapView
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    [self.map drawInContext:NSGraphicsContext.currentContext.CGContext size:self.bounds.size
        selectedIndex:self.selection];
}
@end

@interface DMShieldGuideWindow : NSWindowController <NSSearchFieldDelegate>
- (void)openGuide:(id)sender;
@end

@implementation DMShieldGuideWindow {
    DMShieldGuide *_guide;
    DMShieldReferenceWindow *_handbook;
    NSPopUpButton *_source;
    NSPopUpButton *_area;
    NSScrollView *_scroll;
    NSStackView *_rows;
    NSMutableSet<NSString *> *_revealed;
    DMGuideSaveMonitor *_saves;
    DMGuideLiveLocation *_liveLocation;
    DMGuidePresentation *_presentation;
    NSSearchField *_search;
    NSButton *_incomplete;
    NSTimer *_refreshTimer;
    NSInteger _wildSubareaChoice[2]; // Popup row zero follows the guide location.
    NSInteger _wildSubarea[2];
    NSInteger _wildWeather[2];
    NSInteger _curryRecipeGroup;
    NSInteger _galarDexRange;
    NSInteger _selectedDexNumber;
    BOOL _galarDexShowCaught;
    BOOL _missingEncountersOnly;
    NSInteger _sparkleSpot[2];
    NSInteger _raidDen[2];
    NSInteger _raidBeam[2];
    NSInteger _raidRank[2];
}

- (void)loadWindow {
    _guide = [[DMShieldGuide alloc] initWithDefaults:NSUserDefaults.standardUserDefaults];
    _saves = [DMGuideSaveMonitor new];
    _revealed = [NSMutableSet set];

    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 560, 640)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    window.title = @"Pokémon Shield Guide";
    window.releasedWhenClosed = NO;
    window.autorecalculatesKeyViewLoop = YES;
    window.contentMinSize = NSMakeSize(390, 360);
    window.collectionBehavior = NSWindowCollectionBehaviorFullScreenAuxiliary;
    [window center];
    [window setFrameAutosaveName:@"Shield Guide"];
    self.window = window;

    NSView *content = window.contentView;
    _source = [[DMGuidePopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_source addItemWithTitle:@"Current game"];
    [_source addItemWithTitle:@"Browse manually"];
    [_source addItemWithTitle:@"Last game save"];
    for (DMGuideSnapshot *snapshot in DMShieldGuide.previews) [_source addItemWithTitle:snapshot.title];
    _source.target = self;
    _source.action = @selector(changedSource:);
    _source.accessibilityLabel = @"Guide context";

    _area = [[DMGuidePopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_area addItemsWithTitles:DMShieldGuide.areaNames];
    [_area selectItemAtIndex:_guide.selectedArea];
    _area.target = self;
    _area.action = @selector(changedArea:);
    _area.accessibilityLabel = @"Guide area";

    // Stack controls vertically so long archive names fit the minimum window width.
    NSStackView *toolbar = [NSStackView stackViewWithViews:@[_source, _area]];
    toolbar.orientation = NSUserInterfaceLayoutOrientationVertical;
    toolbar.alignment = NSLayoutAttributeLeading;
    _search = [NSSearchField new];
    _search.placeholderString = @"Search local activities and services";
    _search.accessibilityLabel = @"Search local activities and services";
    _search.target = self;
    _search.delegate = self;
    _search.action = @selector(changedSearch:);
    _search.sendsSearchStringImmediately = YES;
    [toolbar addArrangedSubview:_search];
    _incomplete = [DMGuideButton checkboxWithTitle:@"Show incomplete only" target:self action:@selector(changedChecklistFilter:)];
    [toolbar addArrangedSubview:_incomplete];
    [toolbar addArrangedSubview:[DMGuideButton buttonWithTitle:@"Offline handbook and reference"
        target:self action:@selector(openHandbook:)]];
    [_search.widthAnchor constraintEqualToAnchor:toolbar.widthAnchor].active = YES;
    toolbar.spacing = 10;
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:toolbar];

    _scroll = [NSScrollView new];
    _scroll.translatesAutoresizingMaskIntoConstraints = NO;
    _scroll.hasVerticalScroller = YES;
    [content addSubview:_scroll];
    [NSLayoutConstraint activateConstraints:@[
        [toolbar.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [toolbar.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [toolbar.topAnchor constraintEqualToAnchor:content.topAnchor constant:12],
        [_scroll.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor constant:8],
        [_scroll.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [_scroll.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [_scroll.bottomAnchor constraintEqualToAnchor:content.bottomAnchor]
    ]];
    NSClipView *clip = _scroll.contentView;
    NSView *document = [NSView new];
    _scroll.documentView = document;
    document.translatesAutoresizingMaskIntoConstraints = NO;

    _rows = [NSStackView new];
    _rows.translatesAutoresizingMaskIntoConstraints = NO;
    _rows.orientation = NSUserInterfaceLayoutOrientationVertical;
    _rows.alignment = NSLayoutAttributeLeading;
    _rows.spacing = 7;
    [document addSubview:_rows];
    [NSLayoutConstraint activateConstraints:@[
        [document.leadingAnchor constraintEqualToAnchor:clip.leadingAnchor],
        [document.widthAnchor constraintEqualToAnchor:clip.widthAnchor],
        [_rows.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:18],
        [_rows.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-18],
        [_rows.topAnchor constraintEqualToAnchor:document.topAnchor constant:14],
        [_rows.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-20]
    ]];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(calendarDayChanged:)
        name:NSCalendarDayChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(guideClosed:)
        name:NSWindowWillCloseNotification object:window];
    [self refresh];
}

- (void)openHandbook:(id)sender {
    if (!_handbook) _handbook = [DMShieldReferenceWindow new];
    if (!_handbook.window) [_handbook loadWindow];
    [_handbook showWindow:sender];
    [_handbook.window makeKeyAndOrderFront:sender];
}

- (void)openGuide:(id)sender {
    if (!self.window) [self loadWindow];
    [self.window makeKeyAndOrderFront:sender];
    [self refreshSavedContext];
    if (!_refreshTimer) {
        __weak DMShieldGuideWindow *weakSelf = self;
        _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
            [weakSelf refreshSavedContext];
        }];
    }
}

- (void)guideClosed:(NSNotification *)notification {
    [_refreshTimer invalidate];
    _refreshTimer = nil;
}

- (void)refreshSavedContext {
    NSInteger source = _source.indexOfSelectedItem;
    if (source >= 3) return;
    DMGuideLiveLocation *location = source == 0 ? DMGuideLiveLocation.currentLocation : nil;
    BOOL moved = location.area != _liveLocation.area || location.placementBased != _liveLocation.placementBased ||
        ![location.wildSubarea ?: @(-1) isEqual:_liveLocation.wildSubarea ?: @(-1)] ||
        ![location.name ?: @"" isEqualToString:_liveLocation.name ?: @""];
    _liveLocation = location;
    if (moved) [self refreshFromTop];
    [_saves refresh:^{
        if (self->_source.indexOfSelectedItem < 3 && self.window.isVisible) [self refresh];
    }];
}

- (DMGuideArea)displayedArea { return _presentation ? _presentation.area : _guide.selectedArea; }

- (void)resolvePresentation {
    NSInteger index = _source.indexOfSelectedItem;
    _presentation = [DMGuidePresentation resolveSource:index >= 3 ? DMGuideSourceArchive : (DMGuideSource)index
        manualArea:_guide.selectedArea saved:_saves.context stale:_saves.stale status:_saves.status
        live:_liveLocation preview:index >= 3 ? DMShieldGuide.previews[index - 3] : nil];
}

- (void)addText:(NSString *)text heading:(BOOL)heading {
    NSTextField *label = [NSTextField wrappingLabelWithString:text];
    if (heading) label.font = [NSFont systemFontOfSize:17 weight:NSFontWeightSemibold];
    [_rows addArrangedSubview:label];
    [label.widthAnchor constraintEqualToAnchor:_rows.widthAnchor].active = YES;
}

- (void)addReveal:(NSString *)title key:(NSString *)key text:(NSString *)text {
    BOOL revealed = [_revealed containsObject:key];
    NSButton *button = [DMGuideButton buttonWithTitle:revealed ? @"Hide details" : title target:self action:@selector(toggleReveal:)];
    button.identifier = key;
    button.accessibilityLabel = revealed ? [@"Hide " stringByAppendingString:title] : title;
    [_rows addArrangedSubview:button];
    if (revealed && text.length) [self addText:text heading:NO];
}

- (void)addBoutiqueInArea:(DMGuideArea)area savedContext:(DMGuideSavedContext *)saved {
    NSString *title = [DMGuideSavedContext boutiqueTitleInArea:area savedContext:saved];
    if (!title) return;
    NSString *key = [NSString stringWithFormat:@"boutique.%ld", (long)area];
    NSArray<DMGuideBoutiqueCategory *> *categories = [_revealed containsObject:key] ?
        [DMGuideSavedContext boutiqueCategoriesInArea:area savedContext:saved] : nil;
    [self addReveal:title key:key text:categories.count ? @"" : @"Load a Shield save to see the stock for your avatar."];
    for (DMGuideBoutiqueCategory *category in categories) {
        NSString *categoryKey = [key stringByAppendingFormat:@".%ld", (long)category.identifier];
        [self addReveal:category.title key:categoryKey text:[category.items componentsJoinedByString:@"\n"]];
    }
}

- (void)addTMsInArea:(DMGuideArea)area key:(NSString *)key savedContext:(DMGuideSavedContext *)saved {
    NSString *title = [DMGuideSavedContext tmTitleInArea:area savedContext:saved];
    if (!title) return;
    NSArray<NSString *> *rows = [_revealed containsObject:key] ?
        [DMGuideSavedContext tmRowsInArea:area savedContext:saved] : nil;
    [self addReveal:title key:key text:[rows componentsJoinedByString:@"\n\n"]];
}

- (void)addTRsInArea:(DMGuideArea)area savedContext:(DMGuideSavedContext *)saved {
    NSString *sources = [DMGuideSavedContext trSourcesInArea:area];
    if (!sources) return;
    NSString *key = @"technical-records";
    NSString *details = nil;
    if ([_revealed containsObject:key]) {
        NSArray<NSString *> *rows = [DMGuideSavedContext trRowsWithSavedContext:saved];
        details = [NSString stringWithFormat:@"%@\n\n%@", sources, [rows componentsJoinedByString:@"\n"]];
    }
    [self addReveal:[DMGuideSavedContext trTitleWithSavedContext:saved] key:key text:details];
}

- (void)addAlcremieCollectionWithSavedContext:(DMGuideSavedContext *)saved {
    NSString *key = @"alcremie-collection";
    [self addReveal:[DMGuideSavedContext alcremieTitleWithSavedContext:saved] key:key text:DMShieldGuide.alcremieDirections];
    if (![_revealed containsObject:key]) return;
    NSArray<NSString *> *titles = [DMGuideSavedContext alcremieSweetTitlesWithSavedContext:saved];
    for (NSUInteger sweet = 0; sweet < titles.count; sweet++) {
        NSString *sweetKey = [key stringByAppendingFormat:@".%lu", sweet];
        NSArray<NSString *> *rows = [_revealed containsObject:sweetKey] ?
            [DMGuideSavedContext alcremieRowsForSweet:(NSInteger)sweet savedContext:saved] : nil;
        [self addReveal:titles[sweet] key:sweetKey text:[rows componentsJoinedByString:@"\n\n"]];
    }
}

- (void)addStowMarketWithSavedContext:(DMGuideSavedContext *)saved {
    NSString *key = @"stow-market";
    NSArray<NSString *> *rows = [_revealed containsObject:key] ?
        [DMGuideSavedContext stowMarketRowsWithSavedContext:saved] : nil;
    [self addReveal:@"Street Market" key:key text:[rows componentsJoinedByString:@"\n"]];
    if (!rows) return;
    [self addReveal:@"Bargain stock" key:@"stow-market.stock"
        text:[DMGuideSavedContext.stowBargainStock componentsJoinedByString:@"\n"]];
    [self addReveal:@"Buyer prices" key:@"stow-market.prices"
        text:[DMGuideSavedContext.stowBuyerPrices componentsJoinedByString:@"\n"]];
}

- (void)addBattleTowerRecordsForDoubles:(BOOL)doubles savedContext:(DMGuideSavedContext *)saved {
    NSString *key = doubles ? @"tower.doubles" : @"tower.singles";
    NSArray<NSString *> *records = [saved battleTowerProgressForDoubles:doubles];
    [self addReveal:doubles ? @"Doubles records" : @"Singles records" key:key
        text:records.count ? [records componentsJoinedByString:@"\n"] : @"Battle records unavailable."];
    if (![_revealed containsObject:key]) return;
    NSArray<NSString *> *ranks = [DMGuideSavedContext battleTowerRankRewardsForDoubles:doubles savedContext:saved];
    NSArray<NSString *> *wins = [DMGuideSavedContext battleTowerWinRewardsForDoubles:doubles repeating:NO savedContext:saved];
    NSArray<NSString *> *repeat = [DMGuideSavedContext battleTowerWinRewardsForDoubles:doubles repeating:YES savedContext:saved];
    [self addReveal:@"Rank rewards" key:[key stringByAppendingString:@".rank-rewards"] text:[ranks componentsJoinedByString:@"\n\n"]];
    [self addReveal:@"Win rewards" key:[key stringByAppendingString:@".win-rewards"] text:[wins componentsJoinedByString:@"\n"]];
    [self addReveal:@"Repeat rewards after 200 wins" key:[key stringByAppendingString:@".repeat-rewards"]
        text:[repeat componentsJoinedByString:@"\n"]];
}

- (void)addWildSubareasInArea:(DMGuideArea)area locatedSubarea:(NSNumber *)located
    savedContext:(DMGuideSavedContext *)saved matchingSpecies:(NSSet<NSString *> *)species {
    NSString *key = [NSString stringWithFormat:@"encounters.%ld", (long)area];
    NSUInteger index = area == DMGuideAreaNorthWild ? 1 : 0;
    NSInteger choice = _wildSubareaChoice[index];
    NSInteger subarea = choice > 0 ? choice - 1 : located.integerValue;
    if (_wildSubarea[index] != subarea) {
        _wildSubarea[index] = subarea;
        _raidDen[index] = 0;
        _sparkleSpot[index] = 0;
    }
    NSArray<NSString *> *names = [DMShieldGuide wildSubareasInArea:area];
    BOOL revealed = [_revealed containsObject:key];
    NSString *title = [NSString stringWithFormat:@"%@ · %@", revealed ? @"Hide Wild Area subareas" : @"Wild Area subareas",
        names[subarea]];
    NSButton *button = [DMGuideButton buttonWithTitle:title target:self action:@selector(toggleReveal:)];
    button.identifier = key;
    [_rows addArrangedSubview:button];
    if (!revealed) return;

    NSPopUpButton *subareas = [[DMGuidePopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [subareas addItemWithTitle:@"Follow location"];
    [subareas addItemsWithTitles:names];
    [subareas selectItemAtIndex:choice];
    subareas.accessibilityLabel = @"Wild Area subarea";
    subareas.target = self;
    subareas.action = @selector(changedWildSubarea:);
    NSPopUpButton *weather = [[DMGuidePopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [weather addItemsWithTitles:DMShieldGuide.wildWeatherNames];
    [weather selectItemAtIndex:_wildWeather[index]];
    weather.accessibilityLabel = @"Weather";
    weather.target = self;
    weather.action = @selector(changedWildWeather:);
    [_rows addArrangedSubview:[NSStackView stackViewWithViews:@[subareas, weather]]];
    [self addText:[DMShieldGuide wildDirectionsInArea:area subarea:subarea] heading:NO];
    [self addWildSparklesInArea:area savedContext:saved];
    [self addRaidEncountersInArea:area matchingSpecies:species];
    [self addText:DMShieldGuide.wildWeatherHelp heading:NO];
    NSArray<NSString *> *sections = [DMShieldGuide wildEncountersInArea:area subarea:_wildSubarea[index]
        weather:_wildWeather[index] matchingSpecies:species];
    if (!sections.count) [self addText:species ? @"No missing Galar Pokédex entries for this selection." :
        @"No listed encounters for this selection." heading:NO];
    for (NSString *section in sections) [self addText:section heading:NO];
}

- (void)addWildSparklesInArea:(DMGuideArea)area savedContext:(DMGuideSavedContext *)saved {
    NSString *key = [NSString stringWithFormat:@"sparkles.%ld", (long)area];
    BOOL revealed = [_revealed containsObject:key];
    NSButton *button = [DMGuideButton buttonWithTitle:revealed ? @"Hide recurring sparkles" : @"Recurring sparkles"
        target:self action:@selector(toggleReveal:)];
    button.identifier = key;
    [_rows addArrangedSubview:button];
    if (!revealed) return;

    NSUInteger index = area == DMGuideAreaNorthWild ? 1 : 0;
    NSInteger subarea = _wildSubarea[index];
    NSArray<NSString *> *sparkles = [DMGuideSavedContext wildSparklesInArea:area subarea:subarea savedContext:saved];
    if (sparkles.count) [self addText:sparkles.firstObject heading:NO];
    DMGuideSparkleMap *map = [DMGuideSavedContext wildSparkleMapInArea:area subarea:subarea savedContext:saved];
    if (map) {
        NSPopUpButton *picker = [[DMGuidePopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        [picker addItemsWithTitles:[map.spots valueForKey:@"title"]];
        [picker selectItemAtIndex:_sparkleSpot[index]];
        picker.accessibilityLabel = @"Sparkle spot";
        picker.target = self;
        picker.action = @selector(changedSparkleSpot:);
        [_rows addArrangedSubview:picker];
        DMGuideSparkleSpot *spot = map.spots[_sparkleSpot[index]];
        [self addText:[NSString stringWithFormat:@"%@ · %@", spot.saveStatus, spot.denReference] heading:NO];
        [self addText:@"Relative positions · North ↑ · Hollow dots await respawn · D labels mark raid dens" heading:NO];
        DMGuideSparkleMapView *mapView = [DMGuideSparkleMapView new];
        mapView.map = map;
        mapView.selection = _sparkleSpot[index];
        mapView.translatesAutoresizingMaskIntoConstraints = NO;
        [_rows addArrangedSubview:mapView];
        [NSLayoutConstraint activateConstraints:@[
            [mapView.widthAnchor constraintEqualToAnchor:_rows.widthAnchor],
            [mapView.heightAnchor constraintEqualToConstant:230]
        ]];
    }
    if (sparkles.count > 1)
        [self addText:[[sparkles subarrayWithRange:NSMakeRange(1, sparkles.count - 1)] componentsJoinedByString:@"\n"] heading:NO];
    [self addText:@"Mixed reward pools can also yield a Wishing Piece." heading:NO];
}

- (void)addCurryDexWithSavedContext:(DMGuideSavedContext *)saved {
    NSString *key = @"curry-dex";
    BOOL revealed = [_revealed containsObject:key];
    NSNumber *cooked = saved.cookedCurryCount;
    NSString *title = cooked ? [NSString stringWithFormat:@"Curry Dex · %@ of 151 cooked", cooked] : @"Curry Dex";
    NSButton *button = [DMGuideButton buttonWithTitle:revealed ? [@"Hide " stringByAppendingString:title] : title
        target:self action:@selector(toggleReveal:)];
    button.identifier = key;
    [_rows addArrangedSubview:button];
    if (!revealed) return;

    NSPopUpButton *picker = [[DMGuidePopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [picker addItemsWithTitles:DMGuideSavedContext.curryRecipeGroups];
    [picker selectItemAtIndex:_curryRecipeGroup];
    picker.accessibilityLabel = @"Curry recipe group";
    picker.target = self;
    picker.action = @selector(changedCurryRecipeGroup:);
    [_rows addArrangedSubview:picker];
    if (!cooked) [self addText:@"Curry Dex progress unavailable" heading:NO];
    NSString *ingredient = [DMGuideSavedContext curryIngredientInGroup:_curryRecipeGroup];
    if (ingredient) [self addText:ingredient heading:NO];
    NSArray<NSString *> *recipes = [DMGuideSavedContext curryRecipesInGroup:_curryRecipeGroup savedContext:saved];
    [self addText:[recipes componentsJoinedByString:@"\n"] heading:NO];
    NSArray<NSString *> *rewards = [DMGuideSavedContext campingRewardsWithSavedContext:saved];
    NSString *details = [@"Ask the Camping King by the steps to Motostoke to rate your Curry Dex.\n"
        stringByAppendingString:[rewards componentsJoinedByString:@"\n"]];
    [self addReveal:@"Camping King rewards" key:@"camping-rewards" text:details];
}

- (void)addGalarDexWithSavedContext:(DMGuideSavedContext *)saved {
    NSString *key = @"galar-dex";
    BOOL revealed = [_revealed containsObject:key];
    NSNumber *caught = saved.galarDexCaughtCount;
    NSString *title = caught ? [NSString stringWithFormat:@"Galar Pokédex · %@ of 400 caught", caught] : @"Galar Pokédex";
    NSButton *button = [DMGuideButton buttonWithTitle:revealed ? [@"Hide " stringByAppendingString:title] : title
        target:self action:@selector(toggleReveal:)];
    button.identifier = key;
    [_rows addArrangedSubview:button];
    if (!revealed) return;

    NSPopUpButton *picker = [[DMGuidePopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [picker addItemsWithTitles:[DMGuideSavedContext galarDexRangesWithSavedContext:saved]];
    [picker selectItemAtIndex:_galarDexRange];
    picker.accessibilityLabel = @"Galar Pokédex range";
    picker.target = self;
    picker.action = @selector(changedGalarDexRange:);
    [_rows addArrangedSubview:picker];
    if (caught) {
        NSButton *filter = [DMGuideButton checkboxWithTitle:@"Show missing only" target:self action:@selector(changedGalarDexFilter:)];
        filter.state = _galarDexShowCaught ? NSControlStateValueOff : NSControlStateValueOn;
        [_rows addArrangedSubview:filter];
    } else {
        [self addText:@"Galar Pokédex progress unavailable" heading:NO];
    }
    NSArray<DMGuideGalarDexEntry *> *entries = [DMGuideSavedContext galarDexRowsInRange:_galarDexRange
        missingOnly:!_galarDexShowCaught savedContext:saved];
    if (!entries.count) [self addText:@"All entries in this range are caught." heading:NO];
    for (DMGuideGalarDexEntry *entry in entries) {
        NSButton *find = [DMGuideButton buttonWithTitle:entry.label target:self action:@selector(changedDexSpecies:)];
        find.tag = entry.number;
        find.accessibilityLabel = [@"Where to find " stringByAppendingString:entry.label];
        [_rows addArrangedSubview:find];
        if (entry.number == _selectedDexNumber) [self addEncounterLocationsForSpecies:entry.species];
    }
}

- (void)addEncounterLocationsForSpecies:(NSString *)species {
    DMGuideEncounterLocations *locations = [DMShieldGuide encounterLocationsForSpecies:species];
    if (locations.routes.count)
        [self addReveal:@"Routes and towns" key:@"dex-location.routes"
            text:[locations.routes componentsJoinedByString:@"\n\n"]];
    if (locations.wildArea.count)
        [self addReveal:@"Wild Area encounters" key:@"dex-location.wild"
            text:[locations.wildArea componentsJoinedByString:@"\n\n"]];
    if (locations.raids.count)
        [self addReveal:@"Max Raid dens" key:@"dex-location.raids"
            text:[locations.raids componentsJoinedByString:@"\n\n"]];
    if (locations.other.count)
        [self addReveal:@"Gifts, trades, and other sources" key:@"dex-location.other"
            text:[locations.other componentsJoinedByString:@"\n\n"]];
    if (!locations.routes.count && !locations.wildArea.count && !locations.raids.count && !locations.other.count)
        [self addText:@"No location is listed for this species in the guide." heading:NO];
}

- (void)addRaidEncountersInArea:(DMGuideArea)area matchingSpecies:(NSSet<NSString *> *)species {
    NSString *key = [NSString stringWithFormat:@"raids.%ld", (long)area];
    BOOL revealed = [_revealed containsObject:key];
    NSButton *button = [DMGuideButton buttonWithTitle:revealed ? @"Hide Max Raid dens" : @"Max Raid dens"
        target:self action:@selector(toggleReveal:)];
    button.identifier = key;
    [_rows addArrangedSubview:button];
    if (!revealed) return;

    NSUInteger index = area == DMGuideAreaNorthWild ? 1 : 0;
    NSInteger subarea = _wildSubarea[index];
    NSArray<NSNumber *> *dens = [DMShieldGuide raidDensInArea:area subarea:subarea];
    if (!dens.count) return;
    NSPopUpButton *den = [[DMGuidePopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    for (NSNumber *number in dens) [den addItemWithTitle:[NSString stringWithFormat:@"Den %@", number]];
    [den selectItemAtIndex:_raidDen[index]];
    den.accessibilityLabel = @"Raid den";
    den.target = self;
    den.action = @selector(changedRaidDen:);

    NSPopUpButton *beam = [[DMGuidePopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [beam addItemsWithTitles:@[@"Red beam", @"Purple beam"]];
    [beam selectItemAtIndex:_raidBeam[index]];
    beam.accessibilityLabel = @"Raid beam";
    beam.target = self;
    beam.action = @selector(changedRaidBeam:);

    NSPopUpButton *rank = [[DMGuidePopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [rank addItemsWithTitles:@[@"1 star", @"2 stars", @"3 stars", @"4 stars", @"5 stars"]];
    [rank selectItemAtIndex:_raidRank[index]];
    rank.accessibilityLabel = @"Raid star rank";
    rank.target = self;
    rank.action = @selector(changedRaidRank:);
    [_rows addArrangedSubview:[NSStackView stackViewWithViews:@[den, beam, rank]]];
    DMGuideRaidMap *map = [DMShieldGuide raidMapInArea:area subarea:subarea];
    if (map) {
        [self addText:@"Den locations · Schematic map · North ↑" heading:NO];
        DMGuideRaidMapView *mapView = [[DMGuideRaidMapView alloc] initWithMap:map selectedIndex:_raidDen[index]
            target:self action:@selector(changedRaidMapDen:)];
        mapView.translatesAutoresizingMaskIntoConstraints = NO;
        [_rows addArrangedSubview:mapView];
        [NSLayoutConstraint activateConstraints:@[
            [mapView.widthAnchor constraintEqualToAnchor:_rows.widthAnchor],
            [mapView.heightAnchor constraintEqualToAnchor:mapView.widthAnchor multiplier:1 / map.aspectRatio]
        ]];
    }
    [self addText:@"Standard Shield raid pools. Your Gym Badges determine which star ranks can appear." heading:NO];
    if (species) [self addText:@"Odds are for the full den pool." heading:NO];
    NSArray<NSString *> *encounters = [DMShieldGuide raidEncountersInArea:area subarea:subarea
        den:dens[_raidDen[index]].integerValue rare:_raidBeam[index] == 1 stars:_raidRank[index] + 1
        matchingSpecies:species];
    if (encounters.count) [self addText:[encounters componentsJoinedByString:@"\n"] heading:NO];
    else [self addText:species ? @"No missing Galar Pokédex entries for this selection." :
        @"No listed encounters for this selection." heading:NO];
}

- (void)refresh {
    for (NSView *row in _rows.arrangedSubviews) {
        [_rows removeArrangedSubview:row];
        [row removeFromSuperview];
    }
    [self resolvePresentation];
    DMGuideArea area = _presentation.area;
    DMGuideSavedContext *progress = _presentation.progress;
    _area.enabled = _presentation.canChooseArea;
    [_area selectItemAtIndex:area];
    for (NSString *line in _presentation.summary) [self addText:line heading:NO];
    [self addChecklist];
    NSArray<NSString *> *services = [DMGuidePresentation servicesInArea:area];
    if (services.count) {
        [self addText:@"Local services" heading:YES];
        for (NSString *service in services)
            if (!_search.stringValue.length || [service localizedStandardContainsString:_search.stringValue])
                [self addText:service heading:NO];
    }
    [self addReveal:@"Route directions" key:[NSString stringWithFormat:@"area.%ld", (long)area]
        text:[DMShieldGuide directionsInArea:area]];
    NSArray<NSString *> *encounters = [DMShieldGuide encounterGroupsInArea:area];
    BOOL wild = [DMShieldGuide hasWildEncountersInArea:area];
    NSSet<NSString *> *missing = (wild || encounters.count) ? progress.missingGalarSpecies : nil;
    NSSet<NSString *> *species = _missingEncountersOnly ? missing : nil;
    if (missing) {
        NSButton *filter = [DMGuideButton checkboxWithTitle:@"Show missing Galar Pokémon only"
            target:self action:@selector(changedEncounterFilter:)];
        filter.state = _missingEncountersOnly ? NSControlStateValueOn : NSControlStateValueOff;
        [_rows addArrangedSubview:filter];
        if (species) [self addText:@"Based on your last save. Forms share a Pokédex entry." heading:NO];
    }
    if (wild) {
        [self addWildSubareasInArea:area locatedSubarea:_presentation.wildSubarea
            savedContext:progress matchingSpecies:species];
        [self addCurryDexWithSavedContext:progress];
        NSString *title = [DMGuideSavedContext gigantamaxTitleWithSavedContext:progress];
        NSArray<NSString *> *forms = [_revealed containsObject:@"gigantamax-collection"] ?
            [DMGuideSavedContext gigantamaxRowsWithSavedContext:progress] : nil;
        [self addReveal:title key:@"gigantamax-collection" text:[forms componentsJoinedByString:@"\n\n"]];
    } else if (encounters.count) {
        if (species) encounters = [DMShieldGuide encounterGroupsInArea:area matchingSpecies:species];
        [self addReveal:@"Pokémon to find" key:[NSString stringWithFormat:@"encounters.%ld", (long)area]
            text:encounters.count ? [encounters componentsJoinedByString:@"\n\n"] :
                @"No missing Galar Pokédex entries in this area’s encounter list."];
    }
    if (area == DMGuideAreaCirchester) [self addGalarDexWithSavedContext:progress];
    if (area == DMGuideAreaMotostoke) {
        NSString *title = [DMGuideSavedContext gymChallengeTitleWithSavedContext:progress];
        NSArray<NSString *> *gyms = [DMGuideSavedContext gymChallengeRowsWithSavedContext:progress];
        [self addReveal:title key:@"gym-challenge" text:[gyms componentsJoinedByString:@"\n\n"]];
    }
    if (area == DMGuideAreaWedgehurst) {
        NSString *title = [DMGuideSavedContext postgameStadiumTitleWithSavedContext:progress];
        NSArray<NSString *> *stadiums = [DMGuideSavedContext postgameStadiumRowsWithSavedContext:progress];
        [self addReveal:title key:@"postgame-stadiums" text:[stadiums componentsJoinedByString:@"\n\n"]];
    }
    if (area == DMGuideAreaMotostoke || area == DMGuideAreaBattleTower) {
        NSString *title = [DMGuideSavedContext leagueCardAlbumTitleWithSavedContext:progress];
        NSArray<NSString *> *cards = [DMGuideSavedContext leagueCardAlbumRowsWithSavedContext:progress];
        [self addReveal:title key:@"league-card-album" text:[cards componentsJoinedByString:@"\n\n"]];
        NSArray<NSString *> *materials = [DMGuideSavedContext cardMakerRowsWithSavedContext:progress];
        [self addReveal:@"Card Maker styles" key:@"card-maker-styles" text:[materials componentsJoinedByString:@"\n"]];
    }
    if ([DMShieldGuide hasUniformWardrobeInArea:area]) {
        NSString *title = [DMGuideSavedContext uniformWardrobeTitleWithSavedContext:progress];
        NSArray<NSString *> *uniforms = [DMGuideSavedContext uniformWardrobeRowsWithSavedContext:progress];
        [self addReveal:title key:@"uniform-wardrobe" text:[uniforms componentsJoinedByString:@"\n\n"]];
    }
    [self addBoutiqueInArea:area savedContext:progress];
    DMGuideSavedContext *tmProgress = progress;
    if (area != DMGuideAreaUnknown)
        [self addTMsInArea:area key:[NSString stringWithFormat:@"tm.local.%ld", (long)area] savedContext:tmProgress];
    if (area == DMGuideAreaMotostoke || area == DMGuideAreaBattleTower)
        [self addTMsInArea:DMGuideAreaUnknown key:@"tm.case" savedContext:tmProgress];
    [self addTRsInArea:area savedContext:tmProgress];
    NSString *cafeTitle = [DMGuideSavedContext cafePrizeTitleInArea:area];
    if (cafeTitle) {
        NSString *key = [NSString stringWithFormat:@"cafe-prizes.%ld", (long)area];
        NSArray<NSString *> *rows = [_revealed containsObject:key] ?
            [DMGuideSavedContext cafePrizeRowsInArea:area savedContext:tmProgress] : nil;
        [self addReveal:cafeTitle key:key text:[rows componentsJoinedByString:@"\n"]];
    }
    if ([DMShieldGuide hasAlcremieCollectionInArea:area])
        [self addAlcremieCollectionWithSavedContext:tmProgress];
    if (area == DMGuideAreaStow) [self addStowMarketWithSavedContext:tmProgress];
    if (area == DMGuideAreaStow || area == DMGuideAreaGlimwood) {
        NSString *title = [DMGuideSavedContext teaEvolutionTitleWithSavedContext:tmProgress];
        NSArray<NSString *> *rows = [DMGuideSavedContext teaEvolutionRowsWithSavedContext:tmProgress];
        [self addReveal:title key:@"sinistea-evolutions" text:[rows componentsJoinedByString:@"\n\n"]];
    }
    if (area == DMGuideAreaWyndon) {
        NSString *title = [DMGuideSavedContext rotomFormsTitleWithSavedContext:tmProgress];
        NSArray<NSString *> *rows = [DMGuideSavedContext rotomFormRowsWithSavedContext:tmProgress];
        [self addReveal:title key:@"rotom-forms" text:[rows componentsJoinedByString:@"\n\n"]];
    }
    if (area == DMGuideAreaBattleTower) {
        NSString *title = [DMGuideSavedContext silvallyMemoryTitleWithSavedContext:progress];
        NSArray<NSString *> *rows = [DMGuideSavedContext silvallyMemoryRowsWithSavedContext:progress];
        [self addReveal:title key:@"silvally-memories" text:[rows componentsJoinedByString:@"\n"]];
        [self addBattleTowerRecordsForDoubles:NO savedContext:progress];
        [self addBattleTowerRecordsForDoubles:YES savedContext:progress];
    }
    [_scroll layoutSubtreeIfNeeded];
    [self.window recalculateKeyViewLoop];
}

- (void)addChecklist {
    NSArray<DMGuideActivityRow *> *rows = [_presentation rowsWithGuide:_guide query:_search.stringValue
        incompleteOnly:_incomplete.state == NSControlStateValueOn];
    [self addText:@"Checklist" heading:YES];
    if (!rows.count) [self addText:@"No matching activities. Clear search or show completed items." heading:NO];
    for (NSInteger group = 0; group < 3; group++) {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(DMGuideActivityRow *row, NSDictionary *bindings) {
            return (row.completed ? 2 : row.later ? 1 : 0) == group;
        }];
        NSArray<DMGuideActivityRow *> *items = [rows filteredArrayUsingPredicate:predicate];
        if (!items.count) continue;
        NSString *title = @[@"Explore nearby", @"Later visits and access to check", @"Completed"][group];
        NSString *groupKey = [NSString stringWithFormat:@"checklist.%ld.%ld", (long)_presentation.area, (long)group];
        [self addText:[NSString stringWithFormat:@"%@ · %lu", title, items.count] heading:YES];
        if (group != 0) {
            [self addReveal:[@"Show " stringByAppendingString:title] key:groupKey text:nil];
            if (![_revealed containsObject:groupKey] && !_search.stringValue.length) continue;
        }
        NSUInteger position = 0;
        for (DMGuideActivityRow *row in items) {
            if (group == 0 && position++ == 5 && !_search.stringValue.length) {
                NSString *moreKey = [groupKey stringByAppendingString:@".more"];
                [self addReveal:[NSString stringWithFormat:@"More nearby activities · %lu", items.count - 5] key:moreKey text:nil];
                if (![_revealed containsObject:moreKey]) break;
            }
            DMGuideActivity *activity = row.activity;
            [self addText:activity.title heading:YES];
            [self addText:row.hint heading:NO];
            if (![row.status isEqualToString:@"Player confirmation available"]) [self addText:row.status heading:NO];
            if (row.later) [self addText:row.access heading:NO];
            NSString *detail = [NSString stringWithFormat:@"%@\n%@\n\n%@", row.status, row.access, activity.directions];
            [self addReveal:@"Directions and preparation" key:activity.key text:detail];
            if ([_revealed containsObject:activity.key]) {
                for (NSNumber *related in row.relatedAreas) {
                    if (related.integerValue == _presentation.area) continue;
                    NSButton *link = [DMGuideButton buttonWithTitle:[@"Browse " stringByAppendingString:DMShieldGuide.areaNames[related.integerValue]]
                        target:self action:@selector(browseRelated:)];
                    link.tag = related.integerValue;
                    [_rows addArrangedSubview:link];
                }
            }
            if (!_presentation.readOnly && ![_presentation.progress activityCompletionForKey:activity.key]) {
                NSButton *check = [DMGuideButton checkboxWithTitle:@"" target:self action:@selector(toggleCheckoff:)];
                check.identifier = activity.key;
                check.state = [_guide isChecked:activity] ? NSControlStateValueOn : NSControlStateValueOff;
                [self setCheckoffLabel:check activity:activity];
                [_rows addArrangedSubview:check];
            }
            [_rows setCustomSpacing:16 afterView:_rows.arrangedSubviews.lastObject];
        }
    }
}

- (void)browseRelated:(NSButton *)sender {
    _guide.selectedArea = sender.tag;
    [_source selectItemAtIndex:DMGuideSourceManual];
    _search.stringValue = @"";
    [self refreshFromTop];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)editor doCommandBySelector:(SEL)command {
    // NSSearchField can host its own field-editor loop on recent macOS versions.
    // Navigate from the outer control so Tab reaches the rebuilt guide controls.
    if (command == @selector(insertTab:)) { [self.window selectKeyViewFollowingView:control]; return YES; }
    if (command == @selector(insertBacktab:)) { [self.window selectKeyViewPrecedingView:control]; return YES; }
    return NO;
}

- (void)changedSearch:(NSSearchField *)sender { [self refresh]; }
- (void)changedChecklistFilter:(NSButton *)sender { [self refresh]; }

- (void)setCheckoffLabel:(NSButton *)button activity:(DMGuideActivity *)activity {
    if (button.state == NSControlStateValueOn)
        button.title = activity.isDaily ? @"Checked off by you today" : @"Checked off by you";
    else
        button.title = activity.isDaily ? @"Check off for today" : @"Check off";
    button.accessibilityLabel = [NSString stringWithFormat:@"%@ — %@", activity.title, button.title];
}

- (void)refreshFromTop {
    [self refresh];
    [_scroll.documentView scrollPoint:NSMakePoint(0, NSMaxY(_scroll.documentView.bounds))];
}

- (void)changedSource:(NSPopUpButton *)sender {
    [self refreshFromTop];
    [self refreshSavedContext];
}

- (void)changedArea:(NSPopUpButton *)sender {
    _guide.selectedArea = sender.indexOfSelectedItem;
    [self refreshFromTop];
}

- (void)calendarDayChanged:(NSNotification *)notification {
    [self refresh];
}

- (void)changedWildSubarea:(NSPopUpButton *)sender {
    NSUInteger index = [self displayedArea] == DMGuideAreaNorthWild ? 1 : 0;
    _wildSubareaChoice[index] = sender.indexOfSelectedItem;
    [self refresh];
}

- (void)changedWildWeather:(NSPopUpButton *)sender {
    NSUInteger index = [self displayedArea] == DMGuideAreaNorthWild ? 1 : 0;
    _wildWeather[index] = sender.indexOfSelectedItem;
    [self refresh];
}

- (void)changedSparkleSpot:(NSPopUpButton *)sender {
    NSUInteger index = [self displayedArea] == DMGuideAreaNorthWild ? 1 : 0;
    _sparkleSpot[index] = sender.indexOfSelectedItem;
    [self refresh];
}

- (void)changedCurryRecipeGroup:(NSPopUpButton *)sender {
    _curryRecipeGroup = sender.indexOfSelectedItem;
    [self refresh];
}

- (void)changedGalarDexRange:(NSPopUpButton *)sender {
    _galarDexRange = sender.indexOfSelectedItem;
    _selectedDexNumber = 0;
    [self refresh];
}

- (void)changedDexSpecies:(NSButton *)sender {
    _selectedDexNumber = sender.tag == _selectedDexNumber ? 0 : sender.tag;
    [self refresh];
}

- (void)changedGalarDexFilter:(NSButton *)sender {
    _galarDexShowCaught = sender.state != NSControlStateValueOn;
    [self refresh];
}

- (void)changedEncounterFilter:(NSButton *)sender {
    _missingEncountersOnly = sender.state == NSControlStateValueOn;
    [self refresh];
}

- (void)changedRaidDen:(NSPopUpButton *)sender {
    _raidDen[[self displayedArea] == DMGuideAreaNorthWild ? 1 : 0] = sender.indexOfSelectedItem;
    [self refresh];
}

- (void)changedRaidMapDen:(NSButton *)sender {
    NSInteger selected = sender.tag;
    _raidDen[[self displayedArea] == DMGuideAreaNorthWild ? 1 : 0] = selected;
    [self refresh];
    for (NSView *row in _rows.arrangedSubviews) {
        if ([row isKindOfClass:DMGuideRaidMapView.class] && (NSUInteger)selected < row.subviews.count) {
            [self.window makeFirstResponder:row.subviews[selected]];
            break;
        }
    }
}

- (void)changedRaidBeam:(NSPopUpButton *)sender {
    _raidBeam[[self displayedArea] == DMGuideAreaNorthWild ? 1 : 0] = sender.indexOfSelectedItem;
    [self refresh];
}

- (void)changedRaidRank:(NSPopUpButton *)sender {
    _raidRank[[self displayedArea] == DMGuideAreaNorthWild ? 1 : 0] = sender.indexOfSelectedItem;
    [self refresh];
}

- (void)toggleReveal:(NSButton *)sender {
    NSString *key = sender.identifier;
    if (!key) return;
    if ([_revealed containsObject:key]) [_revealed removeObject:key];
    else [_revealed addObject:key];
    [self refresh];
    for (NSView *row in _rows.arrangedSubviews) {
        if ([row isKindOfClass:NSButton.class] && [row.identifier isEqualToString:key]) {
            [self.window makeFirstResponder:row];
            [row scrollRectToVisible:row.bounds];
            break;
        }
    }
}

- (void)toggleCheckoff:(NSButton *)sender {
    NSString *key = sender.identifier;
    if (!key) return;
    for (DMGuideActivity *activity in [DMShieldGuide activitiesInArea:[self displayedArea]]) {
        if (![activity.key isEqualToString:key]) continue;
        [_guide setChecked:sender.state == NSControlStateValueOn forActivity:activity];
        [self refresh];
        break;
    }
}
@end

void dm_shield_guide_mac_menu(NSMenu *bar) {
    if (!dm_shield_guide_available()) return;
    static DMShieldGuideWindow *guide;
    guide = [DMShieldGuideWindow new];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Guide"];
    [menu addItemWithTitle:@"Open Pokémon Shield Guide" action:@selector(openGuide:) keyEquivalent:@""].target = guide;
    [bar addItemWithTitle:@"Guide" action:nil keyEquivalent:@""].submenu = menu;
}
