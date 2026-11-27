import XCTest

/// End-to-end checks for Sudoku's pieces (Phase 19.1, DESIGN.md §3.8):
/// pad keys, erase and Value/Notes. Screenshots are kept for human review.
@MainActor
final class PiecesSudokuTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Tap the first empty cell, then place a digit with the first enabled
    /// pad key. `keyOffset` picks where on the key the tap lands.
    private func placeDigit(_ app: XCUIApplication, keyOffset: CGVector?) -> (cell: String, suffix: String) {
        let cell = firstEmptyCell(app)
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "an empty cell exists")
        let label = cell.label
        let suffix = String(label[label.range(of: ", row")!.lowerBound...])
        cell.tap()
        let key = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Place ' AND enabled == 1")).firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 3), "an enabled pad key exists")
        if let keyOffset {
            key.coordinate(withNormalizedOffset: keyOffset).tap()
        } else {
            key.tap()
        }
        return (label, suffix)
    }

    private func cellText(_ app: XCUIApplication, suffix: String) -> String {
        let cell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", suffix)).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 3))
        return cell.label
    }

    func testPadKeyPlacesDigit() {
        let app = launchSudoku()
        let placed = placeDigit(app, keyOffset: nil)
        let after = cellText(app, suffix: placed.suffix)
        XCTAssertFalse(after.hasPrefix("Empty"), "the pad key filled the cell: \(after)")
        capturePieces(app, "pad-key-places-digit")
        app.buttons["Erase"].tap() // leave no saved mistake for other suites
    }

    func testPadKeyTopEdgeTapRegisters() {
        let app = launchSudoku()
        let placed = placeDigit(app, keyOffset: CGVector(dx: 0.5, dy: 0.04))
        let after = cellText(app, suffix: placed.suffix)
        XCTAssertFalse(after.hasPrefix("Empty"), "a tap on the key's top edge filled the cell: \(after)")
        capturePieces(app, "pad-key-top-edge")
        app.buttons["Erase"].tap() // leave no saved mistake for other suites
    }

    func testEraseAndModeArePieces() {
        let app = launchSudoku()
        let placed = placeDigit(app, keyOffset: nil)
        XCTAssertFalse(cellText(app, suffix: placed.suffix).hasPrefix("Empty"))
        let erase = app.buttons["Erase"]
        XCTAssertTrue(erase.waitForExistence(timeout: 3))
        erase.tap()
        XCTAssertTrue(cellText(app, suffix: placed.suffix).hasPrefix("Empty"), "erase cleared the cell")
        let toggle = app.buttons["Toggle mode"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "Notes")
        capturePieces(app, "erase-and-mode")
    }

    /// D-14: a wrong digit in Lives mode is not shown; the cell stays empty
    /// and a life is lost. The shake itself is judged by eye (screenshot).
    func testWrongMoveInLivesModeIsRejected() {
        let app = launchSudoku(choices: ["Lives", "Easy"])
        let cell = firstEmptyCell(app)
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "an empty cell exists")
        let label = cell.label
        let rowText = String(label[label.range(of: "row ")!.upperBound...].prefix { $0 != "," })
        // A digit already given in this row can never be right for an empty
        // cell of the same row.
        let givens = app.descendants(matching: .any).matching(
            NSPredicate(format: "label MATCHES %@", "Given [1-9], row \(rowText), column [0-9]")
        ).allElementsBoundByIndex
        XCTAssertFalse(givens.isEmpty, "the row has a given to borrow a wrong digit from")
        var wrongKey: XCUIElement?
        for given in givens {
            let digit = String(given.label.dropFirst("Given ".count).prefix(1))
            let key = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@ AND enabled == 1", "Place \(digit),")
            ).firstMatch
            if key.exists { wrongKey = key; break }
        }
        let key = try? XCTUnwrap(wrongKey, "an enabled key for a digit given in the row")
        cell.tap()
        key?.tap()
        capturePieces(app, "lives-wrong-move") // right after the tap
        let suffix = String(label[label.range(of: ", row")!.lowerBound...])
        XCTAssertTrue(cellText(app, suffix: suffix).hasPrefix("Empty"), "the wrong digit is not shown")
        XCTAssertTrue(app.descendants(matching: .any)["2 of 3 lives remaining"].waitForExistence(timeout: 3),
                      "a life was lost")
    }

    /// Animations off: nothing pops or travels, yet the move registers at once.
    func testMotionOffPlacementStillRegisters() {
        let app = launchSudoku(args: ["-gamekit.animationsEnabled", "<false/>"])
        let placed = placeDigit(app, keyOffset: nil)
        XCTAssertFalse(cellText(app, suffix: placed.suffix).hasPrefix("Empty"),
                       "the digit is on the board without waiting")
        capturePieces(app, "motion-off-placement")
        app.buttons["Erase"].tap() // leave no saved mistake for other suites
    }

    /// Plan 07 deletes this test together with the strength switch.
    func testDebugSettingsOffersThreeStrengths() {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-launch", "-gamekit.cloudSyncEnabled", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 10))
        app.buttons["Profile"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        let bold = app.buttons["Bold"]
        var swipes = 0
        while !bold.exists && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(bold.waitForExistence(timeout: 3), "Bold exists in the DEBUG section")
        XCTAssertTrue(app.buttons["Subtle"].exists)
        XCTAssertTrue(app.buttons["Medium"].exists)
        bold.tap()
        capturePieces(app, "debug-strength-bold")
        app.buttons["Medium"].tap() // restore the default
    }
}

extension XCTestCase {
    /// Launch into a Sudoku game. `choices` are tapped in order, matching a
    /// button whose label is the choice or begins with "<choice>,".
    @MainActor
    func launchSudoku(choices: [String] = ["Free", "Easy"], args: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-launch", "-gamekit.cloudSyncEnabled", "NO"] + args
        app.launch()
        XCTAssertTrue(app.buttons["Sudoku"].waitForExistence(timeout: 10))
        app.buttons["Sudoku"].tap()
        for choice in choices {
            let button = app.buttons.matching(
                NSPredicate(format: "label == %@ OR label BEGINSWITH %@", choice, choice + ",")
            ).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 3), choice)
            button.tap()
        }
        if app.buttons["New Puzzle"].waitForExistence(timeout: 1) { app.buttons["New Puzzle"].tap() }
        return app
    }

    /// First element of any type whose label begins "Empty, row".
    @MainActor
    func firstEmptyCell(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Empty, row'")).firstMatch
    }

    @MainActor
    func capturePieces(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 0.5)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
