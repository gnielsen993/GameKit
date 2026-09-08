import XCTest

/// Operator-only native capture suite. Run on an isolated marketing simulator:
/// --screenshots deliberately replaces its demonstration stats and saved games.
@MainActor
final class AppStoreMarketingCapture: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?.hasPrefix("GameDrawer Marketing ") == true,
            "Capture fixtures require an isolated GameDrawer Marketing simulator."
        )
    }

    private func launch(seed: Bool = false, preset: String = "classicMuted", mode: String = "light", video: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-launch", "-gamekit.cloudSyncEnabled", "NO",
            "-designkit.theme.preset", preset, "-designkit.theme.mode", mode,
            "-gamekit.videoModeEnabled", video ? "YES" : "NO",
            "-gamekit.videoModeLocation", "largeTop",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        if seed { app.launchArguments.append("--screenshots") }
        app.launch()
        XCTAssertTrue(app.buttons["Math Crossword"].waitForExistence(timeout: 15))
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func open(_ game: String, choices: [String], resume: Bool = true, video: Bool = false) -> XCUIApplication {
        let app = launch(video: video)
        app.buttons[game].tap()
        for choice in choices {
            let button = app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", choice, choice + ",")).firstMatch
            if button.waitForExistence(timeout: 2) { button.tap() }
        }
        if resume {
            for title in ["Continue", "Resume"] {
                if app.buttons[title].waitForExistence(timeout: 1) { app.buttons[title].tap() }
            }
        }
        return app
    }

    func testCaptureCollection() {
        var app = launch(seed: true)
        capture(app, "home-classic")
        app.terminate()

        app = open("Sudoku", choices: ["Free", "Easy"])
        capture(app, "sudoku")
        app.buttons["Show a Sudoku hint"].tap()
        capture(app, "sudoku-hint")
        app.terminate()

        app = open("Math Crossword", choices: ["Easy"])
        XCTAssertTrue(app.buttons["Show a Math Crossword hint"].waitForExistence(timeout: 30))
        capture(app, "math-crossword")
        app.terminate()

        app = open("Five Letter", choices: ["Unlimited"])
        app.buttons["Restart puzzle"].tap()
        for letter in "CRANE" { app.buttons["Letter \(letter)"].tap() }
        app.buttons["Enter"].tap()
        capture(app, "five-letter")
        app.terminate()

        app = open("Word Grid", choices: ["Relaxed"])
        app.buttons["Reveal a word"].tap()
        app.buttons["Dismiss hint"].tap()
        capture(app, "word-grid")
        app.terminate()

        app = open("FreeCell", choices: ["Easy"])
        capture(app, "freecell")
        app.terminate()
        app = open("FreeCell", choices: ["Easy"], resume: false)
        capture(app, "freecell-resume")
        app.terminate()

        app = open("Merge", choices: ["2048"])
        capture(app, "merge")
        app.terminate()

        app = launch(video: true)
        app.buttons["Video Mode"].tap()
        if app.frame.width > 600 { app.scrollViews.firstMatch.swipeUp() }
        capture(app, "video-mode-positions")
        app.terminate()

        app = launch()
        app.buttons["Profile"].tap()
        app.buttons["Stats"].tap()
        capture(app, "stats")
        app.terminate()

        app = launch(preset: "dracula", mode: "dark")
        capture(app, "home-dracula")
        app.terminate()
        app = launch(preset: "voltage", mode: "dark")
        capture(app, "home-voltage")
        app.terminate()
    }

    func testCaptureVideoAndStats() {
        var app = open("Merge", choices: ["2048"], video: true)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.6))
        start.press(forDuration: 0.1, thenDragTo: end)
        capture(app, "merge-video-large")
        app.terminate()

        app = launch()
        app.buttons["Profile"].tap()
        app.buttons["Stats"].tap()
        capture(app, "stats-dashboard")
        app.terminate()
    }
}
