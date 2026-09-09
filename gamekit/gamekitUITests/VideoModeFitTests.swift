import XCTest
import UIKit

@MainActor
final class VideoModeFitTests: XCTestCase {
    private var testLandscape = false
    override func setUpWithError() throws { continueAfterFailure = false }

    private func open(_ game: String, choices: [String], zone: String = "largeTop") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-launch", "-gamekit.cloudSyncEnabled", "NO",
            "-gamekit.videoModeEnabled", zone == "off" ? "NO" : "YES",
            "-gamekit.videoModeLocation", zone == "off" ? "smallBottomLeft" : zone,
            "-designkit.theme.preset", ["largeBottom": "dracula", "smallTopLeft": "voltage", "smallTopRight": "lavender"][zone] ?? "classicMuted"]
        app.launch()
        if testLandscape {
            XCUIDevice.shared.orientation = .landscapeLeft
            let landscape = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil
            )
            XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed,
                           "The tablet game must actually be in landscape")
        }
        XCTAssertTrue(app.buttons[game].waitForExistence(timeout: 15))
        app.buttons[game].tap()
        for choice in choices {
            let button = app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", choice, choice + ",")).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
        }
        for title in ["Continue", "Resume"] {
            if app.buttons[title].waitForExistence(timeout: 1) { app.buttons[title].tap() }
        }
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }

    func testMathBoardAndBankFitWithoutScrolling() {
        let app = open("Math Crossword", choices: ["Hard"])
        XCTAssertTrue(app.buttons["Show a Math Crossword hint"].waitForExistence(timeout: 40))
        capture(app, "math-hard-largeTop")
        let cells = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Blank number' OR label BEGINSWITH 'Given number'"))
        XCTAssertGreaterThan(cells.count, 0)
        let bank = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Place '"))
        let bankTop = bank.allElementsBoundByIndex.map(\.frame.minY).min() ?? app.frame.maxY
        for cell in cells.allElementsBoundByIndex {
            XCTAssertTrue(app.frame.contains(cell.frame), cell.label + " outside screen: \(cell.frame)")
            XCTAssertLessThanOrEqual(cell.frame.maxY, bankTop, cell.label + " overlaps bank")
        }
        XCTAssertEqual(app.scrollViews.count, 0, "The full board and inventory must be visible together")
    }

    func testMathDragFromBankWithoutSelectingBlank() {
        checkMathDrag(zone: "off")
    }

    func testMathDragInVideoMode() {
        for zone in ["largeTop", "smallBottomRight"] { checkMathDrag(zone: zone) }
    }

    func testTabletLandscapeFitAndDragging() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Tablet landscape layout") }
        defer {
            testLandscape = false
            XCUIDevice.shared.orientation = .portrait
        }
        let probe = open("Math Crossword", choices: ["Hard"])
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in probe.frame.width > probe.frame.height }, object: nil
        )
        guard XCTWaiter.wait(for: [landscape], timeout: 5) == .completed else {
            capture(probe, "tablet-orientation-unavailable")
            probe.terminate()
            throw XCTSkip("The tablet retained a portrait window after rotation; landscape is unverified")
        }
        probe.terminate()
        testLandscape = true
        testMathBoardAndBankFitWithoutScrolling()
        checkMathDrag(zone: "largeBottom")
        testFreeCellDragAndUndoWithVideo()
    }

    private func checkMathDrag(zone: String) {
        let app = open("Math Crossword", choices: ["Easy"], zone: zone)
        XCTAssertTrue(app.buttons["Show a Math Crossword hint"].waitForExistence(timeout: 40))
        app.buttons["Restart puzzle"].tap()
        app.buttons["Restart"].tap()
        let blank = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Blank number' AND value == 'empty'")).firstMatch
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Place '")).firstMatch
        XCTAssertTrue(blank.exists)
        XCTAssertTrue(tile.exists)
        let expected = String(tile.label.dropFirst("Place ".count))
        let cellIdentifier = blank.identifier
        let destination = blank.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: destination)
        let placed = app.buttons[cellIdentifier]
        XCTAssertEqual(placed.value as? String, expected)
        app.buttons["Undo last tile"].tap()
        XCTAssertEqual(placed.value as? String, "empty")
        let given = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Given number'")).firstMatch
        let originalGiven = given.value as? String
        tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: given.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        XCTAssertEqual(given.value as? String, originalGiven)
        XCTAssertEqual(placed.value as? String, "empty")
        capture(app, "math-dragged")
        app.terminate()
    }

    func testFreeCellDragAndUndoWithVideo() {
        for zone in ["largeTop", "smallBottomRight"] {
            let app = open("FreeCell", choices: ["Easy"], zone: zone)
            let column = app.buttons.matching(NSPredicate(format: "value == 'Column 1'"))
            guard let source = column.allElementsBoundByIndex.max(by: { $0.frame.minY < $1.frame.minY }) else {
                XCTFail("Expected a playable card in the first column")
                return
            }
            let cardLabel = source.label
            let destination = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Free cell ' AND value == 'Empty'")).firstMatch
            XCTAssertTrue(destination.exists)
            let cellLabel = destination.label
            source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                .press(forDuration: 0.05, thenDragTo: destination.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
            XCTAssertEqual(app.buttons[cellLabel].value as? String, cardLabel)
            app.buttons["Undo"].tap()
            XCTAssertEqual(app.buttons[cellLabel].value as? String, "Empty")
            capture(app, "FreeCell-drag-undo-" + zone)
            app.terminate()
        }
    }

    func testHintsLeaveCompleteBoardsVisible() {
        for (game, choices, hint) in [
            ("Minesweeper", ["Hard"], "Show a Minesweeper hint"),
            ("Nonogram", ["Free", "20×20"], "Show a Nonogram hint"),
            ("Sudoku", ["Free", "Hard"], "Show a Sudoku hint"),
            ("Math Crossword", ["Hard"], "Show a Math Crossword hint")
        ] {
            let app = open(game, choices: choices)
            XCTAssertTrue(app.buttons[hint].waitForExistence(timeout: 40))
            app.buttons[hint].tap()
            let card = app.otherElements["game-assist-card"]
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Dismiss hint"].isHittable)
            capture(app, game + "-hint-fit")
            let cardFrame = card.frame
            let lines = app.debugDescription.components(separatedBy: "\n").filter {
                $0.range(of: #"label: '(?:Given|Blank|Empty|Unrevealed|Flagged|Revealed|Notes|[0-9])"#, options: .regularExpression) != nil
                    && ($0.contains("row ") || $0.contains("Empty square"))
            }
            let frames = lines.compactMap(frame)
            XCTAssertGreaterThan(frames.count, 0)
            for rect in frames {
                XCTAssertFalse(cardFrame.intersects(rect.insetBy(dx: 1, dy: 1)), game + " hint overlaps cell at \(rect)")
            }
            app.buttons["Dismiss hint"].tap()
            app.terminate()
        }
    }

    func testMinesweeperToolsFit() {
        let app = open("Minesweeper", choices: ["Hard"])
        capture(app, "mines-hard-largeTop")
        for label in ["Back", "Restart game", "Show a Minesweeper hint"] {
            let button = app.buttons[label]
            XCTAssertTrue(button.exists, label)
            XCTAssertTrue(app.frame.contains(button.frame), label + " outside screen: \(button.frame)")
            XCTAssertTrue(button.isHittable, label)
        }
    }

    func testZAllGamesVideoZones() {
        let games: [(String, [String])] = [
            ("Minesweeper", ["Hard"]), ("Merge", ["2048"]),
            ("Nonogram", ["Free", "20×20"]), ("Sudoku", ["Free", "Hard"]),
            ("Solitaire", ["Easy"]), ("FreeCell", ["Easy"]),
            ("Five Letter", ["Unlimited"]), ("Word Grid", ["Relaxed"]),
            ("Stack", []), ("Snake", []), ("Math Crossword", ["Hard"])
        ]
        for zone in ["largeTop", "largeBottom", "smallTopLeft", "smallTopRight", "smallBottomLeft", "smallBottomRight"] {
            for (game, choices) in games {
                let app = open(game, choices: choices, zone: zone)
                if game == "Math Crossword" {
                    XCTAssertTrue(app.buttons["Show a Math Crossword hint"].waitForExistence(timeout: 40))
                }
                capture(app, game + "-" + zone)
                // One accessibility snapshot avoids hundreds of remote queries per board.
                let tree = app.debugDescription
                let bounds = app.frame.insetBy(dx: -1, dy: -1)
                var checkedButtons = 0
                for line in tree.components(separatedBy: "\n") where line.contains("Button,") && !line.contains("Disabled") {
                    guard let rect = frame(line), rect.width > 0, rect.height > 0 else { continue }
                    checkedButtons += 1
                    XCTAssertTrue(bounds.contains(rect), game + " " + zone + " " + line)
                }
                XCTAssertGreaterThan(checkedButtons, 0, game + " " + zone + " must check actual button bounds")
                app.terminate()
            }
        }
    }
    private func frame(_ line: String) -> CGRect? {
        let regex = try! NSRegularExpression(pattern: #"\{\{(-?[0-9.]+), (-?[0-9.]+)\}, \{([0-9.]+), ([0-9.]+)\}\}"#)
        let ns = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let values = (1...4).map { Double(ns.substring(with: match.range(at: $0)))! }
        return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

}
