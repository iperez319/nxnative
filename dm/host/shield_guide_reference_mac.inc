// Included by shield_guide_mac.m to share the host's accessible control classes.
@interface DMShieldReferenceWindow : NSWindowController <NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>
@end
@implementation DMShieldReferenceWindow {
    NSSearchField *_query;
    NSPopUpButton *_category;
    NSTableView *_table;
    NSTextView *_detail;
    NSTextField *_count;
    NSButton *_previous, *_next;
    NSArray<DMGuideReferenceEntry *> *_entries;
    NSInteger _page;
}
- (void)loadWindow {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, 700)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    window.title = @"Shield Offline Handbook";
    window.releasedWhenClosed = NO;
    window.collectionBehavior = NSWindowCollectionBehaviorFullScreenAuxiliary;
    window.contentMinSize = NSMakeSize(390, 560);
    window.autorecalculatesKeyViewLoop = YES;
    [window center]; self.window = window;
    _query = [NSSearchField new];
    _query.placeholderString = @"Search all reference facts";
    _query.accessibilityLabel = _query.placeholderString;
    _query.sendsSearchStringImmediately = YES;
    _query.delegate = self;
    _category = [[DMGuidePopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_category addItemWithTitle:@"All categories"];
    [_category addItemsWithTitles:DMShieldReference.categories];
    _category.accessibilityLabel = @"Reference category";
    _category.target = self; _category.action = @selector(filterChanged:);
    _count = [NSTextField wrappingLabelWithString:@""];
    _previous = [DMGuideButton buttonWithTitle:@"Previous page" target:self action:@selector(previousPage:)];
    _next = [DMGuideButton buttonWithTitle:@"Next page" target:self action:@selector(nextPage:)];
    NSStackView *paging = [NSStackView stackViewWithViews:@[_previous, _next]];
    paging.spacing = 12;
    NSScrollView *results = [NSScrollView new];
    results.hasVerticalScroller = YES;
    _table = [NSTableView new];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"entry"];
    column.title = @"Reference entries";
    [_table addTableColumn:column];
    _table.headerView = nil; _table.dataSource = self; _table.delegate = self;
    _table.allowsEmptySelection = NO;
    _table.rowHeight = 30;
    _table.accessibilityLabel = @"Reference results";
    results.documentView = _table;
    NSScrollView *detailScroll = [NSScrollView new];
    detailScroll.hasVerticalScroller = YES; detailScroll.borderType = NSBezelBorder;
    _detail = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 540, 200)];
    _detail.editable = NO; _detail.selectable = YES;
    _detail.richText = NO; _detail.font = [NSFont systemFontOfSize:14];
    _detail.textContainerInset = NSMakeSize(10, 10);
    _detail.verticallyResizable = YES; _detail.horizontallyResizable = NO;
    _detail.autoresizingMask = NSViewWidthSizable;
    _detail.textContainer.widthTracksTextView = YES;
    _detail.accessibilityLabel = @"Reference detail and source";
    detailScroll.documentView = _detail;
    NSTextField *help = [NSTextField wrappingLabelWithString:@"Base-game facts · Available without a save · Reference entries do not track completion"];
    NSStackView *stack = [NSStackView stackViewWithViews:@[help, _query, _category, _count, results, paging, detailScroll]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading; stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [window.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:window.contentView.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:window.contentView.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:window.contentView.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:window.contentView.bottomAnchor constant:-16],
        [results.heightAnchor constraintEqualToConstant:130],
        [detailScroll.heightAnchor constraintGreaterThanOrEqualToConstant:100],
    ]];
    for (NSView *view in @[help, _query, _category, _count, results, detailScroll])
        [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [self reload];
}
- (void)controlTextDidChange:(NSNotification *)notification { _page = 0; [self reload]; }
- (void)filterChanged:(id)sender { _page = 0; [self reload]; }
- (void)previousPage:(id)sender { if (_page > 0) _page--; [self reload]; }
- (void)nextPage:(id)sender { if ((_page + 1) * 25 < (NSInteger)_entries.count) _page++; [self reload]; }
- (void)reload {
    NSString *category = _category.indexOfSelectedItem > 0 ? _category.titleOfSelectedItem : @"";
    _entries = [DMShieldReference entriesInCategory:category query:_query.stringValue];
    NSInteger pages = MAX(1, ((NSInteger)_entries.count + 24) / 25);
    _page = MIN(_page, pages - 1);
    _count.stringValue = [NSString stringWithFormat:@"%lu results · Page %ld of %ld", (unsigned long)_entries.count, (long)_page + 1, (long)pages];
    _previous.enabled = _page > 0; _next.enabled = _page + 1 < pages;
    [_table reloadData];
    if ([self numberOfRowsInTableView:_table]) [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [self tableViewSelectionDidChange:[NSNotification notificationWithName:NSTableViewSelectionDidChangeNotification object:_table]];
    [_table scrollRowToVisible:0];
    [self.window recalculateKeyViewLoop];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return MIN(25, MAX(0, (NSInteger)_entries.count - _page * 25));
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    DMGuideReferenceEntry *entry = _entries[_page * 25 + row];
    return [NSString stringWithFormat:@"%@ · %@", entry.title, entry.category];
}
- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger index = _page * 25 + _table.selectedRow;
    if (_table.selectedRow < 0 || index >= (NSInteger)_entries.count) {
        _detail.string = @"No matching reference entries. Clear search or choose All categories.";
    } else {
        DMGuideReferenceEntry *entry = _entries[index];
        _detail.string = [NSString stringWithFormat:@"%@\n%@\n\n%@\n\nSource: %@", entry.title, entry.category, entry.body, entry.citation];
    }
    [_detail scrollRangeToVisible:NSMakeRange(0, 0)];
}
@end
