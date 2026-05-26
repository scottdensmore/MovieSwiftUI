import Foundation
import SwiftUIFlux

public enum AppLoggingPolicy {
    static public func shouldEnableLogging(isRunningTests: Bool) -> Bool {
        !isRunningTests
    }
}

// `nonisolated(unsafe)`: `Middleware` is a SwiftUIFlux function type and
// therefore not `Sendable`, but this is an immutable `let` created once
// and only ever invoked by the Store on the main thread during dispatch.
nonisolated(unsafe) public let loggingMiddleware: Middleware<AppState> = { dispatch, getState in
    return { next in
        return { action in
            #if DEBUG
            let name = __dispatch_queue_get_label(nil)
            let queueName = String(cString: name, encoding: .utf8)
            print("#Action: \(String(reflecting: type(of: action))) on queue: \(queueName ?? "??")")
            #endif
            return next(action)
        }
    }
}
