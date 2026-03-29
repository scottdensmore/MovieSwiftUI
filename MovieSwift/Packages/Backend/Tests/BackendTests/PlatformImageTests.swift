import Testing
import SwiftUI
@testable import Backend

@Suite("DataImage")
struct PlatformImageTests {
    @Test("DataImage initializes with data")
    func initWithData() {
        let data = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
        let view = DataImage(data: data)
        #expect(view.data == data)
        #expect(view.renderingMode == nil)
    }

    @Test("DataImage initializes with rendering mode")
    func initWithRenderingMode() {
        let data = Data([0xFF, 0xD8, 0xFF]) // JPEG header bytes
        let view = DataImage(data: data, renderingMode: .template)
        #expect(view.data == data)
        #expect(view.renderingMode == .template)
    }
}
