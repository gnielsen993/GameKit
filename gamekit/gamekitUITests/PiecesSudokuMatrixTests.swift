import XCTest

/// Phase 19.1 plan 06: the automated pre-review for Sudoku's pieces. Presets,
/// Video Mode zones, the largest text size, a small phone, motion off and
/// Reduce Motion, plus the end cards and two drives for a frame trace.
/// Screenshots are kept for human review (`pad-*`, `win-*`, `video-*`, ...).
@MainActor
final class PiecesSudokuMatrixTests: XCTestCase {

    private let nearWin = "--sudoku-near-win"
    private let animationsOff = ["-gamekit.animationsEnabled", "<false/>"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func presetArgs(_ preset: String, _ mode: String) -> [String] {
        ["-designkit.theme.preset", preset, "-designkit.theme.mode", mode]
    }

    private func videoArgs(_ zone: String) -> [String] {
        ["-gamekit.videoModeEnabled", "YES", "-gamekit.videoModeLocation", zone]
    }

    private func padKeys(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Place '"))
    }

    private func isInside(_ element: XCUIElement, _ window: CGRect) -> Bool {
        element.exists && !element.frame.isEmpty && window.contains(element.frame)
    }

    /// The nine digit keys, Erase and Value/Notes exist, are hittable and
    /// lie inside the window.
    private func assertControlsOnScreen(_ app: XCUIApplication, _ note: String = "") {
        let window = app.windows.firstMatch.frame
        let keys = padKeys(app)
        XCTAssertEqual(keys.count, 9, "nine digit keys \(note)")
        for index in 0..<keys.count {
            let key = keys.element(boundBy: index)
            XCTAssertTrue(key.isHittable, "\(key.label) hittable \(note)")
            XCTAssertTrue(window.contains(key.frame), "\(key.label) inside the window \(note)")
        }
        for name in ["Erase", "Toggle mode"] {
            let button = app.buttons[name]
            XCTAssertTrue(button.exists && button.isHittable, "\(name) hittable \(note)")
            XCTAssertTrue(window.contains(button.frame), "\(name) inside the window \(note)")
        }
    }

    private func cell(_ app: XCUIApplication, row: Int, column: Int) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", ", row \(row), column \(column)")).firstMatch
    }

