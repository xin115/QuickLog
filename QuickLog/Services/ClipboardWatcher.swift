import Foundation
import AppKit

@MainActor
final class ClipboardWatcher {
    var onClipboardChange: ((ClipboardItem) -> Void)?

    private var timer: Timer?
    private var lastChangeCount: Int

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func startWatching(pollInterval: TimeInterval = 0.5) {
        stopWatching()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if let str = pb.string(forType: .string), !str.isEmpty {
            let item = ClipboardItem(content: str)
            onClipboardChange?(item)
        }
    }
}
