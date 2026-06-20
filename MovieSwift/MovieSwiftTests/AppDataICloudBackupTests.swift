import Testing
import Foundation
import MovieSwiftFluxCore
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

// `.serialized` + final class: these tests perform iCloud-backup file
// I/O, and the class's init/deinit act as per-test setup/teardown to
// stand up and tear down a temp container directory.
@Suite(.serialized)
final class AppDataICloudBackupTests {

    private var tempContainer: URL!

    init() {
        // Stand up a temp directory that mimics an iCloud container —
        // pure-logic helpers don't care that it's not iCloud-backed.
        // Non-throwing init (best-effort `try?`): creating a uniquely-named
        // temp directory won't realistically fail, and keeping it
        // non-throwing means a problem surfaces in the specific @Test that
        // can't write rather than as an opaque suite-construction failure.
        tempContainer = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("AppDataICloudBackupTests-\(UUID().uuidString)",
                                    isDirectory: true)
        try? FileManager.default.createDirectory(at: tempContainer,
                                                 withIntermediateDirectories: true)
    }

    deinit {
        if let tempContainer {
            try? FileManager.default.removeItem(at: tempContainer)
        }
    }

    private func makeMovie(id: Int) -> Movie {
        Movie(id: id,
              originalTitle: "Movie \(id)",
              title: "Movie \(id)",
              overview: "Overview",
              posterPath: nil,
              backdropPath: nil,
              popularity: 0,
              voteAverage: 0,
              voteCount: 0,
              releaseDateString: nil,
              genres: nil,
              runtime: nil,
              status: nil,
              video: false,
              keywords: nil,
              images: nil,
              productionCountries: nil,
              character: nil,
              department: nil)
    }

    // MARK: - URL composition

    @Test func backupDirectoryAndFileURLLayout() {
        let dir = AppDataICloudBackup.backupDirectory(in: tempContainer)
        let file = AppDataICloudBackup.backupFileURL(in: tempContainer)

        #expect(dir.lastPathComponent == "Backups")
        #expect(dir.deletingLastPathComponent().lastPathComponent == "Documents")
        #expect(file.lastPathComponent == AppDataICloudBackup.backupFilename)
        #expect(file.deletingLastPathComponent() == dir)
    }

    // MARK: - Write

    @Test func writeBackupCreatesIntermediateDirectoriesAndWritesEnvelope() throws {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.wishlist.insert(1)

        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)

        try AppDataICloudBackup.writeBackup(state: state, to: fileURL)

