import AppKit

/// Borderless panels often refuse key status by default.
/// This panel explicitly allows key/main so SwiftUI TextEditor can receive focus.
final class QuickLogPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
