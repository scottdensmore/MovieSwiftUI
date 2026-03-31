//
//  UITestHelpers.swift
//  MovieSwiftUITests
//
//  Shared UI test utilities used across iOS, macOS, and tvOS UI test targets.
//

import XCTest

// MARK: - Common Constants

enum UITestConstants {
    static let uiWaitTimeout: TimeInterval = 15
    static let smokeTestArguments = ["-ApplePersistenceIgnoreState", "YES", "--ui-smoke-tests"]
    static let smokeTestEnvironment = ["UI_SMOKE_TESTS": "1"]
}

// MARK: - App Launch

extension XCUIApplication {
    @discardableResult
    static func launchForTesting(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = UITestConstants.smokeTestArguments
        for (key, value) in UITestConstants.smokeTestEnvironment {
            app.launchEnvironment[key] = value
        }
        for (key, value) in environment {
            app.launchEnvironment[key] = value
        }
        app.launch()
        return app
    }
}

// MARK: - Element Finders

extension XCUIApplication {
    func identifiedElement(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func labeledElement(_ label: String) -> XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
    }

    func identifiedButton(_ identifierOrLabel: String) -> XCUIElement {
        let identifiedButton = buttons[identifierOrLabel]
        if identifiedButton.waitForExistence(timeout: 0.5) {
            return identifiedButton
        }
        return buttons.matching(NSPredicate(format: "label == %@", identifierOrLabel)).firstMatch
    }

    func scrollUntilVisible(_ element: XCUIElement, maxSwipes: Int = 6) -> Bool {
        if element.waitForExistence(timeout: 1) {
            return true
        }
        for _ in 0..<maxSwipes {
            #if os(tvOS)
            XCUIRemote.shared.press(.down)
            #else
            swipeUp()
            #endif
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }
        return false
    }
}

// MARK: - Debug Helpers

/// Logs the app hierarchy when an element is missing. Available as a free function
/// to avoid conflicts with per-class overrides.
func logHierarchyOnMissing(_ app: XCUIApplication, element: XCUIElement, named name: String) {
    let shouldLog = ProcessInfo.processInfo.environment["UI_TEST_LOG_HIERARCHY"] == "1"
    if shouldLog && !element.exists {
        print("Missing element: \(name)")
        print(app.debugDescription)
    }
}