        #expect(FileManager.default.fileExists(atPath: fileURL.path),
                "Backup file should exist after write")

        let data = try Data(contentsOf: fileURL)
        let decoded = try AppDataImport.decodeEnvelope(from: data)
        #expect(decoded.formatVersion == AppDataExportEnvelope.currentFormatVersion)
        #expect(decoded.snapshot.moviesState.wishlist.contains(1))
    }

    @Test func writeBackupOverwritesPreviousBackup() throws {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)

        var firstState = AppState()
        firstState.moviesState.wishlist.insert(11)
        try AppDataICloudBackup.writeBackup(state: firstState, to: fileURL)

        var secondState = AppState()
        secondState.moviesState.wishlist.insert(22)
        try AppDataICloudBackup.writeBackup(state: secondState, to: fileURL)

        let envelope = try AppDataICloudBackup.readBackup(from: fileURL)
        #expect(!(envelope.snapshot.moviesState.wishlist.contains(11)),
                "Old backup data should not survive overwrite")
        #expect(envelope.snapshot.moviesState.wishlist.contains(22))
    }

    // MARK: - Read

    @Test func readBackupRoundTripsTheWrittenEnvelope() throws {
        var state = AppState()
        state.moviesState.movies[5] = makeMovie(id: 5)
        state.moviesState.seenlist.insert(5)
        state.peoplesState.fanClub.insert(7)

        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        try AppDataICloudBackup.writeBackup(state: state, to: fileURL)

        let envelope = try AppDataICloudBackup.readBackup(from: fileURL)
        #expect(envelope.snapshot.moviesState.seenlist.contains(5))
        #expect(envelope.snapshot.peoplesState.fanClub.contains(7))
    }

    @Test func readBackupThrowsNoBackupExistsWhenFileMissing() {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        #expect(!(FileManager.default.fileExists(atPath: fileURL.path)))

        do {
            _ = try AppDataICloudBackup.readBackup(from: fileURL)
            Issue.record("Expected readBackup to throw noBackupExists")
        } catch {
            guard case AppDataICloudBackup.BackupError.noBackupExists = error else {
                Issue.record("Expected noBackupExists, got \(error)")
                return
            }
        }
    }

    @Test func readBackupWrapsCorruptDataInReadFailedError() throws {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("not actually json".utf8).write(to: fileURL)

        do {
            _ = try AppDataICloudBackup.readBackup(from: fileURL)
            Issue.record("Expected readBackup to throw readFailed")
        } catch {
            guard case AppDataICloudBackup.BackupError.readFailed = error else {
                Issue.record("Expected readFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - lastBackupDate

    @Test func lastBackupDateReturnsNilWhenFileMissing() {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        #expect(AppDataICloudBackup.lastBackupDate(at: fileURL) == nil)
    }

    @Test func lastBackupDateReturnsModificationDate() throws {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        try AppDataICloudBackup.writeBackup(state: AppState(), to: fileURL)

        let modDate = AppDataICloudBackup.lastBackupDate(at: fileURL)
        #expect(modDate != nil)
        if let modDate {
            #expect(abs(modDate.timeIntervalSinceNow) < 5,
                    "Mod date should be within 5 seconds of now")
        }
    }

    // MARK: - availableVersions
    //
    // NSFileVersion-backed iCloud version history can't be set up in
    // a unit test (it requires the iCloud file coordination
    // machinery). These tests cover what we can: the empty-file and
    // missing-file paths, and the shape of BackupVersionInfo for
    // freshly written non-iCloud files.

    @Test func availableVersionsReturnsEmptyWhenFileMissing() {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        #expect(!(FileManager.default.fileExists(atPath: fileURL.path)))
        #expect(AppDataICloudBackup.availableVersions(at: fileURL).isEmpty,
                "Missing file should produce no versions, not crash")
    }

    @Test func availableVersionsExposesCurrentVersionForLocalFile() throws {
        // For a local (non-iCloud) file NSFileVersion still returns
        // a "current" version with the file's modification date —
        // verify our wrapper surfaces it as isCurrent = true and
        // doesn't fabricate any conflict state.
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        try AppDataICloudBackup.writeBackup(state: AppState(), to: fileURL)

        let versions = AppDataICloudBackup.availableVersions(at: fileURL)
        #expect(versions.count >= 1,
                "A written file should yield at least one version")
        #expect(versions.contains { $0.isCurrent },
                "One version should be marked current")
        #expect(!(versions.contains { $0.isUnresolvedConflict }),
                "A freshly written local file shouldn't have unresolved conflicts")
    }

    @Test func readBackupAtVersionRoundTripsLocalFile() throws {
        let fileURL = AppDataICloudBackup.backupFileURL(in: tempContainer)
        var state = AppState()
        state.moviesState.wishlist.insert(42)
        try AppDataICloudBackup.writeBackup(state: state, to: fileURL)

        // Pick the "current" version and read through the
        // version-aware path. Should match what readBackup(from:)
        // would have returned.
        let versions = AppDataICloudBackup.availableVersions(at: fileURL)
        let current = try #require(versions.first(where: { $0.isCurrent }),
                                   "Expected a current version for the freshly written file")

        let envelope = try AppDataICloudBackup.readBackup(at: current.version)
        #expect(envelope.snapshot.moviesState.wishlist.contains(42),
                "Reading at a specific version should return the same data as reading the file directly")
    }
}
