import XCTest

@MainActor
final class MathCrosswordJourneyTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func openMath(difficulty: String = "Easy", arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-launch", "-gamekit.cloudSyncEnabled", "NO"] + arguments
        app.launch()
        app.buttons["Math Crossword"].tap()
        app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", difficulty, difficulty + ",")).firstMatch.tap()
        if app.buttons["Continue"].waitForExistence(timeout: 2) { app.buttons["Continue"].tap() }
        XCTAssertTrue(app.buttons["Show a Math Crossword hint"].waitForExistence(timeout: 30))
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 0.5)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }

    func testHintResumeUndoAndComplete() {
        let app = openMath()
        capture(app, "Math-start")
        app.buttons["Show a Math Crossword hint"].tap()
        capture(app, "Math-teaching")
        app.buttons["Show the numbers"].tap()
        capture(app, "Math-reveal")
        app.buttons["Fill it in"].tap()
        XCTAssertTrue(app.buttons["Undo last tile"].isEnabled)
        capture(app, "Math-applied")
        app.terminate()
        app.launch()
        app.buttons["Math Crossword"].tap()
        app.buttons.matching(NSPredicate(format: "label == 'Easy' OR label BEGINSWITH 'Easy,'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["Undo last tile"].isEnabled)
        app.buttons["Undo last tile"].tap()
        capture(app, "Math-resumed-undo")
        for _ in 0..<30 {
            if app.buttons["New puzzle"].exists { break }
            app.buttons["Show a Math Crossword hint"].tap()
            if app.buttons["Show the numbers"].exists { app.buttons["Show the numbers"].tap() }
            XCTAssertTrue(app.buttons["Fill it in"].waitForExistence(timeout: 3))
            app.buttons["Fill it in"].tap()
        }
        XCTAssertTrue(app.buttons["New puzzle"].waitForExistence(timeout: 5))
        capture(app, "Math-complete")
    }

    func testVideoThemes() {
        for (preset, location) in [("classicMuted", "largeTop"), ("dracula", "largeBottom"), ("voltage", "smallTopRight"), ("lavender", "smallBottomLeft")] {
            let app = openMath(arguments: ["-designkit.theme.preset", preset, "-gamekit.videoModeEnabled", "YES", "-gamekit.videoModeLocation", location])
            app.buttons["Show a Math Crossword hint"].tap()
            XCTAssertTrue(app.buttons["Dismiss hint"].isHittable)
            capture(app, "Math-\(preset)-\(location)")
            app.buttons["Dismiss hint"].tap()
            app.terminate()
        }
    }

    func testManualPlacementEraseAndUndo() {
        let app = openMath(arguments: ["-designkit.theme.preset", "classicMuted", "-gamekit.videoModeEnabled", "NO"])
        let blank = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Blank number at row' AND value == 'empty'")).firstMatch
        XCTAssertTrue(blank.waitForExistence(timeout: 5))
        let coordinateLabel = blank.label
        blank.tap()
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Place '")).firstMatch
        let number = String(tile.label.dropFirst(6))
        tile.tap()
        let placed = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", coordinateLabel)).firstMatch
        XCTAssertEqual(placed.value as? String, number)
        app.buttons["Erase selected tile"].tap()
        XCTAssertEqual(placed.value as? String, "empty")
        app.buttons["Undo last tile"].tap()
        XCTAssertEqual(placed.value as? String, number)
        capture(app, "Math-manual-place-erase-undo")
    }

    func testAllDifficultyLayouts() {
        for difficulty in ["Easy", "Medium", "Hard"] {
            let app = openMath(difficulty: difficulty, arguments: ["-designkit.theme.preset", "classicMuted", "-gamekit.videoModeEnabled", "NO", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"])
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Blank number at row'")).firstMatch.waitForExistence(timeout: 30))
            capture(app, "Math-\(difficulty)-layout")
            app.terminate()
        }
    }

    func testAccessibilityText() {
        let app = openMath(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-gamekit.videoModeEnabled", "YES", "-gamekit.videoModeLocation", "largeTop"])
        app.buttons["Show a Math Crossword hint"].tap()
        XCTAssertTrue(app.buttons["Dismiss hint"].isHittable)
        capture(app, "Math-XXXL-video")
        app.buttons["Dismiss hint"].tap()
        let blank = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Blank number at row' AND value == 'empty'")).firstMatch
        XCTAssertTrue(blank.exists)
        blank.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Place '")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Undo last tile"].isEnabled)
        app.buttons["Undo last tile"].tap()
        capture(app, "Math-XXXL-played-and-undone")
    }
}
