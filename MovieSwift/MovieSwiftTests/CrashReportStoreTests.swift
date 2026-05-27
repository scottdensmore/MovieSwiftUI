import Testing
import Foundation
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

// `.serialized` + final class: these tests perform crash-report file
// I/O, and the class's init/deinit act as per-test setup/teardown to
// stand up and tear down a temp container directory.
@Suite(.serialized)
final class CrashReportStoreTests {

    private var tempContainer: URL!

    init() {
        tempContainer = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("CrashReportStoreTests-\(UUID().uuidString)",
                                    isDirectory: true)
        // Don't pre-create — `write` should create on demand.
    }

    deinit {
        if let tempContainer {
            try? FileManager.default.removeItem(at: tempContainer)
        }
    }

    // MARK: - Filename composition

    @Test func filenameUsesUTCISODateAndKnownSuffix() {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 3
        components.hour = 14
        components.minute = 30
        components.second = 7

        var calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC")!
        calendar.timeZone = utc
        let date = calendar.date(from: components)!

        let name = CrashReportStore.filename(for: .diagnostic,
                                             date: date,
                                             suffix: "abc12345",
                                             calendar: calendar,
                                             timeZone: utc)
        #expect(name == "diagnostic-2026-05-03-143007-abc12345.json")
    }

    @Test func filenameDifferentiatesKinds() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let metric = CrashReportStore.filename(for: .metric, date: date, suffix: "x")
        let diagnostic = CrashReportStore.filename(for: .diagnostic, date: date, suffix: "x")

