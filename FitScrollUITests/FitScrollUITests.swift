import XCTest

final class FitScrollUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testOnboardingFlowIsPresented() {
        // On first launch, onboarding should be visible
        let welcomeText = app.staticTexts["Welcome to FitScroll"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5))
    }

    func testOnboardingCanNavigatePages() {
        let nextButton = app.buttons["Next"]
        if nextButton.waitForExistence(timeout: 5) {
            nextButton.tap()
            // Should move to next page
            let selectAppsText = app.staticTexts["Select Apps"]
            XCTAssertTrue(selectAppsText.waitForExistence(timeout: 3))
        }
    }

    func testOnboardingCompletesToDashboard() {
        // Tap through all onboarding pages
        let nextButton = app.buttons["Next"]
        for _ in 0..<3 {
            if nextButton.waitForExistence(timeout: 3) {
                nextButton.tap()
            }
        }

        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 3) {
            getStartedButton.tap()
        }

        // Dashboard should appear
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))
    }

    func testDashboardShowsUnlockButton() {
        completeOnboardingIfNeeded()

        let unlockButton = app.buttons["Unlock with Exercise"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 5))
    }

    func testSettingsTabExists() {
        completeOnboardingIfNeeded()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3))
    }

    func testHistoryTabExists() {
        completeOnboardingIfNeeded()

        let historyTab = app.tabBars.buttons["Workout History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
    }

    // MARK: - Helpers

    private func completeOnboardingIfNeeded() {
        let nextButton = app.buttons["Next"]
        if nextButton.waitForExistence(timeout: 2) {
            for _ in 0..<3 {
                if nextButton.exists {
                    nextButton.tap()
                }
            }
            let getStarted = app.buttons["Get Started"]
            if getStarted.waitForExistence(timeout: 2) {
                getStarted.tap()
            }
        }
    }
}
