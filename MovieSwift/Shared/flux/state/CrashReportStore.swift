//
//  CrashReportStore.swift
//  MovieSwift
//
//  On-device persistence for MetricKit crash + metric payloads.
//
//  Pure logic so the directory composition, write behaviour, and
//  filename format can be unit-tested with a temp directory. The
//  MetricKit subscriber (`MetricKitCrashReporter`) wires to the
//  production helpers; tests pass an explicit directory.
//
//  Files land at <Documents>/CrashReports/<kind>-<UTC-date>-<short-uuid>.json
//  so:
//   - Sorting alphabetically also sorts chronologically.
//   - The user can find them by their app container in Files.app
//     (iOS) or via Xcode > Devices and Simulators > Download
//     Container (iOS device) / ~/Library/Containers/<bundle>/...
//     (macOS sandbox).
//

import Foundation

enum CrashReportKind: String {
    case diagnostic
    case metric
}

enum CrashReportStore {

    enum WriteError: LocalizedError {
        case directoryUnavailable
        case writeFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .directoryUnavailable:
                return "Couldn't resolve the Documents directory for crash reports."
            case .writeFailed(let underlying):
                return "Couldn't write crash report: \(underlying.localizedDescription)"
            }
        }
    }

    /// Resolves the on-device directory used to store crash reports.
    /// Returns nil only when the user-domain Documents directory
    /// can't be resolved at all (very rare in practice).
    static func resolvedDirectory(fileManager: FileManager = .default) -> URL? {
        guard let docs = try? fileManager.url(for: .documentDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: false) else {
            return nil
        }
        return docs.appendingPathComponent("CrashReports", isDirectory: true)
    }

    // MARK: - Filename composition

    /// Composes a filename for a payload. Combines kind, ISO-style
    /// UTC timestamp, and a short suffix for uniqueness so two
    /// payloads delivered in the same second don't collide. Sorts
    /// alphabetically === chronologically because the timestamp is
    /// fixed-width.
    static func filename(for kind: CrashReportKind,
                         date: Date,
                         suffix: String,
                         calendar: Calendar = .init(identifier: .gregorian),
                         timeZone: TimeZone = TimeZone(secondsFromGMT: 0) ?? .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let stamp = formatter.string(from: date)
        return "\(kind.rawValue)-\(stamp)-\(suffix).json"
    }

    /// Default short suffix: 8 hex characters from a UUID. Stable in
    /// length so filenames sort cleanly.
    static func defaultSuffix() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))
    }

    // MARK: - Write

    /// Writes a payload into `directory`. Creates intermediate
    /// directories. Returns the URL the payload was written to.
    @discardableResult
    static func write(payload: Data,
                      kind: CrashReportKind,
                      to directory: URL,
                      date: Date = Date(),
                      suffix: String = defaultSuffix(),
                      fileManager: FileManager = .default) throws -> URL {
        do {
            try fileManager.createDirectory(at: directory,
                                            withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(
                filename(for: kind, date: date, suffix: suffix)
            )
            try payload.write(to: url, options: [.atomic])
            return url
        } catch {
            throw WriteError.writeFailed(underlying: error)
        }
    }

    /// Production convenience: writes to the resolved Documents
    /// directory. Throws `directoryUnavailable` when there's no
    /// Documents directory.
    @discardableResult
    static func writeToDefaultDirectory(payload: Data,
                                        kind: CrashReportKind,
                                        date: Date = Date(),
                                        fileManager: FileManager = .default) throws -> URL {
        guard let directory = resolvedDirectory(fileManager: fileManager) else {
            throw WriteError.directoryUnavailable
        }
        return try write(payload: payload,
                         kind: kind,
                         to: directory,
                         date: date,
                         fileManager: fileManager)
    }

    // MARK: - List

    /// Lists URLs of stored reports in `directory`, sorted by
    /// filename (chronologically given the fixed timestamp prefix).
    /// Returns empty when the directory doesn't exist yet — that's
    /// the normal "no reports captured yet" case.
    static func listReports(in directory: URL,
                            fileManager: FileManager = .default) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return contents
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Production convenience: lists from the resolved directory.
    static func listReportsInDefaultDirectory(fileManager: FileManager = .default) -> [URL] {
        guard let directory = resolvedDirectory(fileManager: fileManager) else {
            return []
        }
        return listReports(in: directory, fileManager: fileManager)
    }

    /// Returns the count of stored reports. Convenience for
    /// surfacing in the Settings UI.
    static func countOfStoredReports(fileManager: FileManager = .default) -> Int {
        listReportsInDefaultDirectory(fileManager: fileManager).count
    }
}
