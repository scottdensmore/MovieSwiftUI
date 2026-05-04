//
//  AppDataICloudBackup.swift
//  MovieSwift
//
//  Reads and writes a single rolling backup of the user's data to
//  iCloud Drive. Reuses AppDataExport's envelope format so a backup
//  is just an export saved to a known iCloud path; restore reuses
//  AppDataImport's merge semantics. The file lives at
//
//      <iCloudContainer>/Documents/Backups/MovieSwift-Latest.json
//
//  so it shows up under the user's iCloud Drive in Files.app and is
//  automatically synced across devices that share the iCloud account.
//

import Foundation

enum AppDataICloudBackup {

    /// Errors surfaced by Backup/Restore operations.
    enum BackupError: LocalizedError {
        case iCloudUnavailable
        case noBackupExists
        case writeFailed(underlying: Error)
        case readFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable:
                return String(localized: "iCloud Drive is not available. Sign in to iCloud in System Settings and enable iCloud Drive for MovieSwift.",
                              comment: "Error shown when the user taps Back up to iCloud or Restore from iCloud but iCloud Drive isn't set up.")
            case .noBackupExists:
                return String(localized: "No iCloud backup exists yet. Tap Back up to iCloud first.",
                              comment: "Error shown when the user taps Restore from iCloud before any backup has been made.")
            case .writeFailed(let error):
                return String(localized: "Couldn't write the backup: \(error.localizedDescription)",
                              comment: "Error shown when the iCloud Drive write of a backup file fails. The interpolated value is the underlying system error.")
            case .readFailed(let error):
                return String(localized: "Couldn't read the backup: \(error.localizedDescription)",
                              comment: "Error shown when the iCloud Drive read of a backup file fails. The interpolated value is the underlying system error.")
            }
        }
    }

    /// Filename of the rolling backup. A single file is overwritten
    /// on each Back up — the goal is "latest known good", not a
    /// versioned history.
    static let backupFilename = "MovieSwift-Latest.json"

    // MARK: - URL helpers (testable; take an explicit container)

    /// Directory inside the given iCloud container where backups live.
    /// `Documents/` is the conventional public-facing slot — files
    /// there appear in the user's iCloud Drive in Files.app.
    static func backupDirectory(in container: URL) -> URL {
        container
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
    }

    /// Path of the rolling backup file inside the given container.
    static func backupFileURL(in container: URL) -> URL {
        backupDirectory(in: container).appendingPathComponent(backupFilename)
    }

    // MARK: - URL helpers (production; resolve real iCloud)

    /// Resolved iCloud container URL, or nil when iCloud Drive isn't
    /// available (no signed-in iCloud account, the user disabled
    /// iCloud Drive for the app, or the container isn't provisioned).
    static func resolvedICloudContainer(fileManager: FileManager = .default) -> URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)
    }

    /// Production helper that resolves the iCloud container then
    /// returns the rolling backup URL inside it. Returns nil when
    /// iCloud is unavailable.
    static func resolvedBackupFileURL(fileManager: FileManager = .default) -> URL? {
        resolvedICloudContainer(fileManager: fileManager).map(backupFileURL(in:))
    }

    /// Whether iCloud Drive can be used for backup right now.
    static func isICloudAvailable(fileManager: FileManager = .default) -> Bool {
        resolvedICloudContainer(fileManager: fileManager) != nil
    }

    // MARK: - Reading the last-backup date

    /// Modification date of the backup file at `fileURL`, or nil when
    /// the file isn't present.
    static func lastBackupDate(at fileURL: URL,
                               fileManager: FileManager = .default) -> Date? {
        guard fileManager.fileExists(atPath: fileURL.path),
              let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return nil
        }
        return modDate
    }

    /// Production convenience: returns the iCloud backup's last-modified
    /// date, or nil when iCloud is unavailable or no backup exists.
    static func resolvedLastBackupDate(fileManager: FileManager = .default) -> Date? {
        guard let url = resolvedBackupFileURL(fileManager: fileManager) else {
            return nil
        }
        return lastBackupDate(at: url, fileManager: fileManager)
    }

    // MARK: - Write

    /// Writes the export envelope of `state` to `fileURL`. Creates
    /// any missing intermediate directories. Re-throws decode/IO
    /// failures wrapped in `BackupError.writeFailed`.
    static func writeBackup(state: AppState,
                            to fileURL: URL,
                            date: Date = Date(),
                            fileManager: FileManager = .default) throws {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory,
                                            withIntermediateDirectories: true)
            let envelope = AppDataExport.envelope(from: state, exportDate: date)
            let data = try AppDataExport.data(from: envelope)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw BackupError.writeFailed(underlying: error)
        }
    }

    /// Production convenience: resolves the iCloud container and
    /// writes there. Throws `iCloudUnavailable` if there's no
    /// container.
    static func writeBackupToICloud(state: AppState,
                                    date: Date = Date(),
                                    fileManager: FileManager = .default) throws {
        guard let url = resolvedBackupFileURL(fileManager: fileManager) else {
            throw BackupError.iCloudUnavailable
        }
        try writeBackup(state: state, to: url, date: date, fileManager: fileManager)
    }

    // MARK: - Read

    /// Reads and decodes the backup envelope at `fileURL`. Throws
    /// `noBackupExists` if the file isn't present, or a wrapped
    /// `readFailed` for any other failure.
    static func readBackup(from fileURL: URL,
                           fileManager: FileManager = .default) throws -> AppDataExportEnvelope {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw BackupError.noBackupExists
        }
        // If the file is in iCloud and not yet downloaded, ask iCloud
        // to start downloading it. `Data(contentsOf:)` then waits on
        // the materialized file. On a non-iCloud URL this is a no-op.
        try? fileManager.startDownloadingUbiquitousItem(at: fileURL)
        do {
            let data = try Data(contentsOf: fileURL)
            return try AppDataImport.decodeEnvelope(from: data)
        } catch let error as AppDataImport.ImportError {
            // Decode-side errors carry their own user-facing message;
            // forward them as readFailed so the caller surfaces a
            // single error type.
            throw BackupError.readFailed(underlying: error)
        } catch {
            throw BackupError.readFailed(underlying: error)
        }
    }

    /// Production convenience: resolves the iCloud container and
    /// reads from there. Throws `iCloudUnavailable` if there's no
    /// container.
    static func readBackupFromICloud(fileManager: FileManager = .default) throws -> AppDataExportEnvelope {
        guard let url = resolvedBackupFileURL(fileManager: fileManager) else {
            throw BackupError.iCloudUnavailable
        }
        return try readBackup(from: url, fileManager: fileManager)
    }
}
