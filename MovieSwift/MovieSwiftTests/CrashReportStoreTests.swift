import XCTest
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

final class CrashReportStoreTests: XCTestCase {

    private var tempContainer: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempContainer = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("CrashReportStoreTests-\(UUID().uuidString)",
                                    isDirectory: true)
        // Don't pre-create — `write` should create on demand.
    }

    override func tearDownWithError() throws {
        if let tempContainer {
            try? FileManager.default.removeItem(at: tempContainer)
        }
        tempContainer = nil
        try super.tearDownWithError()
    }

    // MARK: - Filename composition

    func testFilenameUsesUTCISODateAndKnownSuffix() {
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
        XCTAssertEqual(name, "diagnostic-2026-05-03-143007-abc12345.json")
    }

    func testFilenameDifferentiatesKinds() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let metric = CrashReportStore.filename(for: .metric, date: date, suffix: "x")
        let diagnostic = CrashReportStore.filename(for: .diagnostic, date: date, suffix: "x")

        XCTAssertTrue(metric.hasPrefix("metric-"))
        XCTAssertTrue(diagnostic.hasPrefix("diagnostic-"))
    }

    func testFilenamesWithSequentialDatesSortChronologically() {
        // Filenames are designed so alphabetical sort produces
        // chronological order. Verify with two dates a minute apart.
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        let later = Date(timeIntervalSince1970: 1_700_000_060)

        let a = CrashReportStore.filename(for: .diagnostic, date: earlier, suffix: "00000000")
        let b = CrashReportStore.filename(for: .diagnostic, date: later, suffix: "00000000")

        XCTAssertLessThan(a, b)
    }

    // MARK: - Default suffix

    func testDefaultSuffixIsEightCharacters() {
        // Stable length keeps filenames sorting cleanly even when
        // multiple payloads land in the same second.
        let suffix = CrashReportStore.defaultSuffix()
        XCTAssertEqual(suffix.count, 8)
    }

    // MARK: - Write

    func testWriteCreatesIntermediateDirectoriesAndStoresPayload() throws {
        let payload = Data("{\"hello\":\"world\"}".utf8)
        let url = try CrashReportStore.write(payload: payload,
                                              kind: .diagnostic,
                                              to: tempContainer,
                                              suffix: "deadbeef")

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempContainer.path),
                      "Write should have created the directory")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "Write should have created the payload file")

        let readBack = try Data(contentsOf: url)
        XCTAssertEqual(readBack, payload)
    }

    func testWriteWrapsUnderlyingErrorsInWriteFailed() {
        // Pointing the directory at a non-creatable location forces
        // a failure. /dev/null/foo isn't a valid URL we can create
        // a directory under, so write() should throw.
        let invalid = URL(fileURLWithPath: "/dev/null/CrashReportStoreTests/should-fail")

        XCTAssertThrowsError(
            try CrashReportStore.write(payload: Data(),
                                        kind: .diagnostic,
                                        to: invalid)
        ) { error in
            guard case CrashReportStore.WriteError.writeFailed = error else {
                XCTFail("Expected writeFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - List

    func testListReportsReturnsOnlyJSONFilesSortedAlphabetically() throws {
        try FileManager.default.createDirectory(at: tempContainer,
                                                withIntermediateDirectories: true)
        // Three valid reports + one stray non-JSON file that should
        // be filtered out.
        try Data().write(to: tempContainer.appendingPathComponent("metric-2026-05-03-100000-aaaaaaaa.json"))
        try Data().write(to: tempContainer.appendingPathComponent("diagnostic-2026-05-03-090000-bbbbbbbb.json"))
        try Data().write(to: tempContainer.appendingPathComponent("metric-2026-05-03-110000-cccccccc.json"))
        try Data().write(to: tempContainer.appendingPathComponent("README.txt"))

        let urls = CrashReportStore.listReports(in: tempContainer)
        XCTAssertEqual(urls.count, 3, "Non-JSON files should be filtered out")
        XCTAssertEqual(urls.map(\.lastPathComponent), [
            "diagnostic-2026-05-03-090000-bbbbbbbb.json",
            "metric-2026-05-03-100000-aaaaaaaa.json",
            "metric-2026-05-03-110000-cccccccc.json",
        ], "Listed reports must sort by filename, which sorts chronologically")
    }

    func testListReportsReturnsEmptyWhenDirectoryDoesNotExist() {
        // Brand-new install case: directory hasn't been created yet,
        // no payloads have been received. Should return [] cleanly
        // rather than throwing.
        let urls = CrashReportStore.listReports(in: tempContainer)
        XCTAssertEqual(urls, [])
    }

    // MARK: - End-to-end: write multiple, list back

    func testWriteThenListReturnsAllPayloadsInOrder() throws {
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

        XCTAssertEqual(names.count, 3)
        // diagnostic-...-1700000000... < metric-...-1700000000... < metric-...-1700001000...
        XCTAssertTrue(names[0].hasPrefix("diagnostic-"))
        XCTAssertTrue(names[1].hasPrefix("metric-"))
        XCTAssertLessThan(names[1], names[2])
    }

    // MARK: - Filename round-trip parsing

    func testParseKindAndDateRoundTripsFilenamesProducedByFilename() {
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
            XCTAssertNotNil(parsed)
            XCTAssertEqual(parsed?.kind, kind)
            XCTAssertEqual(parsed?.date, date,
                           "Round-trip date for \(kind) should match the input")
        }
    }

    func testParseKindAndDateReturnsNilForUnknownFilename() {
        XCTAssertNil(CrashReportStore.parseKindAndDate(fromFilename: "README.txt"))
        XCTAssertNil(CrashReportStore.parseKindAndDate(fromFilename: "metric.json"),
                     "Filenames missing the date components should not parse")
        XCTAssertNil(CrashReportStore.parseKindAndDate(fromFilename: "telemetry-2026-05-03-090000-deadbeef.json"),
                     "Unknown kinds should not parse")
    }

    // MARK: - listReportFiles

    func testListReportFilesReturnsMetadataNewestFirst() throws {
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
        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(files[0].date, latest)
        XCTAssertEqual(files[1].date, middle)
        XCTAssertEqual(files[2].date, earliest)
    }

    func testListReportFilesReturnsEmptyWhenDirectoryMissing() {
        // Brand-new install: directory hasn't been created yet,
        // viewer should render the empty state, not crash.
        let files = CrashReportStore.listReportFiles(in: tempContainer)
        XCTAssertEqual(files, [])
    }

    func testMetadataIncludesFileSize() throws {
        // The viewer shows "X KB" per row so the user has a rough
        // idea of how big a payload is before sharing. Verify
        // metadata reports the actual on-disk byte count.
        let payload = Data(repeating: 0x41, count: 1234)
        let url = try CrashReportStore.write(payload: payload,
                                              kind: .diagnostic,
                                              to: tempContainer,
                                              suffix: "deadbeef")

        let info = try XCTUnwrap(CrashReportStore.metadata(forReportAt: url))
        XCTAssertEqual(info.sizeBytes, 1234)
    }

    func testMetadataReturnsNilForUnparseableFilename() throws {
        try FileManager.default.createDirectory(at: tempContainer,
                                                withIntermediateDirectories: true)
        let bogus = tempContainer.appendingPathComponent("README.txt")
        try Data("hi".utf8).write(to: bogus)

        XCTAssertNil(CrashReportStore.metadata(forReportAt: bogus),
                     "Files that don't match the kind-date-suffix shape shouldn't appear in the viewer list")
    }
}
