import XCTest

/// User-flow probes for the v1.6 release audit. Screenshots and accessibility
/// trees are retained in the result bundle for human inspection.
@MainActor
final class Release16ClosureTests: XCTestCase {
    func capture(_ app: XCUIApplication, _ name: String) {
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

    func open(_ game: String, choices: [String], args: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-launch", "-gamekit.cloudSyncEnabled", "NO"] + args
        app.launch()
        XCTAssertTrue(app.buttons[game].waitForExistence(timeout: 10))
        app.buttons[game].tap()
        for choice in choices {
            let button = app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", choice, choice + ",")).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 3), choice)
            button.tap()
        }
        if app.buttons["Resume"].waitForExistence(timeout: 1) { app.buttons["Resume"].tap() }
        if app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
        capture(app, game + "-start")
        return app
    }

    func hint(_ game: String, choices: [String], label: String) {
        let app = open(game, choices: choices)
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        capture(app, game + "-hint")
        if app.buttons["Dismiss hint"].exists {
            app.buttons["Dismiss hint"].tap()
            capture(app, game + "-dismissed")
        }
        app.terminate()
    }

    func testSudoku() { hint("Sudoku", choices: ["Free", "Easy"], label: "Show a Sudoku hint") }
    func testNonogram() { hint("Nonogram", choices: ["Free", "5×5"], label: "Show a Nonogram hint") }
    func testFreeCell() { hint("FreeCell", choices: ["Easy"], label: "Show a FreeCell move") }
    func testFiveLetter() { hint("Five Letter", choices: ["Unlimited"], label: "Suggest a useful guess") }
    func testWordGrid() { hint("Word Grid", choices: ["Relaxed"], label: "Reveal a word") }
    func testMinesweeper() { hint("Minesweeper", choices: ["Easy"], label: "Show a Minesweeper hint") }
    func testMerge() {
        let app = open("Merge", choices: ["2048"])
        app.swipeLeft(); app.swipeDown(); app.swipeRight(); app.swipeUp()
        capture(app, "Merge-played")
    }
    func testSolitaire() { _ = open("Solitaire", choices: ["Easy"]) }
    func testStack() {
        let app = open("Stack", choices: [])
        app.tap(); app.tap(); app.tap()
        capture(app, "Stack-played")
    }
    func testSnake() {
        let app = open("Snake", choices: [])
        app.swipeUp(); app.swipeLeft()
        capture(app, "Snake-played")
    }

    func testDeepSudokuNotesAndResume() {
        let app = open("Sudoku", choices: ["Free", "Easy"])
        app.buttons["Toggle mode"].tap()
        app.buttons["Show a Sudoku hint"].tap()
        capture(app, "Sudoku-notes-hint")
        app.buttons["Fill it in"].tap()
        capture(app, "Sudoku-notes-applied")
        app.terminate()
        app.launch()
        app.buttons["Sudoku"].tap()
        app.buttons["Free"].tap()
        app.buttons["Easy"].tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        capture(app, "Sudoku-resume-choice")
        app.buttons["Continue"].tap()
        capture(app, "Sudoku-resumed")
    }

    func testDeepNonogramCompleteHintAndPractice() {
        let app = open("Nonogram", choices: ["Lives", "5×5"])
        app.buttons["Show a Nonogram hint"].tap()
        XCTAssertTrue(app.buttons["Dismiss hint"].waitForExistence(timeout: 3))
        app.buttons["Dismiss hint"].tap()
        for _ in 0..<5 {
            let target = app.buttons["Hint: fill this square"].firstMatch
            if target.exists { target.tap() }
        }
        capture(app, "Nonogram-followed-hint")
        for _ in 0..<12 {
            if app.buttons["Keep solving"].exists { break }
            let empty = app.buttons["Empty square"].firstMatch
            if empty.exists { empty.tap() }
        }
        capture(app, "Nonogram-loss")
        if app.buttons["Keep solving"].exists {
            app.buttons["Keep solving"].tap()
            capture(app, "Nonogram-practice")
        }
    }

    func testDeepMinesweeperPlayHint() {
        let app = open("Minesweeper", choices: ["Easy"])
        let hidden = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'hidden' OR label CONTAINS[c] 'unrevealed'")).firstMatch
        if hidden.exists { hidden.tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        app.buttons["Show a Minesweeper hint"].tap()
        XCTAssertTrue(app.buttons["Dismiss hint"].waitForExistence(timeout: 4))
        capture(app, "Minesweeper-playing-hint")
        app.buttons["Dismiss hint"].tap()
        capture(app, "Minesweeper-playing-dismissed")
    }

    func testDeepVideoThemeMatrix() {
        for (preset, zone) in [("classicMuted", "largeTop"), ("dracula", "largeBottom"), ("voltage", "smallTopRight"), ("lavender", "smallBottomLeft")] {
            let app = open("Sudoku", choices: ["Free", "Easy"], args: [
                "-designkit.theme.preset", preset,
                "-gamekit.videoModeEnabled", "YES", "-gamekit.videoModeLocation", zone
            ])
            let hint = app.buttons["Show a Sudoku hint"]
            XCTAssertTrue(hint.waitForExistence(timeout: 3))
            hint.tap()
            capture(app, "Sudoku-" + preset + "-" + zone)
            app.terminate()
        }
    }

    func testDeepLargeText() {
        let app = open("Sudoku", choices: ["Free", "Easy"], args: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-gamekit.videoModeEnabled", "YES", "-gamekit.videoModeLocation", "largeTop"
        ])
        app.buttons["Show a Sudoku hint"].tap()
        capture(app, "Sudoku-accessibilityXXXL-video")
        XCTAssertTrue(app.buttons["Dismiss hint"].isHittable)
        let dismiss = app.buttons["Dismiss hint"]
        dismiss.coordinate(withNormalizedOffset: CGVector(dx: -1.5, dy: 0.8))
            .press(forDuration: 0.1, thenDragTo: dismiss.coordinate(withNormalizedOffset: CGVector(dx: -1.5, dy: -0.7)))
        capture(app, "Sudoku-accessibilityXXXL-explanation-scrolled")
        app.buttons["Fill it in"].tap()
        XCTAssertFalse(app.buttons["Dismiss hint"].exists)
    }

    func testDeepWordGridFollowHintAndFinish() {
        let app = open("Word Grid", choices: ["Relaxed"])
        app.buttons["Reveal a word"].tap()
        capture(app, "WordGrid-follow-before")
        let title = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Found '")).firstMatch.label
        let letters = Array(title.dropFirst(6)).map(String.init)
        let tiles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Letter '")).allElementsBoundByIndex
        XCTAssertEqual(tiles.count, 16)
        let grid = tiles.map { String($0.label.dropFirst(7).prefix(1)) }
        func path(_ soFar: [Int]) -> [Int]? {
            if soFar.count == letters.count { return soFar }
            for index in 0..<grid.count where !soFar.contains(index) && grid[index] == letters[soFar.count] {
                if let last = soFar.last, max(abs(last / 4 - index / 4), abs(last % 4 - index % 4)) != 1 { continue }
                if let result = path(soFar + [index]) { return result }
            }
            return nil
        }
        let route = path([])
        XCTAssertNotNil(route)
        app.buttons["Dismiss hint"].tap()
        for index in route ?? [] { tiles[index].tap() }
        capture(app, "WordGrid-traced")
        app.buttons["Submit"].tap()
        capture(app, "WordGrid-submitted-zero-points")
        XCTAssertTrue(app.otherElements.matching(NSPredicate(format: "label CONTAINS %@", "words found: " + letters.joined())).firstMatch.exists)
        app.buttons["Finish"].tap()
        capture(app, "WordGrid-finished")
    }

    func testDeepFreeCellApplyUndoResume() {
        let app = open("FreeCell", choices: ["Easy"])
        app.buttons["Show a FreeCell move"].tap()
        app.buttons["Move it for me"].tap()
        capture(app, "FreeCell-hint-applied")
        XCTAssertTrue(app.buttons["Undo"].isEnabled)
        app.terminate()
        app.launch()
        app.buttons["FreeCell"].tap()
        app.buttons["Easy"].tap()
        if app.buttons["Continue"].waitForExistence(timeout: 2) { app.buttons["Continue"].tap() }
        capture(app, "FreeCell-resume")
        if app.buttons["Undo"].isEnabled { app.buttons["Undo"].tap() }
        capture(app, "FreeCell-undo")
    }

    func testDeepProfileSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-launch", "-gamekit.cloudSyncEnabled", "NO"]
        app.launch()
        app.buttons["Profile"].tap()
        capture(app, "Profile-stats")
        app.buttons["Settings"].tap()
        capture(app, "Settings-top")
        app.swipeUp()
        capture(app, "Settings-bottom")
    }

