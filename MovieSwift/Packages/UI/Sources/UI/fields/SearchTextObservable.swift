//
//  SearchTextBinding.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 09/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Combine

open class SearchTextObservable: ObservableObject {
    @Published public var searchText = "" {
        willSet {
            // Forward raw changes immediately for anyone observing the subject
            searchSubject.send(newValue)
        }
        didSet {
            onUpdateText(text: searchText)
        }
    }

    public let searchSubject = PassthroughSubject<String, Never>()

    // Store all subscriptions here to ensure proper lifetime management
    private var cancellables = Set<AnyCancellable>()

    deinit {
        // Not strictly necessary because AnyCancellable in the set cancels on deinit,
        // but explicit for clarity
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    public init() {
        // Debounced, distinct, non-empty search text
        searchSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .sink { [weak self] searchText in
                self?.onUpdateTextDebounced(text: searchText)
            }
            .store(in: &cancellables)
    }

    open func onUpdateText(text: String) {
        /// Overwrite by your subclass to get instant text update.
    }

    open func onUpdateTextDebounced(text: String) {
        /// Overwrite by your subclass to get debounced text update.
    }
}
