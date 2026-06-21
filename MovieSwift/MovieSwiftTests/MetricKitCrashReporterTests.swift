import Foundation
import Testing
#if canImport(MetricKit) && !os(tvOS)
    import MetricKit
#endif
#if os(tvOS)
    @testable import MovieSwiftTV
#elseif os(macOS)
    @testable import Film_O_Matic
#else
    @testable import MovieSwift
#endif

#if canImport(MetricKit) && !os(tvOS)
    /// Guards the launch crash where MetricKit delivered diagnostic payloads on a
    /// background queue into a main-actor-isolated subscriber callback.
    ///
    /// The project builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so
    /// `MetricKitCrashReporter` (and its `didReceive` callbacks) were implicitly
    /// `@MainActor` despite the `@unchecked Sendable` annotation. MetricKit invokes
    /// `didReceiveDiagnosticPayloads:` on a background queue, so under Swift 6 the
    /// runtime executor check tripped and trapped (`EXC_BREAKPOINT`) on every launch
    /// that had a pending diagnostic — a crash loop that never reached the UI.
    ///
    /// This pins the contract structurally: the callback must be invocable
    /// synchronously from a background (nonisolated) context. If the type ever
    /// regresses to main-actor isolation this call no longer compiles — the failure
    /// surfaces at build time instead of as a launch crash on a user's machine.
    struct MetricKitCrashReporterTests {
        @Test func subscriberCallbacksRunOffTheMainActor() async {
            let reporter = MetricKitCrashReporter.shared
            await withCheckedContinuation { continuation in
                // `DispatchQueue` (not `Task.detached`) is intentional: it mirrors
                // MetricKit's Objective-C GCD delivery, which is the exact path that
                // crashed. Both subscriber overloads have the same off-main
                // exposure, so cover both. Empty arrays exercise the isolation
                // boundary without needing a (non-publicly-constructible) payload.
                DispatchQueue.global(qos: .utility).async {
                    reporter.didReceive([] as [MXDiagnosticPayload])
                    reporter.didReceive([] as [MXMetricPayload])
                    continuation.resume()
                }
            }
        }
    }
#endif