    func testSmallNonogram20Video() {
        let app = open("Nonogram", choices: ["Free", "20×20"], args: [
            "-designkit.theme.preset", "dracula", "-gamekit.videoModeEnabled", "YES",
            "-gamekit.videoModeLocation", "largeTop"
        ])
        app.buttons["Show a Nonogram hint"].tap()
        XCTAssertTrue(app.buttons["Dismiss hint"].waitForExistence(timeout: 5))
        capture(app, "Small-Nonogram20-video-hint")
        app.buttons["Dismiss hint"].tap()
        let fill = app.buttons["Hint: fill this square"].firstMatch
        if fill.exists { fill.tap() }
        capture(app, "Small-Nonogram20-followed")
    }

    func testSmallWordAndCardHints() {
        for (game, choices, label) in [
            ("Five Letter", ["Unlimited"], "Suggest a useful guess"),
            ("Word Grid", ["Relaxed"], "Reveal a word"),
            ("FreeCell", ["Easy"], "Show a FreeCell move")
        ] {
            let app = open(game, choices: choices, args: [
                "-designkit.theme.preset", "dracula", "-gamekit.videoModeEnabled", "YES",
                "-gamekit.videoModeLocation", "largeTop"
            ])
            app.buttons[label].tap()
            capture(app, "Small-" + game + "-video-hint")
            app.terminate()
        }
    }

