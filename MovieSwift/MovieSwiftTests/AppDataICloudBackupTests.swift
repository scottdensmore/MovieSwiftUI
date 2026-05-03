import XCTest
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

final class AppDataICloudBackupTests: XCTestCase {

    private var tempContainer: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Stand up a temp directory that mimics an iCloud container —
        // pure-logic helpers don't care that it's not iCloud-backed.
        tempContainer = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("AppDataICloudBackupTests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: tempContainer,
                                                withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempContainer {
            try? FileManager.default.removeItem(at: tempContainer)
        }
        tempContainer = nil
        try super.tearDownWithError()
    }

    private func makeMovie(id: Int) -> Movie {
        Movie(id: id,
              original_title: "Movie \(id)",
              title: "Movie \(id)",
              overview: "Overview",
              poster_path: nil,
              backdrop_path: nil,
              popularity: 0,
              vote_average: 0,
              vote_count: 0,
              release_date: nil,
              genres: nil,
              runtime: nil,
              status: nil,
              video: false,
              keywords: nil,
              images: nil,
              production_countries: nil,
              character: nil,
              department: nil)
    }

    // MARK: - URL composition

    func testBackupDirectoryAndFileURLLayout() {
        let dir = AppDataICloudBackup.backupDirectory(in: tempContainer)
        let file = AppDataICloudBackup.backupFileURL(in: tempContainer)

        XCTAssertEqual(dir.lastPathComponent, "Backups")
        XCTAssertEqual(dir.deletingLastPathComponent().lastPathComponent, "Documents")
        XCTAssertEqual(file.lastPathComponent, AppDataICloudBackup.backupFilename)
        XCTAssertEqual(file.deletingLastPathComponent(), dir)
    }

    // MARK: - Write

    func testWriteBackupCreatesIntermediateDirectoriesAndWritesEnvelope() throws {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.wishlist.insert(1)

        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)

        try AppDataICloudBackup.writeBackup(state: state, to: fileURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path),
                      "Backup file should exist after write")

        let data = try Data(contentsOf: fileURL)
        let decoded = try AppDataImport.decodeEnvelope(from: data)
        XCTAssertEqual(decoded.formatVersion, AppDataExportEnvelope.currentFormatVersion)
        XCTAssertTrue(decoded.snapshot.moviesState.wishlist.contains(1))
    }

    func testWriteBackupOverwritesPreviousBackup() throws {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)

        var firstState = AppState()
        firstState.moviesState.wishlist.insert(11)
        try AppDataICloudBackup.writeBackup(state: firstState, to: fileURL)

        var secondState = AppState()
        secondState.moviesState.wishlist.insert(22)
        try AppDataICloudBackup.writeBackup(state: secondState, to: fileURL)

        let envelope = try AppDataICloudBackup.readBackup(from: fileURL)
        XCTAssertFalse(envelope.snapshot.moviesState.wishlist.contains(11),
                       "Old backup data should not survive overwrite")
        XCTAssertTrue(envelope.snapshot.moviesState.wishlist.contains(22))
    }

    // MARK: - Read

    func testReadBackupRoundTripsTheWrittenEnvelope() throws {
        var state = AppState()
        state.moviesState.movies[5] = makeMovie(id: 5)
        state.moviesState.seenlist.insert(5)
        state.peoplesState.fanClub.insert(7)

        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        try AppDataICloudBackup.writeBackup(state: state, to: fileURL)

        let envelope = try AppDataICloudBackup.readBackup(from: fileURL)
        XCTAssertTrue(envelope.snapshot.moviesState.seenlist.contains(5))
        XCTAssertTrue(envelope.snapshot.peoplesState.fanClub.contains(7))
    }

    func testReadBackupThrowsNoBackupExistsWhenFileMissing() {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        XCTAssertThrowsError(try AppDataICloudBackup.readBackup(from: fileURL)) { error in
            guard case AppDataICloudBackup.BackupError.noBackupExists = error else {
                XCTFail("Expected noBackupExists, got \(error)")
                return
            }
        }
    }

    func testReadBackupWrapsCorruptDataInReadFailedError() throws {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("not actually json".utf8).write(to: fileURL)

        XCTAssertThrowsError(try AppDataICloudBackup.readBackup(from: fileURL)) { error in
            guard case AppDataICloudBackup.BackupError.readFailed = error else {
                XCTFail("Expected readFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - lastBackupDate

    func testLastBackupDateReturnsNilWhenFileMissing() {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        XCTAssertNil(AppDataICloudBackup.lastBackupDate(at: fileURL))
    }

    func testLastBackupDateReturnsModificationDate() throws {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        try AppDataICloudBackup.writeBackup(state: AppState(), to: fileURL)

        let modDate = AppDataICloudBackup.lastBackupDate(at: fileURL)
        XCTAssertNotNil(modDate)
        if let modDate {
            XCTAssertLessThan(abs(modDate.timeIntervalSinceNow), 5,
                              "Mod date should be within 5 seconds of now")
        }
    }
}
