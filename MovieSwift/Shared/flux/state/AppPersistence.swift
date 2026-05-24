import Foundation
import MovieSwiftFluxCore

enum AppPersistence {
    private static var savePath: URL?

    private static func resolvedSavePath() throws -> URL {
        let icloudDirectory = FileManager.default.url(forUbiquityContainerIdentifier: nil)
        let documentDirectory = try FileManager.default.url(for: .documentDirectory,
                                                            in: .userDomainMask,
                                                            appropriateFor: nil,
                                                            create: false)
        if let icloudDirectory {
            try FileManager.default.startDownloadingUbiquitousItem(at: icloudDirectory)
        }

        return (icloudDirectory ?? documentDirectory).appendingPathComponent("userData")
    }

    private static func ensureSavePath() -> URL? {
        if let savePath {
            return savePath
        }

        do {
            let path = try resolvedSavePath()
            savePath = path
            return path
        } catch {
            return nil
        }
    }

    static func loadState() -> AppState? {
        guard let savePath = ensureSavePath(),
              let data = try? Data(contentsOf: savePath) else {
            return nil
        }
        do {
            var savedState = try AppStatePersistedFormat.decode(data: data)
            savedState.ensurePlaceholderData()
            return savedState
        } catch {
            // Same outcome as the legacy `try?` path on unrecoverable
            // files: log and let the app start with a fresh state.
            // Future-version files don't get auto-overwritten because
            // the next archive() will write a new envelope at the
            // current build's format version.
            #if DEBUG
            print("Error while loading app state: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    static func archive(state: AppState) {
        guard let resolvedSavePath = ensureSavePath() else {
            return
        }

        DispatchQueue.global().async {
            write(state: AppStateCacheReset.persistentSnapshot(from: state), to: resolvedSavePath)
        }
    }

    static func archiveNow(state: AppState) {
        guard let resolvedSavePath = ensureSavePath() else {
            return
        }

        write(state: AppStateCacheReset.persistentSnapshot(from: state), to: resolvedSavePath)
    }

    static func archivedStateSizeDescription() -> String {
        guard let resolvedSavePath = ensureSavePath() else {
            return "0 KB"
        }
        do {
            let resources = try resolvedSavePath.resourceValues(forKeys: [.fileSizeKey])
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = .useKB
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(resources.fileSize ?? 0))
        } catch {
            return "0"
        }
    }

    private static func write(state: AppState, to path: URL) {
        do {
            let data = try AppStatePersistedFormat.encode(state: state)
            try data.write(to: path)
        } catch let error {
            #if DEBUG
            print("Error while saving app state: \(error)")
            #endif
        }
    }
}
