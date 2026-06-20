import Foundation
import MovieSwiftFluxCore

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

        if arguments.contains(UITestEnv.Argument.smokeTests)
            || environment[UITestEnv.Variable.smokeTests] == "1" {
            return .uiSmokeTests
        }
        #endif

        return .normal
    }
}
