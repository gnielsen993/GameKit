//
//  gamekitUITests.swift
//  gamekitUITests
//
//  Created by Gabriel Nielsen on 4/24/26.
//

import XCTest

final class gamekitUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testFreshLaunchRoutesIntoOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--fresh-launch"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Make it yours"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReturningLaunchRoutesIntoHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-launch"]
        app.launch()

        XCTAssertTrue(app.navigationBars["The Drawer"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDelayedStartupShowsProgressFeedback() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-launch", "--launch-entry-delay"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["startup-progress"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["The Drawer"].waitForExistence(timeout: 7))
    }

    @MainActor
    func testStartupFailureOffersRetryRecovery() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--launch-entry-failure"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["startup-recovery"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Try opening GameDrawer again"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
