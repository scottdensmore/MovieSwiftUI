//
//  EnvironmentKeys.swift
//  MovieSwift
//

import SwiftUI

private struct IsRunningUISmokeTestsKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ArchivedStateSizeDescriptionKey: EnvironmentKey {
    static let defaultValue: () -> String = { "0 KB" }
}

extension EnvironmentValues {
    var isRunningUISmokeTests: Bool {
        get { self[IsRunningUISmokeTestsKey.self] }
        set { self[IsRunningUISmokeTestsKey.self] = newValue }
    }

    var archivedStateSizeDescription: () -> String {
        get { self[ArchivedStateSizeDescriptionKey.self] }
        set { self[ArchivedStateSizeDescriptionKey.self] = newValue }
    }
}
