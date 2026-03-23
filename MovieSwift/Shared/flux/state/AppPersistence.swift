//
//  AppPersistence.swift
//  MovieSwift
//

import Foundation

enum AppPersistence {
    private static var savePath: URL?
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

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
              let data = try? Data(contentsOf: savePath),
              var savedState = try? decoder.decode(AppState.self, from: data) else {
            return nil
        }

        savedState.ensurePlaceholderData()
        return savedState
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
        guard let data = try? encoder.encode(state) else {
            return
        }
        do {
            try data.write(to: path)
        } catch let error {
            print("Error while saving app state :\(error)")
        }
    }
}
