import AppKit
import SwiftUI

@main
struct QuickLogMVPMain {
    // NSApplication.delegate is not strongly retained.
    // Keep a strong reference for the entire app lifetime.
    @MainActor
    static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared

        if ProcessInfo.processInfo.environment["QUICKLOG_SELFTEST"] == "1" {
            // Run self-test on the main actor (AppKit/SwiftUI requirement), then terminate.
            Task { @MainActor in
                QuickLogSelfTest.run()
                app.terminate(nil)
            }
            app.run()
            return
        }

        // IMPORTANT: set delegate + activation policy BEFORE app.run().
        // Doing this asynchronously can race and prevent appDidFinishLaunching from firing,
        // which means no status bar icon.
        MainActor.assumeIsolated {
            app.delegate = appDelegate
            app.setActivationPolicy(.accessory)
        }

        app.run()
    }
}

enum QuickLogSelfTest {
    @MainActor
    static func run() {
        // Smoke test: verify file outputs without needing UI / Accessibility.
        let state = AppState()

        // 1) Append to Today's Log via the new capture flow.
        state.draftContent = "SelfTest: \(Date())\n\nHello from QuickLogMVP."
        state.commitDraftAndNew()

        // 2) Verify draft save/load path works.
        state.draftContent = "SelfTest Draft: \(UUID().uuidString)"
        state.saveDraft()

        // 3) Verify that editing a note updates updatedAt and re-sorts notes.
        let notesService = NotesService()
        let n1 = notesService.createNote(title: "SelfTest Note A")
        let n2 = notesService.createNote(title: "SelfTest Note B")
        state.loadNotes()

        // Open the older note and modify it; it should become most-recent.
        state.openNoteForEditing(noteId: n1.id)
        state.draftContent += "\n\nEdited at \(Date())"
        state.forceAutosaveNow()

        state.loadNotes()
        let topId = state.notes.first?.id
        let reorderOK = (topId == n1.id)

        // Print paths so the runner can verify.
        print("SELFTEST_OK")
        print("reorderOK=\(reorderOK)")
        print("topNoteId=\(topId?.uuidString ?? "nil")")
        print("expectedTop=\(n1.id.uuidString)")
        print("logsDir=\(AppPaths.logsDir.path)")
        print("appSupportDir=\(AppPaths.appSupportDir.path)")
        _ = n2 // silence unused warning if any
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popoverWindow: NSPanel?
    let appState = AppState()

    private var windowTargetFrame: NSRect?
    private var windowHiddenFrame: NSRect?

    private var scrollMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupPopoverWindow()
        setupUnclutterGesture()
        appState.clipboardWatcher.startWatching()
        appState.loadDraft()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }

        // Ensure we don't leave stray status items around in weird edge cases.
        if let item = statusBarItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusBarItem = nil
        NotificationCenter.default.removeObserver(self)
        popoverWindow = nil
    }

    private func setupStatusBarItem() {
        // Defensive: if something calls setup twice, remove the old item first.
        if let existing = statusBarItem {
            NSStatusBar.system.removeStatusItem(existing)
            statusBarItem = nil
        }

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "QuickLog")
            button.toolTip = "QuickLog"
            button.setAccessibilityLabel("QuickLog")
            button.action = #selector(togglePanel)
            button.target = self
        }
    }

    private func setupPopoverWindow() {
        recalcWindowFrames()
        guard let target = windowTargetFrame, let hidden = windowHiddenFrame else { return }

        // Borderless "drawer" panel (Unclutter-like)
        let panel = QuickLogPanel(
            contentRect: hidden,
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // Allow key focus for TextEditor.
        panel.becomesKeyOnlyIfNeeded = false


        let contentView = MainPanelView()
            .environmentObject(appState)

        panel.contentView = NSHostingView(rootView: contentView)
        panel.setFrame(hidden, display: true)

        popoverWindow = panel

        // ESC to hide
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 && self?.popoverWindow?.isVisible == true {
                self?.hidePanel()
                return nil
            }
            return event
        }

        // Recalculate when screens change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Ensure target frame is up-to-date
        panel.setFrame(target, display: false)
        panel.setFrame(hidden, display: false)
    }

    @objc private func screenChanged() {
        recalcWindowFrames()
        guard let window = popoverWindow, let hidden = windowHiddenFrame else { return }
        if !window.isVisible {
            window.setFrame(hidden, display: false)
        }
    }

    private func recalcWindowFrames() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowHeight = screenFrame.height * CGFloat(appState.settings.panelHeightRatio)
        // Unclutter-like: span the full visible width.
        let windowWidth = screenFrame.width

        let windowX = screenFrame.origin.x
        // Top-aligned drawer
        let targetY = screenFrame.maxY - windowHeight
        let target = NSRect(x: windowX, y: targetY, width: windowWidth, height: windowHeight)
        let hidden = NSRect(x: windowX, y: screenFrame.maxY + 2, width: windowWidth, height: windowHeight)

        windowTargetFrame = target
        windowHiddenFrame = hidden
    }

    @objc func togglePanel() {
        if let window = popoverWindow {
            window.isVisible ? hidePanel() : showPanel()
        }
    }

    private func setupUnclutterGesture() {
        // Unclutter-like gesture:
        // move pointer near the top edge, scroll down -> show
        // when visible, scroll up near top -> hide
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            guard let self = self else { return }
            let mouse = NSEvent.mouseLocation
            guard let screen = NSScreen.main else { return }
            let vf = screen.visibleFrame

            // Convert mouse Y to same coordinate space as visibleFrame
            let nearTop = mouse.y >= (vf.maxY - 4)
            guard nearTop else { return }

            // On macOS, scrolling down usually gives negative deltaY.
            if event.scrollingDeltaY < -2 {
                self.showPanel()
            } else if event.scrollingDeltaY > 2 {
                self.hidePanel()
            }
        }
    }

    func showPanel() {
        guard let window = popoverWindow else { return }
        recalcWindowFrames()
        guard let target = windowTargetFrame, let hidden = windowHiddenFrame else { return }

        // Start from hidden (above top edge) each time, like Unclutter.
        window.setFrame(hidden, display: false)
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
            window.animator().setFrame(target, display: true)
        }
    }

    func hidePanel() {
        guard let window = popoverWindow else { return }
        recalcWindowFrames()
        guard let hidden = windowHiddenFrame else {
            window.orderOut(nil)
            appState.saveDraft()
            return
        }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
            window.animator().setFrame(hidden, display: true)
        }, completionHandler: {
            window.orderOut(nil)
        })

        appState.saveDraft()
    }
}