        #expect(metric.hasPrefix("metric-"))
        #expect(diagnostic.hasPrefix("diagnostic-"))
    }

    @Test func filenamesWithSequentialDatesSortChronologically() {
        // Filenames are designed so alphabetical sort produces
        // chronological order. Verify with two dates a minute apart.
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        let later = Date(timeIntervalSince1970: 1_700_000_060)

        let a = CrashReportStore.filename(for: .diagnostic, date: earlier, suffix: "00000000")
        let b = CrashReportStore.filename(for: .diagnostic, date: later, suffix: "00000000")

        #expect(a < b)
    }

    // MARK: - Default suffix

    @Test func defaultSuffixIsEightCharacters() {
        // Stable length keeps filenames sorting cleanly even when
        // multiple payloads land in the same second.
        let suffix = CrashReportStore.defaultSuffix()
        #expect(suffix.count == 8)
    }

    // MARK: - Write

    @Test func writeCreatesIntermediateDirectoriesAndStoresPayload() throws {
        let payload = Data("{\"hello\":\"world\"}".utf8)
        let url = try CrashReportStore.write(payload: payload,
                                              kind: .diagnostic,
                                              to: tempContainer,
                                              suffix: "deadbeef")

        #expect(FileManager.default.fileExists(atPath: tempContainer.path),
                "Write should have created the directory")
        #expect(FileManager.default.fileExists(atPath: url.path),
                "Write should have created the payload file")

        let readBack = try Data(contentsOf: url)
        #expect(readBack == payload)
    }

    @Test func writeWrapsUnderlyingErrorsInWriteFailed() {
        // Pointing the directory at a non-creatable location forces
        // a failure. /dev/null/foo isn't a valid URL we can create
        // a directory under, so write() should throw.
        let invalid = URL(fileURLWithPath: "/dev/null/CrashReportStoreTests/should-fail")

        do {
            try CrashReportStore.write(payload: Data(),
                                        kind: .diagnostic,
                                        to: invalid)
            Issue.record("Expected write to throw writeFailed")
        } catch {
            guard case CrashReportStore.WriteError.writeFailed = error else {
                Issue.record("Expected writeFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - List

    @Test func listReportsReturnsOnlyJSONFilesSortedAlphabetically() throws {
        try FileManager.default.createDirectory(at: tempContainer,
                                                withIntermediateDirectories: true)
        // Three valid reports + one stray non-JSON file that should
        // be filtered out.
        try Data().write(to: tempContainer.appendingPathComponent("metric-2026-05-03-100000-aaaaaaaa.json"))
        try Data().write(to: tempContainer.appendingPathComponent("diagnostic-2026-05-03-090000-bbbbbbbb.json"))
        try Data().write(to: tempContainer.appendingPathComponent("metric-2026-05-03-110000-cccccccc.json"))
        try Data().write(to: tempContainer.appendingPathComponent("README.txt"))

        let urls = CrashReportStore.listReports(in: tempContainer)
        #expect(urls.count == 3, "Non-JSON files should be filtered out")
        #expect(urls.map(\.lastPathComponent) == [
            "diagnostic-2026-05-03-090000-bbbbbbbb.json",
            "metric-2026-05-03-100000-aaaaaaaa.json",
            "metric-2026-05-03-110000-cccccccc.json",
        ], "Listed reports must sort by filename, which sorts chronologically")
    }

    @Test func listReportsReturnsEmptyWhenDirectoryDoesNotExist() {
        // Brand-new install case: directory hasn't been created yet,
        // no payloads have been received. Should return [] cleanly
        // rather than throwing.
        let urls = CrashReportStore.listReports(in: tempContainer)
        #expect(urls == [])
    }

    // MARK: - End-to-end: write multiple, list back

    @Test func writeThenListReturnsAllPayloadsInOrder() throws {
        let payload = Data("{}".utf8)

        let earlierDate = Date(timeIntervalSince1970: 1_700_000_000)
        let laterDate = Date(timeIntervalSince1970: 1_700_001_000)

        try CrashReportStore.write(payload: payload, kind: .metric,
                                    to: tempContainer,
                                    date: laterDate,
                                    suffix: "cccccccc")
        try CrashReportStore.write(payload: payload, kind: .metric,
                                    to: tempContainer,
                                    date: earlierDate,
                                    suffix: "aaaaaaaa")
        try CrashReportStore.write(payload: payload, kind: .diagnostic,
                                    to: tempContainer,
                                    date: earlierDate,
                                    suffix: "bbbbbbbb")

        let urls = CrashReportStore.listReports(in: tempContainer)
        let names = urls.map(\.lastPathComponent)

        #expect(names.count == 3)
        // diagnostic-...-1700000000... < metric-...-1700000000... < metric-...-1700001000...
        #expect(names[0].hasPrefix("diagnostic-"))
        #expect(names[1].hasPrefix("metric-"))
        #expect(names[1] < names[2])
    }

    // MARK: - Filename round-trip parsing

    @Test func parseKindAndDateRoundTripsFilenamesProducedByFilename() {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 3
        components.hour = 9
        components.minute = 41
        components.second = 27

        var calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC")!
        calendar.timeZone = utc
        let date = calendar.date(from: components)!

        for kind: CrashReportKind in [.metric, .diagnostic] {
            let name = CrashReportStore.filename(for: kind,
                                                  date: date,
                                                  suffix: "deadbeef",
                                                  calendar: calendar,
                                                  timeZone: utc)
            let parsed = CrashReportStore.parseKindAndDate(fromFilename: name,
                                                            calendar: calendar,
                                                            timeZone: utc)
            #expect(parsed != nil)
            #expect(parsed?.kind == kind)
            #expect(parsed?.date == date,
                    "Round-trip date for \(kind) should match the input")
        }
    }

    @Test func parseKindAndDateReturnsNilForUnknownFilename() {
        #expect(CrashReportStore.parseKindAndDate(fromFilename: "README.txt") == nil)
        #expect(CrashReportStore.parseKindAndDate(fromFilename: "metric.json") == nil,
                "Filenames missing the date components should not parse")
        #expect(CrashReportStore.parseKindAndDate(fromFilename: "telemetry-2026-05-03-090000-deadbeef.json") == nil,
                "Unknown kinds should not parse")
    }

    // MARK: - listReportFiles

    @Test func listReportFilesReturnsMetadataNewestFirst() throws {
        // Three reports written at known different dates. The
        // listing helper should return them newest-first (the
        // filename-sorted order is reversed for date-desc).
        let payload = Data("{}".utf8)
        let earliest = Date(timeIntervalSince1970: 1_700_000_000)
        let middle = Date(timeIntervalSince1970: 1_700_000_500)
        let latest = Date(timeIntervalSince1970: 1_700_001_000)

        try CrashReportStore.write(payload: payload, kind: .diagnostic,
                                    to: tempContainer,
                                    date: middle,
                                    suffix: "bbbbbbbb")
        try CrashReportStore.write(payload: payload, kind: .metric,
                                    to: tempContainer,
                                    date: latest,
                                    suffix: "cccccccc")
        try CrashReportStore.write(payload: payload, kind: .metric,
                                    to: tempContainer,
                                    date: earliest,
                                    suffix: "aaaaaaaa")

        let files = CrashReportStore.listReportFiles(in: tempContainer)
        #expect(files.count == 3)
        #expect(files[0].date == latest)
        #expect(files[1].date == middle)
        #expect(files[2].date == earliest)
    }

    @Test func listReportFilesReturnsEmptyWhenDirectoryMissing() {
        // Brand-new install: directory hasn't been created yet,
        // viewer should render the empty state, not crash.
        let files = CrashReportStore.listReportFiles(in: tempContainer)
        #expect(files == [])
    }

    @Test func metadataIncludesFileSize() throws {
        // The viewer shows "X KB" per row so the user has a rough
        // idea of how big a payload is before sharing. Verify
        // metadata reports the actual on-disk byte count.
        let payload = Data(repeating: 0x41, count: 1234)
        let url = try CrashReportStore.write(payload: payload,
                                              kind: .diagnostic,
                                              to: tempContainer,
                                              suffix: "deadbeef")

        let info = try #require(CrashReportStore.metadata(forReportAt: url))
        #expect(info.sizeBytes == 1234)
    }

    @Test func metadataReturnsNilForUnparseableFilename() throws {
        try FileManager.default.createDirectory(at: tempContainer,
                                                withIntermediateDirectories: true)
        let bogus = tempContainer.appendingPathComponent("README.txt")
        try Data("hi".utf8).write(to: bogus)

        #expect(CrashReportStore.metadata(forReportAt: bogus) == nil,
                "Files that don't match the kind-date-suffix shape shouldn't appear in the viewer list")
    }
}
