//  Thin FileDocument wrapper around exported user-data JSON so the
//  cross-platform `.fileExporter` modifier in SwiftUI can write it to
//  disk on macOS / iOS / tvOS without dropping into platform-specific
//  NSSavePanel / UIActivityViewController code.

import SwiftUI
import UniformTypeIdentifiers

struct UserDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let raw = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = raw
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
