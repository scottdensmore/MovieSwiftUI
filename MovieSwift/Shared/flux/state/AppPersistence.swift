import Foundation
import MovieSwiftFluxCore

nonisolated enum AppPersistence {
    // Resolved once, lazily and thread-safely — Swift guarantees atomic
    // `static let` initialization. Replaces a mutable `static var` cache
    // that the Swift 6 language mode rejects as non-concurrency-safe
    // global state.
    private static let savePath: URL? = try? resolvedSavePath()

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

    static func loadState() -> AppState? {
        guard let savePath = savePath,
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
        guard let resolvedSavePath = savePath else {
            return
        }

        DispatchQueue.global().async {
            write(state: AppStateCacheReset.persistentSnapshot(from: state), to: resolvedSavePath)
        }
    }

    static func archiveNow(state: AppState) {
        guard let resolvedSavePath = savePath else {
            return
        }

        write(state: AppStateCacheReset.persistentSnapshot(from: state), to: resolvedSavePath)
    }

    static func archivedStateSizeDescription() -> String {
        guard let resolvedSavePath = savePath else {
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