    func testSmallSudokuAndBackgroundTimer() {
        let app = open("Sudoku", choices: ["Free", "Easy"])
        app.buttons["Show a Sudoku hint"].tap()
        app.buttons["Fill it in"].tap()
        app.buttons["Show a Sudoku hint"].tap()
        capture(app, "Small-Sudoku-hint-before-background")
        XCUIDevice.shared.press(.home)
        app.activate()
        let timer = app.otherElements["Time elapsed"].firstMatch
        let before = timer.value as? String
        Thread.sleep(forTimeInterval: 3)
        capture(app, "Small-Sudoku-hint-after-background")
        let after = timer.value as? String
        XCTAssertNotNil(before)
        XCTAssertEqual(before, after)
    }

    func testSmallArcadeRunEnds() {
        let app = open("Snake", choices: [])
        app.buttons["Options"].tap()
        if app.buttons["Wall mode: Off"].exists { app.buttons["Wall mode: Off"].tap() }
        else { app.tap() }
        app.buttons["Move up"].tap()
        XCTAssertTrue(app.buttons["Restart"].waitForExistence(timeout: 12))
        capture(app, "Snake-game-over")
        app.buttons["Restart"].tap()
        capture(app, "Snake-restarted")
        app.terminate()
        let stack = open("Stack", choices: [])
        for _ in 0..<18 {
            if stack.buttons["Restart"].exists { break }
            stack.tap()
        }
        capture(stack, "Stack-run-end")
    }
}
