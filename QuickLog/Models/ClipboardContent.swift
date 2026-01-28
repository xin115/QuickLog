import Foundation
import AppKit

enum ClipboardContent: Equatable {
    case text(String)
    case image(Data)

    var text: String? {
        if case .text(let s) = self { return s }
        return nil
    }

    var imageData: Data? {
        if case .image(let d) = self { return d }
        return nil
    }

    var nsImage: NSImage? {
        guard case .image(let d) = self else { return nil }
        return NSImage(data: d)
    }
}
