// AppKit smoke test through the same Guide menu action as the Mac host.
#import "../../host/shield_guide_mac.m"
#include <assert.h>
#include <fcntl.h>

static NSString *committedPath;

static int openCommitted(void) {
    return open(committedPath.fileSystemRepresentation, O_RDONLY | O_CLOEXEC);
}

static NSButton *checkoff(DMShieldGuideWindow *window, NSString *key) {
    NSStackView *rows = [window valueForKey:@"rows"];
    for (NSView *row in rows.arrangedSubviews)
        if ([row isKindOfClass:NSButton.class] && [row.identifier isEqualToString:key] &&
            ((NSButton *)row).action == @selector(toggleCheckoff:)) return (NSButton *)row;
    return nil;
}

static BOOL displaysText(DMShieldGuideWindow *window, NSString *text) {
    NSStackView *rows = [window valueForKey:@"rows"];
    for (NSView *row in rows.arrangedSubviews)
        if ([row isKindOfClass:NSTextField.class] && [[(NSTextField *)row stringValue] containsString:text])
            return YES;
    return NO;
}

static void showAllChecklist(DMShieldGuideWindow *window) {
    NSMutableSet *revealed = [window valueForKey:@"revealed"];
    for (NSInteger area = 0; area < (NSInteger)DMShieldGuide.areaNames.count; area++) {
        for (NSInteger group = 0; group < 3; group++) {
            NSString *key = [NSString stringWithFormat:@"checklist.%ld.%ld", (long)area, (long)group];
            [revealed addObject:key];
            [revealed addObject:[key stringByAppendingString:@".more"]];
        }
    }
    [window refresh];
}

static void awaitText(DMShieldGuideWindow *window, NSString *text) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (!displaysText(window, text) && deadline.timeIntervalSinceNow > 0)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    assert(displaysText(window, text));
}

