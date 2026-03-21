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

        let moviesState = state.moviesState
        let peoplesState = state.peoplesState
        DispatchQueue.global().async {
            let movies = moviesState.movies.filter { (arg) -> Bool in
                let (key, _) = arg
                return moviesState.seenlist.contains(key) ||
                    moviesState.wishlist.contains(key) ||
                    moviesState.customLists.contains(where: { (_, value) -> Bool in
                        value.movies.contains(key) ||
                            value.cover == key
                    })
            }
            let people = peoplesState.peoples.filter { peoplesState.fanClub.contains($0.key) }
            var savingState = state
            savingState.moviesState.movies = movies
            savingState.peoplesState.peoples = people
            guard let data = try? encoder.encode(savingState) else {
                return
            }
            do {
                try data.write(to: resolvedSavePath)
            } catch let error {
                print("Error while saving app state :\(error)")
            }
        }
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
}
