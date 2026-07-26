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

    /// Post-team-transfer regression (ITMS-90076, 2026-07): the App ID
    /// prefix moved JCWX4BK8GW -> ATRCA5V7ZV, which orphans the Keychain
    /// row holding the Sign in with Apple userID while UserDefaults —
    /// including `gamekit.cloudSyncEnabled` — survives the update. That
    /// leaves updating users on `isSignedIn == false` with CloudKit still
    /// syncing. Gating the SYNC rows on `isSignedIn` alone hid in-app
    /// sign-out AND delete-account (App Store 5.1.1(v)) in exactly that
    /// state; `SettingsSyncSection.canManageCloudAccount` gates on the
    /// live cloud store instead.
    ///
    /// The `-gamekit.cloudSyncEnabled YES` pair lands in UserDefaults'
    /// argument domain (highest precedence), so this reproduces the
    /// desync without a production launch-argument seam: flag on, no
    /// Keychain userID.
    @MainActor
    func testSyncManagementRowsSurviveOrphanedKeychainUserID() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--returning-launch",
            "-gamekit.cloudSyncEnabled", "YES"
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["The Drawer"].waitForExistence(timeout: 10))
        app.buttons["Profile"].tap()
        app.buttons["Settings"].tap()

        // Signed-out surface is still correct — the button is how the user
        // re-establishes a userID under the new team prefix.
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))

        // ...and the account-management rows must be reachable anyway.
        let signOut = app.buttons["Sign out of iCloud"]
        let deleteAccount = app.buttons["Delete account and iCloud data"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 5))
        XCTAssertTrue(deleteAccount.exists)

        // Reachable, not merely present in the tree.
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(signOut.isHittable)
        XCTAssertTrue(deleteAccount.isHittable)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