static void commit(NSString *fixtures, NSString *name, DMShieldGuideWindow *window) {
    NSData *bytes = [NSData dataWithContentsOfFile:[fixtures stringByAppendingPathComponent:name]];
    assert(bytes && [bytes writeToFile:committedPath atomically:YES]);
    DMGuideSaveMonitor *monitor = [window valueForKey:@"saves"];
    DMGuideSavedContext *before = monitor.context;
    [window refreshSavedContext];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (monitor.context == before && deadline.timeIntervalSinceNow > 0)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    assert(monitor.context != before && !monitor.stale);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        assert(argc == 2);
        NSString *fixtures = @(argv[1]);
        committedPath = [fixtures stringByAppendingPathComponent:@"mac-committed"];
        dm_shield_guide_configure("a16802625e7826bf83b6f9708e475b91", openCommitted);

        NSApplication *app = NSApplication.sharedApplication;
        NSMenu *bar = [NSMenu new];
        dm_shield_guide_mac_menu(bar);
        NSMenuItem *open = [bar itemWithTitle:@"Guide"].submenu.itemArray.firstObject;
        assert([open.title isEqualToString:@"Open Pokémon Shield Guide"]);
        DMShieldGuideWindow *window = open.target;
        // Install isolated defaults before the first visible refresh.
        [window loadWindow];
        NSString *suite = [@"nxnative.shield-guide-ui." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        DMShieldGuide *guide = [[DMShieldGuide alloc] initWithDefaults:defaults];
        [window setValue:guide forKey:@"guide"];
        assert([app sendAction:open.action to:open.target from:open]);
        assert(window.window.isVisible);
        awaitText(window, @"Waiting for a committed Shield save");

        // Static browser is reachable through its production action before any save exists.
        [window openHandbook:nil];
        DMShieldReferenceWindow *handbook = [window valueForKey:@"handbook"];
        assert(handbook.window.isVisible);
        NSSearchField *referenceSearch = [handbook valueForKey:@"query"];
        NSPopUpButton *referenceCategory = [handbook valueForKey:@"category"];
        NSTableView *referenceResults = [handbook valueForKey:@"table"];
        NSTextView *referenceDetail = [handbook valueForKey:@"detail"];
        [referenceCategory selectItemWithTitle:@"Moves"];
        [handbook filterChanged:nil];
        assert(referenceResults.numberOfRows == 25);
        [handbook nextPage:nil];
        assert([[handbook valueForKey:@"page"] integerValue] == 1);
        referenceSearch.stringValue = @"Zing Zap";
        [handbook controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:referenceSearch]];
        assert([[handbook valueForKey:@"page"] integerValue] == 0);
        assert(referenceResults.numberOfRows == 1 && [referenceDetail.string containsString:@"Power: 80"]);
        assert([referenceDetail.string containsString:@"pp. 336–351"]);
        referenceSearch.stringValue = @"no-such-reference-entry-xyz";
        [handbook controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:referenceSearch]];
        assert(referenceResults.numberOfRows == 0 && [referenceDetail.string containsString:@"No matching"]);
        referenceSearch.stringValue = @"Moxie";
        [referenceCategory selectItemAtIndex:0]; [handbook filterChanged:nil];
        assert(referenceResults.numberOfRows == 1 && [referenceDetail.string containsString:@"Attack"]);
        [handbook.window setContentSize:handbook.window.contentMinSize];
        [handbook.window.contentView layoutSubtreeIfNeeded];
        assert(!referenceSearch.hasAmbiguousLayout && referenceSearch.frame.size.width > 300);
        assert([referenceCategory canBecomeKeyView] && referenceDetail.selectable);
        [handbook close];

        commit(fixtures, @"monitor/later", window);
        awaitText(window, @"Saved location · Route 2");
        awaitText(window, @"Last saved objective");
        NSPopUpButton *source = [window valueForKey:@"source"];
        [source selectItemAtIndex:1];  // Browse manually.
        guide.selectedArea = DMGuideAreaRoute1;
        [window refresh];
        assert(!displaysText(window, @"Collected · recorded in save")); // Completed starts collapsed.
        showAllChecklist(window);
        assert(displaysText(window, @"Collected · recorded in save"));
        NSButton *incomplete = [window valueForKey:@"incomplete"];
        [incomplete performClick:nil];
        assert(!displaysText(window, @"Collected · recorded in save"));
        [incomplete performClick:nil];
        NSSearchField *search = [window valueForKey:@"search"];
        search.stringValue = @"does not exist";
        [window changedSearch:search];
        assert(displaysText(window, @"No matching activities"));
        search.stringValue = @"Potion";
        [window changedSearch:search];
        assert(displaysText(window, @"Collected · recorded in save"));
        search.stringValue = @"";
        [window changedSearch:search];
        assert(!checkoff(window, @"route1.potion"));

        guide.selectedArea = DMGuideAreaPostwick;
        commit(fixtures, @"first-hop/won", window);
        awaitText(window, @"First Hop battle win recorded");
        assert(!checkoff(window, @"postwick.hop-first-win"));
        assert(checkoff(window, @"postwick.sonia-revives").state == NSControlStateValueOff);

        guide.selectedArea = DMGuideAreaMotostoke;
        commit(fixtures, @"cafe-prizes/split", window);
        awaitText(window, @"Challenge used when last saved");
        NSButton *daily = checkoff(window, @"motostoke.battle-cafe");
        assert(daily.state == NSControlStateValueOff);
        [daily performClick:nil];
        assert(checkoff(window, @"motostoke.battle-cafe").state == NSControlStateValueOn);
        [defaults setObject:@"2000-01-01" forKey:@"shieldGuide.checked.motostoke.battle-cafe"];
        [NSNotificationCenter.defaultCenter postNotificationName:NSCalendarDayChangedNotification object:nil];
        assert(checkoff(window, @"motostoke.battle-cafe").state == NSControlStateValueOff);

        guide.selectedArea = DMGuideAreaWedgehurst;
        commit(fixtures, @"monitor/superseded", window);
        awaitText(window, @"Post-lab Potion event recorded");
        NSButton *birthday = checkoff(window, @"wedgehurst.birthday");
        assert(birthday && birthday.state == NSControlStateValueOff);
        [birthday performClick:nil];
        assert(checkoff(window, @"wedgehurst.birthday").state == NSControlStateValueOn);
        [source selectItemAtIndex:3];
        [window refresh];
        assert(displaysText(window, @"Archived party · Scorbunny"));
        assert(!checkoff(window, @"wedgehurst.birthday"));
        assert(!displaysText(window, @"Post-lab Potion event recorded"));

        [source selectItemAtIndex:2];  // Last game save.
        commit(fixtures, @"monitor/later", window);
        awaitText(window, @"Saved location · Route 2");
        assert([[@"broken" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:committedPath atomically:YES]);
        [window refreshSavedContext];
        awaitText(window, @"Last known save · refresh unavailable");
        assert(displaysText(window, @"Last-known saved objective") && checkoff(window, @"wedgehurst.birthday"));
        commit(fixtures, @"monitor/early", window);
        awaitText(window, @"Saved location · Wedgehurst");
        assert(!displaysText(window, @"refresh unavailable"));
        assert(checkoff(window, @"wedgehurst.birthday").state == NSControlStateValueOn);

        // Shared manual detail progress, linked area browsing and minimum sizing.
        [source selectItemAtIndex:1];
        guide.selectedArea = DMGuideAreaHammerlocke;
        [[window valueForKey:@"revealed"] addObject:@"hammerlocke.letter"];
        [window refresh];
        NSButton *related = nil;
        for (NSView *row in ((NSStackView *)[window valueForKey:@"rows"]).arrangedSubviews)
            if ([row isKindOfClass:NSButton.class] && ((NSButton *)row).action == @selector(browseRelated:)) { related = (NSButton *)row; break; }
        assert(related && related.tag == DMGuideAreaBallonlea);
        [related performClick:nil];
        assert([window displayedArea] == DMGuideAreaBallonlea && source.indexOfSelectedItem == 1);
        [window refreshSavedContext];
        assert([window displayedArea] == DMGuideAreaBallonlea);
        for (NSValue *size in @[[NSValue valueWithSize:NSMakeSize(390, 360)], [NSValue valueWithSize:NSMakeSize(900, 800)]]) {
            [window.window setContentSize:size.sizeValue];
            [window.window.contentView layoutSubtreeIfNeeded];
            assert(!window.window.contentView.hasAmbiguousLayout);
            assert(search.frame.size.width > 250);
            assert(search.accessibilityLabel.length && related.accessibilityLabel.length);
            NSString *output = NSProcessInfo.processInfo.environment[@"DM_GUIDE_UI_OUTPUT"];
            if (output) {
                [NSFileManager.defaultManager createDirectoryAtPath:output withIntermediateDirectories:YES attributes:nil error:nil];
                NSView *content = window.window.contentView;
                NSBitmapImageRep *image = [content bitmapImageRepForCachingDisplayInRect:content.bounds];
                [content cacheDisplayInRect:content.bounds toBitmapImageRep:image];
                NSString *file = [output stringByAppendingPathComponent:[NSString stringWithFormat:@"mac-%ld.png", (long)size.sizeValue.width]];
                assert([[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:file atomically:YES]);
            }
            [window.window makeFirstResponder:search];
            assert(window.window.firstResponder == search.currentEditor);
            assert([window control:search textView:(NSTextView *)search.currentEditor doCommandBySelector:@selector(insertTab:)]);
            assert(window.window.firstResponder != search.currentEditor);
        }
        // One reviewed expectation table is also consumed by the simulator UI tests.
        NSData *journeyData = [NSData dataWithContentsOfFile:[fixtures stringByAppendingPathComponent:@"release-journeys.json"]];
        NSArray<NSDictionary *> *journeys = [NSJSONSerialization JSONObjectWithData:journeyData options:0 error:nil];
        assert(journeys.count == 16);
        [source selectItemAtIndex:1];
        for (NSDictionary *step in journeys) {
            guide.selectedArea = [step[@"area"] integerValue];
            search.stringValue = step[@"title"];
            [[window valueForKey:@"revealed"] addObject:step[@"key"]];
            commit(fixtures, step[@"fixture"], window);
            showAllChecklist(window);
            if (!displaysText(window, step[@"status"])) NSLog(@"Journey failed: %@", step);
            assert(displaysText(window, step[@"status"]));
            DMGuideSavedContext *saved = ((DMGuideSaveMonitor *)[window valueForKey:@"saves"]).context;
            assert(!![saved activityCompletionForKey:step[@"key"]] == [step[@"completed"] boolValue]);
        }
        search.stringValue = @"";
        guide.selectedArea = DMGuideAreaWildArea;
        NSMutableSet *revealed = [window valueForKey:@"revealed"];
        [revealed addObjectsFromArray:@[@"encounters.3", @"sparkles.3"]];
        commit(fixtures, @"rehearsal/sparkle-waiting", window);
        assert(displaysText(window, @"1 of 14 spots awaiting respawn"));
        commit(fixtures, @"rehearsal/sparkle-respawned", window);
        assert(displaysText(window, @"0 of 14 spots awaiting respawn"));
        puts("PASS: 16 shared release journey expectations and Wild Area respawn screens");
        [window close];
        [defaults removePersistentDomainForName:suite];
        assert([NSFileManager.defaultManager removeItemAtPath:committedPath error:nil]);
        puts("PASS: Mac Guide menu, filters/search, linked manual browse, compact groups, minimum/large sizing, keyboard focus, daily/archive isolation and stale recovery");
    }
}
