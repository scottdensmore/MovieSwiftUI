import Foundation
#if canImport(MetricKit) && !os(tvOS)
    import MetricKit
#endif

#if canImport(MetricKit) && !os(tvOS)

    /// `nonisolated` + `@unchecked Sendable`: MetricKit invokes the subscriber
    /// callbacks on a background queue, so this must NOT be a `@MainActor` type.
    /// The project builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which
    /// would otherwise make this type — and its `didReceive` callbacks — implicitly
    /// main-actor-isolated; `@unchecked Sendable` alone does NOT opt out of that.
    /// A main-actor callback invoked off the main queue trips the Swift 6 runtime
    /// executor check and traps (`EXC_BREAKPOINT`) on the next launch that has a
    /// pending payload — a launch crash loop. `nonisolated` opts the whole type
    /// back out of main-actor isolation. Its only mutable state, `isObserving`, is
    /// touched solely by start/stop at app launch on the main thread; the
    /// `didReceive` callbacks just write files. We own that confinement, which makes
    /// the `shared` singleton safe to share.
    final nonisolated class MetricKitCrashReporter: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
        static let shared = MetricKitCrashReporter()

        private var isObserving = false

        // `isObserving` has no lock: the type is `nonisolated`, so the compiler
        // no longer proves these mutations happen on one actor. Both callers
        // (`HomeView.init` / `MovieSwiftMacApp.init`) run on the main actor, so
        // start/stop must continue to be called from the main actor only — the
        // `didReceive` callbacks (the part MetricKit delivers off-main) never
        // touch this flag.

        /// Subscribes to MetricKit. Idempotent — calling twice doesn't
        /// re-register. Call from the main actor (see note above).
        func startObserving() {
            guard !isObserving else { return }
            MXMetricManager.shared.add(self)
            isObserving = true
        }

        /// Unsubscribes. Useful for tests; production typically never
        /// stops observing.
        func stopObserving() {
            guard isObserving else { return }
            MXMetricManager.shared.remove(self)
            isObserving = false
        }

        // MARK: - MXMetricManagerSubscriber

        /// Daily aggregated metric payloads. Delivered roughly once per
        /// day per the framework contract.
        func didReceive(_ payloads: [MXMetricPayload]) {
            for payload in payloads {
                let data = payload.jsonRepresentation()
                guard !data.isEmpty else { continue }
                _ = try? CrashReportStore.writeToDefaultDirectory(payload: data, kind: .metric)
            }
        }

        /// Diagnostic payloads (crashes, hangs, CPU exceptions, disk
        /// write exceptions). (The old `@available(iOS 14, macOS 12)` gate is
        /// dropped — the app's deployment minimum is well past those.)
        func didReceive(_ payloads: [MXDiagnosticPayload]) {
            for payload in payloads {
                let data = payload.jsonRepresentation()
                guard !data.isEmpty else { continue }
                _ = try? CrashReportStore.writeToDefaultDirectory(payload: data, kind: .diagnostic)
            }
        }
    }

#else

    /// tvOS doesn't ship MetricKit. Provide an API-compatible stub so
    /// the app entry point can call `startObserving()` unconditionally
    /// without a platform branch at the call site.
    final class MetricKitCrashReporter: Sendable {
        static let shared = MetricKitCrashReporter()
        func startObserving() {}
        func stopObserving() {}
    }

#endif
