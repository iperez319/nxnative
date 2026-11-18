import XCTest

final class GuideUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ fixture: String = "monitor/later", live: Bool = false, replacement: String? = nil, area: Int = 27) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["GUIDE_FIXTURE": fixture, "GUIDE_AREA": String(area)] // Route 1 fallback
        if live { app.launchEnvironment["GUIDE_LIVE"] = "motostoke" }
        if let replacement {
            app.launchEnvironment["GUIDE_REPLACEMENT"] = replacement
            app.launchEnvironment["GUIDE_RECOVERY"] = "monitor/early"
        }
        app.launch()
        return app
    }
    private func text(_ app: XCUIApplication, _ value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }
    private func source(_ app: XCUIApplication, _ title: String) {
        let control = app.buttons["guide.source"]
        control.tap()
        let choice = app.buttons[title]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.press(forDuration: 0.15)
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            control.label.contains(title)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
    func testArrivalAndSources() {
        let app = launch(live: true)
        XCTAssertTrue(text(app, "Live location estimate").waitForExistence(timeout: 10))
        XCTAssertTrue(text(app, "moved since saving").exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Gym mission,")).firstMatch.exists)
        capture(app, "mixed-live-save")
        source(app, "Last game save")
        XCTAssertTrue(text(app, "Saved location · Route 2").waitForExistence(timeout: 5))
        XCTAssertFalse(text(app, "moved since saving").exists)
        source(app, "Browse manually")
        XCTAssertTrue(text(app, "Browsing · Route 1").waitForExistence(timeout: 5))
        XCTAssertTrue(text(app, "last readable game save").exists)
        source(app, "Wedgehurst before Route 2")
        XCTAssertTrue(text(app, "Archived party").waitForExistence(timeout: 5))
        XCTAssertTrue(text(app, "Read-only archive reference").exists)
        capture(app, "archive")
    }

    func testOfflineHandbook() {
        let app = launch("none")
        let handbook = app.buttons["guide.handbook"]
        XCTAssertTrue(handbook.waitForExistence(timeout: 10))
        handbook.tap()
        XCTAssertTrue(app.navigationBars["Offline handbook"].waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Moxie\n")
        let moxie = app.buttons["reference.entry.abilities-moxie"]
        XCTAssertTrue(moxie.waitForExistence(timeout: 5))
        moxie.tap()
        XCTAssertTrue(text(app, "Effects in battle").waitForExistence(timeout: 5))
        if !text(app, "359–364").isHittable { reveal(text(app, "359–364"), in: app) }
        XCTAssertTrue(text(app, "359–364").exists)
        capture(app, "offline-handbook-ability")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        search.tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "Zing Zap\n")
        let move = app.buttons["reference.entry.moves-zing-zap"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        move.tap()
        XCTAssertTrue(text(app, "Power: 80").waitForExistence(timeout: 5))
        if !text(app, "336–351").isHittable { reveal(text(app, "336–351"), in: app) }
        XCTAssertTrue(text(app, "336–351").exists)
        capture(app, "offline-handbook-move")
    }

    func testHandbookPagingAndCategory() {
        let app = launch("none")
        let handbook = app.buttons["guide.handbook"]
        XCTAssertTrue(handbook.waitForExistence(timeout: 10))
        handbook.tap()
        let next = app.buttons["reference.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        XCTAssertTrue(text(app, "Page 2 of").waitForExistence(timeout: 5))
        let category = app.buttons["reference.category"]
        category.tap()
        let categorySearch = app.searchFields.firstMatch
        categorySearch.tap()
        categorySearch.typeText("Natures\n")
        app.buttons["Natures"].tap()
        XCTAssertTrue(text(app, "25 results").waitForExistence(timeout: 5))
        XCTAssertFalse(next.exists)
        let adamant = app.buttons["reference.entry.natures-adamant"]
        XCTAssertTrue(adamant.waitForExistence(timeout: 5))
        adamant.tap()
        XCTAssertTrue(text(app, "Disliked flavor: Dry").waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            let pixels = XCUIScreen.main.screenshot().image.size
            return frame.width > frame.height && pixels.width > pixels.height && self.text(app, "Disliked flavor: Dry").isHittable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 8), .completed)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = "handbook-landscape-nature"
        screen.lifetime = .keepAlways
        add(screen)
        XCUIDevice.shared.orientation = .portrait
    }
    func testChecklistFiltersAndSearch() {
        let app = launch()
        XCTAssertTrue(text(app, "Saved location · Route 2").waitForExistence(timeout: 10))
        source(app, "Browse manually")
        XCTAssertTrue(text(app, "Browsing · Route 1").waitForExistence(timeout: 5))
        let completed = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Completed ·")).firstMatch
        for _ in 0..<8 {
            if completed.isHittable && completed.frame.midY < app.windows.firstMatch.frame.maxY - 160 { break }
            // Small drags avoid skipping the short completed group behind the search bar.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        capture(app, "before-filter")
        XCTAssertTrue(completed.isHittable, app.debugDescription)
        completed.tap()
        let potion = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Potion pickup")).firstMatch
        XCTAssertTrue(potion.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            if app.switches["guide.incomplete"].isHittable { break }
            app.swipeDown()
        }
        // SwiftUI exposes a labeled container plus the actual switch control.
        app.switches["guide.incomplete"].switches.firstMatch.tap()
        let filtered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !completed.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [filtered], timeout: 5), .completed, app.debugDescription)
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Potion pickup")
        XCTAssertTrue(text(app, "No matching activities").waitForExistence(timeout: 5))
        capture(app, "filtered-local-search")
    }

    func testNoSaveAndOrientation() {
        let app = launch("none")
        XCTAssertTrue(text(app, "Waiting for a committed Shield save").waitForExistence(timeout: 10))
        capture(app, "portrait-no-save")
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return frame.width > frame.height && app.buttons["guide.source"].isHittable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 8), .completed)
        capture(app, "landscape-no-save")
        XCUIDevice.shared.orientation = .portrait
    }
    func testStaleReadAndRecovery() {
        let app = launch(replacement: "broken")
        XCTAssertTrue(text(app, "Saved location · Route 2").waitForExistence(timeout: 10))
        XCTAssertTrue(text(app, "Last known save · refresh unavailable").waitForExistence(timeout: 12))
        XCTAssertTrue(text(app, "Automatic progress unavailable").exists)
        XCTAssertTrue(text(app, "Browsing · Route 1").exists)
        capture(app, "stale")
        XCTAssertTrue(text(app, "Saved location · Wedgehurst").waitForExistence(timeout: 15))
        XCTAssertFalse(text(app, "Automatic progress unavailable").exists)
    }

    func testCollectionDeepAccess() {
        let app = launch("none", area: 20) // Circhester, offline reference.
        XCTAssertTrue(text(app, "Browsing · Circhester").waitForExistence(timeout: 10))
        let dex = app.buttons.matching(NSPredicate(format: "label == %@", "Galar Pokédex")).firstMatch
        for _ in 0..<14 {
            if dex.isHittable && dex.frame.midY < app.windows.firstMatch.frame.maxY - 160 { break }
            app.swipeUp()
        }
        XCTAssertTrue(dex.isHittable)
        dex.tap()
        let grookey = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Grookey")).firstMatch
        for _ in 0..<8 {
            if grookey.isHittable && grookey.frame.midY < app.windows.firstMatch.frame.maxY - 160 { break }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        capture(app, "expanded-dex")
        XCTAssertTrue(grookey.isHittable, app.debugDescription)
        grookey.tap()
        XCTAssertTrue(app.navigationBars["Grookey"].waitForExistence(timeout: 5))
        capture(app, "dex-deep-link")
    }
    private struct Journey: Decodable {
        let name, family, fixture, key, title, status, group: String
        let area: Int
        let completed: Bool
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let list = app.collectionViews.firstMatch
        for _ in 0..<18 {
            // iPad presents a centered sheet; the window extends beyond its viewport.
            let viewport = list.frame
            if element.isHittable && element.frame.midY < viewport.maxY - 140 { return }
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
    private func journeys(_ families: Set<String>) throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "release-journeys", withExtension: "json"))
        let steps = try JSONDecoder().decode([Journey].self, from: Data(contentsOf: url))
        XCTAssertEqual(steps.count, 16)
        for step in steps where families.contains(step.family) {
            let app = launch(step.fixture, area: step.area)
            XCTAssertTrue(app.buttons["guide.source"].waitForExistence(timeout: 10))
            source(app, "Browse manually")
            let search = app.searchFields.firstMatch
            search.tap()
            search.typeText(step.title + "\n")
            if step.group != "nearby" {
                let prefix = step.group == "completed" ? "Completed ·" : "Later visits and access to check ·"
                let group = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
                reveal(group, in: app)
                group.tap()
            }
            let row = app.buttons["guide.activity.\(step.key)"]
            reveal(row, in: app)
            XCTAssertTrue(row.exists, step.name)
            row.tap()
            XCTAssertTrue(text(app, step.status).waitForExistence(timeout: 5), step.name + "\n" + app.debugDescription)
            let checkoff = app.switches.matching(NSPredicate(format: "label CONTAINS %@", step.title)).firstMatch
            if !step.completed { reveal(checkoff, in: app) }
            XCTAssertEqual(checkoff.exists, !step.completed, step.name)
            capture(app, step.name)
            app.terminate()
        }
    }
    func testReleaseOpeningAndQuests() throws { try journeys(["opening", "quests"]) }
    func testReleaseGymRetry() throws { try journeys(["gym"]) }
    func testReleaseDailyAndCollectionRestore() throws { try journeys(["daily", "collection"]) }

    func testFirstCommitAndRollback() {
        let app = launch("none", replacement: "monitor/later")
        XCTAssertTrue(text(app, "Waiting for a committed Shield save").waitForExistence(timeout: 10))
        XCTAssertTrue(text(app, "Saved location · Route 2").waitForExistence(timeout: 12))
        capture(app, "first-readable-commit")
        XCTAssertTrue(text(app, "Saved location · Wedgehurst").waitForExistence(timeout: 15))
        XCTAssertFalse(text(app, "refresh unavailable").exists)
        capture(app, "older-synthetic-commit")
    }
    func testWildWeatherAndRecurringItems() {
        for (fixture, expected) in [("waiting", "1 of 14 spots awaiting respawn"), ("respawned", "0 of 14 spots awaiting respawn")] {
            let app = launch("rehearsal/sparkle-" + fixture, area: 3)
            XCTAssertTrue(app.buttons["guide.source"].waitForExistence(timeout: 10))
            source(app, "Browse manually")
            let wild = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Wild Area subareas")).firstMatch
            reveal(wild, in: app)
            wild.tap()
            let weather = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Weather,")).firstMatch
            reveal(weather, in: app)
            weather.tap()
            app.buttons["Intense Sun"].tap()
            let sparkles = app.buttons["Recurring sparkles"]
            reveal(sparkles, in: app)
            sparkles.tap()
            XCTAssertTrue(text(app, expected).waitForExistence(timeout: 5))
            capture(app, "wild-" + fixture)
            // Collapse the locator before inspecting the weather-specific encounter list.
            sparkles.tap()
            let growlithe = text(app, "Growlithe")
            reveal(growlithe, in: app)
            XCTAssertTrue(growlithe.exists)
            capture(app, "intense-sun-encounters-" + fixture)
            app.terminate()
        }
    }

    func testSourceMenuAcrossUnchangedPolls() {
        let app = launch()
        XCTAssertTrue(text(app, "Saved location · Route 2").waitForExistence(timeout: 10))
        let control = app.buttons["guide.source"]
        control.tap()
        let choice = app.buttons["Browse manually"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        let disappears = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !choice.exists }, object: nil)
        disappears.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [disappears], timeout: 3.2), .completed)
        choice.press(forDuration: 0.15)
        XCTAssertTrue(text(app, "Browsing · Route 1").waitForExistence(timeout: 5))
        capture(app, "source-menu-after-unchanged-polls")
    }

    func testPrintedGuideServiceSearch() {
        let app = launch("none", area: 3)
        XCTAssertTrue(app.buttons["guide.source"].waitForExistence(timeout: 10))
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("tent color\n")
        let king = text(app, "lead Pokémon’s type")
        reveal(king, in: app)
        XCTAssertTrue(king.exists)
        XCTAssertTrue(text(app, "dual-type lead offers two choices").exists)
        capture(app, "printed-guide-tent-color-service")
    }

}
