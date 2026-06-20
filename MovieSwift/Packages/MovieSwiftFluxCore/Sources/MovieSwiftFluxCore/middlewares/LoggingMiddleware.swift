import Foundation
import Flux

public enum AppLoggingPolicy {
    static public func shouldEnableLogging(isRunningTests: Bool) -> Bool {
        !isRunningTests
    }
}

// `Flux.Middleware`'s outer closure is `@Sendable`, so this module-level
// `let` is concurrency-safe with no annotation: it captures nothing and is
// only invoked by the Store on the main actor during dispatch.
public let loggingMiddleware: Middleware<AppState> = { _, _ in
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
