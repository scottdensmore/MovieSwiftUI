//
//  AppLaunchMode.swift
//  MovieSwift
//

import Foundation

enum AppLaunchMode {
    case normal
    case uiSmokeTests
    case preview

    static func current(processInfo: ProcessInfo = .processInfo) -> AppLaunchMode {
        from(arguments: processInfo.arguments, environment: processInfo.environment)
    }

    static func from(arguments: [String], environment: [String: String]) -> AppLaunchMode {
        #if DEBUG
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return .preview
        }

        if arguments.contains("--ui-smoke-tests")
            || environment["UI_SMOKE_TESTS"] == "1" {
            return .uiSmokeTests
        }
        #endif

        return .normal
    }
}
