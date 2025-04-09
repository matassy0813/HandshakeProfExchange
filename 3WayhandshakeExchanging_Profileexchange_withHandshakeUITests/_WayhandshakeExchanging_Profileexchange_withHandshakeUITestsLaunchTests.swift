//
//  _WayhandshakeExchanging_Profileexchange_withHandshakeUITestsLaunchTests.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshakeUITests
//
//  Created by 俣江悠聖 on 2025/04/09.
//

import XCTest

final class _WayhandshakeExchanging_Profileexchange_withHandshakeUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
