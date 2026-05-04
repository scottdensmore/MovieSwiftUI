//
//  MetricKitCrashReporter.swift
//  MovieSwift
//
//  Apple-native crash reporting via MetricKit. No third-party SDK,
//  no transmission — payloads are written to <Documents>/CrashReports/
//  for local inspection.
//
//  Hook in once at app launch by calling
//  `MetricKitCrashReporter.shared.startObserving()`. The reporter
//  retains itself as a long-lived singleton because MetricKit
//  doesn't retain its subscribers, and we want delivery whenever it
//  happens (typically up to once per ~24 hours, often when the app
//  is re-opened after a crash).
//
//  MetricKit isn't available on tvOS. The code paths here compile
//  to a no-op there so the app entry point doesn't need a platform
//  branch.
//

import Foundation
#if canImport(MetricKit) && !os(tvOS)
import MetricKit
#endif

#if canImport(MetricKit) && !os(tvOS)

final class MetricKitCrashReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricKitCrashReporter()

    private var isObserving = false

    /// Subscribes to MetricKit. Idempotent — calling twice doesn't
    /// re-register.
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
            try? CrashReportStore.writeToDefaultDirectory(payload: data, kind: .metric)
        }
    }

    /// Diagnostic payloads (crashes, hangs, CPU exceptions, disk
    /// write exceptions). Available since iOS 14 / macOS 12.
    @available(iOS 14.0, macOS 12.0, *)
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let data = payload.jsonRepresentation()
            guard !data.isEmpty else { continue }
            try? CrashReportStore.writeToDefaultDirectory(payload: data, kind: .diagnostic)
        }
    }
}

#else

/// tvOS doesn't ship MetricKit. Provide an API-compatible stub so
/// the app entry point can call `startObserving()` unconditionally
/// without a platform branch at the call site.
final class MetricKitCrashReporter {
    static let shared = MetricKitCrashReporter()
    func startObserving() {}
    func stopObserving() {}
}

#endif