    private func assertWinCardActions(_ app: XCUIApplication, _ note: String) {
        XCTAssertTrue(app.buttons["sudoku.endCard.primary"].waitForExistence(timeout: 6), "primary appears \(note)")
        XCTAssertTrue(app.buttons["sudoku.endCard.primary"].isHittable, "primary hittable \(note)")
        XCTAssertTrue(app.buttons["sudoku.endCard.secondary"].isHittable, "secondary hittable \(note)")
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(app.buttons["sudoku.endCard.primary"].frame), "primary inside window \(note)")
    }

    // MARK: - Presets

    func testPresetMatrix() {
        let combos = [("classicMuted", "light"), ("classicMuted", "dark"), ("dracula", "dark"),
                      ("voltage", "dark"), ("voltage", "light"), ("cream", "light")]
        for (preset, mode) in combos {
            let app = launchSudoku(args: [nearWin] + presetArgs(preset, mode))
            assertControlsOnScreen(app, "\(preset)-\(mode)")
            capturePieces(app, "pad-\(preset)-\(mode)")
            finishNearWin(app)
            assertWinCardActions(app, "\(preset)-\(mode)")
            Thread.sleep(forTimeInterval: 1.8) // let the count-up settle
            capturePieces(app, "win-\(preset)-\(mode)")
            app.terminate()
        }
    }

    // MARK: - Video Mode

    func testVideoModeZones() {
        for zone in ["largeTop", "largeBottom", "smallTopLeft", "smallBottomRight"] {
            let app = launchSudoku(args: [nearWin] + presetArgs("dracula", "dark") + videoArgs(zone))
            let window = app.windows.firstMatch.frame
            assertControlsOnScreen(app, zone)
            XCTAssertTrue(isInside(cell(app, row: 1, column: 1), window), "r1c1 inside window in \(zone)")
            XCTAssertTrue(isInside(cell(app, row: 9, column: 9), window), "r9c9 inside window in \(zone)")
            capturePieces(app, "video-\(zone)")
            finishNearWin(app)
            assertWinCardActions(app, zone)
            Thread.sleep(forTimeInterval: 1.8)
            capturePieces(app, "video-win-\(zone)")
            app.terminate()
        }
    }

    // MARK: - Largest text size

    func testLargestTextSize() {
        let xxxl = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        var app = launchSudoku(args: [nearWin] + xxxl)
        assertControlsOnScreen(app, "XXXL")
        capturePieces(app, "xxxl-pad")
        finishNearWin(app)
        assertWinCardActions(app, "XXXL")
        Thread.sleep(forTimeInterval: 1.8)
        capturePieces(app, "xxxl-win")
        app.terminate()

        // Video Mode at XXXL: the board vanishing here is the v1.6 audit item
        // (README line 19); record it, do not fail on it. The pad must stay.
        app = launchSudoku(args: [nearWin] + xxxl + videoArgs("largeTop"))
        let window = app.windows.firstMatch.frame
        let keys = padKeys(app)
        for index in 0..<keys.count {
            XCTAssertTrue(window.contains(keys.element(boundBy: index).frame), "XXXL video key \(index) inside window")
        }
        XCTAssertTrue(isInside(app.buttons["Erase"], window), "XXXL video Erase inside window")
        let boardVisible = isInside(cell(app, row: 9, column: 9), window)
        XCTContext.runActivity(named: "XXXL Video Mode board visible: \(boardVisible)") { _ in }
        capturePieces(app, "xxxl-video-largeTop")
        app.terminate()
    }

    // MARK: - Small phone (run on the iPhone SE destination)

    func testSmallPhoneFit() {
        for (preset, mode) in [("classicMuted", "light"), ("dracula", "dark")] {
            let app = launchSudoku(args: [nearWin] + presetArgs(preset, mode))
            assertControlsOnScreen(app, "SE \(preset)")
            let boardBottom = cell(app, row: 9, column: 1).frame.maxY
            let toggleTop = app.buttons["Toggle mode"].frame.minY
            XCTAssertLessThanOrEqual(boardBottom, toggleTop, "the pad never overlaps the board (\(preset))")
            capturePieces(app, "se-pad-\(preset)-\(mode)")
            finishNearWin(app)
            assertWinCardActions(app, "SE \(preset)")
            Thread.sleep(forTimeInterval: 1.8)
            capturePieces(app, "se-win-\(preset)-\(mode)")
            app.terminate()
        }
    }

    // MARK: - Motion

    /// Fills one cell, finishes the near-win and checks the card is there at
    /// once with a time that is not counting.
    private func runMotionReducedFlow(_ app: XCUIApplication, tag: String) {
        let cellToFill = firstEmptyCell(app)
        XCTAssertTrue(cellToFill.waitForExistence(timeout: 5))
        let label = cellToFill.label
        let suffix = String(label[label.range(of: ", row")!.lowerBound...])
        cellToFill.tap()
        let key = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH 'Place ' AND NOT (label ENDSWITH ', 0 remaining') AND enabled == 1"
        )).firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 3))
        key.tap()
        let filled = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", suffix)).firstMatch
        XCTAssertFalse(filled.label.hasPrefix("Empty"), "the digit registered at once (\(tag))")
        capturePieces(app, "\(tag)-placed")
        for _ in 0..<2 {
            let next = firstEmptyCell(app)
            next.tap()
            app.buttons.matching(NSPredicate(
                format: "label BEGINSWITH 'Place ' AND NOT (label ENDSWITH ', 0 remaining') AND enabled == 1"
            )).firstMatch.tap()
        }
        XCTAssertTrue(app.buttons["sudoku.endCard.primary"].waitForExistence(timeout: 1.5),
                      "no pre-roll (\(tag))")
        let time = app.descendants(matching: .any)["sudoku.endCard.time"]
        let first = time.label
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(time.label, first, "the time is not counting (\(tag))")
        capturePieces(app, "\(tag)-win")
    }

    func testMotionOff() {
        let app = launchSudoku(args: [nearWin] + animationsOff)
        runMotionReducedFlow(app, tag: "motionoff")
    }

    /// Needs the system Reduce Motion switch on (set from outside with
    /// `simctl spawn <udid> defaults write com.apple.Accessibility
    /// ReduceMotionEnabled -bool true` and a relaunch); otherwise skipped.
    func testReduceMotion() throws {
        try XCTSkipUnless(UIAccessibility.isReduceMotionEnabled,
                          "Reduce Motion is off on this device; enable it to run this test")
        let app = launchSudoku(args: [nearWin])
        runMotionReducedFlow(app, tag: "reducemotion")
    }

    // MARK: - Pressed piece (held so a screenshot can be taken from outside)

    /// Holds a pad key down for 8 seconds. When TEST_RUNNER_GK_HOLD_DIR is set
    /// a marker file is written at the start of the hold so a script can take
    /// a simulator screenshot of the pressed piece.
    private func holdKey(_ app: XCUIApplication, tag: String) {
        firstEmptyCell(app).tap()
        let key = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Place ' AND enabled == 1")).firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 3))
        if let dir = ProcessInfo.processInfo.environment["GK_HOLD_DIR"] {
            try? "hold".write(toFile: dir + "/hold-\(tag).marker", atomically: true, encoding: .utf8)
        }
        key.press(forDuration: 8)
        app.buttons["Erase"].tap()
    }

    func testPressedHoldNormal() {
        holdKey(launchSudoku(), tag: "normal")
    }

    func testPressedHoldAnimationsOff() {
        holdKey(launchSudoku(args: animationsOff), tag: "animoff")
    }

    func testPressedHoldReduceMotion() throws {
        try XCTSkipUnless(UIAccessibility.isReduceMotionEnabled, "Reduce Motion is off on this device")
        holdKey(launchSudoku(), tag: "reducemotion")
    }

    // MARK: - End cards

    /// Taps the first empty cell and plays a digit that is already given in
    /// its row, which can never be right. Lives mode rejects it and costs a life.
    private func playWrongMove(_ app: XCUIApplication) {
        let cell = firstEmptyCell(app)
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "an empty cell exists")
        let label = cell.label
        let rowText = String(label[label.range(of: "row ")!.upperBound...].prefix { $0 != "," })
        let givens = app.descendants(matching: .any).matching(
            NSPredicate(format: "label MATCHES %@", "Given [1-9], row \(rowText), column [0-9]")
        ).allElementsBoundByIndex
        for given in givens {
            let digit = String(given.label.dropFirst("Given ".count).prefix(1))
            let key = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@ AND enabled == 1", "Place \(digit),")
            ).firstMatch
            if key.exists {
                cell.tap()
                key.tap()
                return
            }
        }
        XCTFail("no enabled key for a digit given in the row")
    }

    /// The game-over card after three wrong moves in Lives mode.
    func testGameOverCard() {
        let app = launchSudoku(choices: ["Lives", "Easy"], args: presetArgs("dracula", "dark"))
        for _ in 0..<3 {
            playWrongMove(app)
            Thread.sleep(forTimeInterval: 0.8)
        }
        let keep = app.buttons["sudoku.endCard.primary"]
        XCTAssertTrue(keep.waitForExistence(timeout: 6), "game over card appears")
        XCTAssertTrue(app.staticTexts["Out of mistakes"].exists)
        XCTAssertTrue(app.buttons["sudoku.endCard.secondary"].isHittable, "Retry this puzzle is a piece")
        Thread.sleep(forTimeInterval: 0.6)
        capturePieces(app, "end-gameover-dracula")
        // The practice-complete card cannot be reached from here: the DEBUG
        // near-win jump resets a practice run to .playing, so it ends in the
        // win card. It was captured once with that reset patched out locally.
    }

    // MARK: - Frame-check drives (run under xctrace; no assertions beyond reaching the win)

    func testFrameCheckDrive() {
        let app = launchSudoku(args: [nearWin])
        Thread.sleep(forTimeInterval: 2)
        // Quick pad taps: each key on an empty cell, erased at once, so this
        // is pad and placement cost only. Then the win drive below.
        let keys = padKeys(app)
        for _ in 0..<2 {
            for index in 0..<keys.count {
                firstEmptyCell(app).tap()
                keys.element(boundBy: index).tap()
                app.buttons["Erase"].tap()
            }
        }
        app.terminate()
        let again = launchSudoku(args: [nearWin])
        finishNearWin(again)
        XCTAssertTrue(again.buttons["sudoku.endCard.primary"].waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 3)
    }

    /// Completes the same row, column and box again and again so a screenshot
    /// loop run from outside can catch the ripple mid-flight.
    func testRippleRepeat() {
        let app = launchSudoku(args: [nearWin])
        Thread.sleep(forTimeInterval: 1)
        for _ in 0..<10 {
            let cell = firstEmptyCell(app)
            XCTAssertTrue(cell.waitForExistence(timeout: 5))
            cell.tap()
            app.buttons.matching(NSPredicate(
                format: "label BEGINSWITH 'Place ' AND NOT (label ENDSWITH ', 0 remaining') AND enabled == 1"
            )).firstMatch.tap()
            Thread.sleep(forTimeInterval: 1.2)
            app.buttons["Erase"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// Lives mode: two wrong moves, each firing the flat board timelines.
    func testFrameCheckWrongMoves() {
        let app = launchSudoku(choices: ["Lives", "Easy"])
        Thread.sleep(forTimeInterval: 2)
        for _ in 0..<2 {
            playWrongMove(app)
            Thread.sleep(forTimeInterval: 1.5)
        }
        XCTAssertTrue(app.descendants(matching: .any)["1 of 3 lives remaining"].exists, "two lives were lost")
        Thread.sleep(forTimeInterval: 2)
    }
}
