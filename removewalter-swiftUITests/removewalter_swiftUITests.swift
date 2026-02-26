//
//  removewalter_swiftUITests.swift
//  removewalter-swiftUITests
//
//  Created by wenhao on 2026/2/25.
//

import XCTest

final class removewalter_swiftUITests: XCTestCase {

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
    func testExtractButtonRequiresConsentAndValidLink() throws {
        let app = XCUIApplication()
        app.launch()

        let extractButton = app.buttons["extract_button"]
        XCTAssertTrue(extractButton.waitForExistence(timeout: 5))
        XCTAssertFalse(extractButton.isEnabled)

        let linkInput = app.textFields["link_input"]
        XCTAssertTrue(linkInput.waitForExistence(timeout: 3))
        linkInput.tap()
        linkInput.typeText("https://example.com/video")

        let consentToggle = app.switches["consent_toggle"]
        XCTAssertTrue(consentToggle.waitForExistence(timeout: 3))
        consentToggle.tap()

        let usageRulesToggle = app.switches["usage_rules_toggle"]
        XCTAssertTrue(usageRulesToggle.waitForExistence(timeout: 3))
        usageRulesToggle.tap()

        XCTAssertTrue(extractButton.isEnabled)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
