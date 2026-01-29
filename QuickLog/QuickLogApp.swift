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

        // Print paths so the runner can verify.
        print("SELFTEST_OK")
        print("logsDir=\(AppPaths.logsDir.path)")
        print("appSupportDir=\(AppPaths.appSupportDir.path)")
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
        setupMainMenu()
        setupStatusBarItem()
        setupPopoverWindow()
        setupUnclutterGesture()
        appState.clipboardWatcher.startWatching()
        appState.loadDraft()
    }

    private func setupMainMenu() {
        // Accessory apps often have no default menu, which can break standard
        // Cmd+C / Cmd+V / Cmd+X / Cmd+A because these shortcuts are usually
        // provided via menu item key equivalents.
        let main = NSMenu()

        // App menu (minimal)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit QuickLog", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        main.addItem(appMenuItem)

        // Edit menu with standard pasteboard actions
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")

        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        editMenuItem.submenu = editMenu
        main.addItem(editMenuItem)

        NSApp.mainMenu = main
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

        // Key handling
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // ESC to hide
            if event.keyCode == 53 && self.popoverWindow?.isVisible == true {
                self.hidePanel()
                return nil
            }

            // Ensure standard clipboard shortcuts work even when the app has no visible menubar.
            // This routes actions through the responder chain to the focused TextEditor.
            if event.modifierFlags.contains(.command), self.popoverWindow?.isVisible == true {
                let ch = event.charactersIgnoringModifiers?.lowercased() ?? ""
                switch ch {
                case "c":
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                    return nil
                case "v":
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                    return nil
                case "x":
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                    return nil
                case "a":
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    return nil
                case "z":
                    if event.modifierFlags.contains(.shift) {
                        NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                    } else {
                        NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                    }
                    return nil
                default:
                    break
                }
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
        // Gesture:
        // when cursor is in the menu bar area (top bar), two-finger scroll down -> show
        // when visible, two-finger scroll up -> hide
        // (Only applies while this app is running; implemented via global scroll monitor.)
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            guard let self = self else { return }

            let mouse = NSEvent.mouseLocation
            guard let screen = NSScreen.main else { return }

            // Menu bar is the region above visibleFrame (which excludes it).
            let menuBarHeight = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
            let menuBarBottomY = screen.frame.maxY - menuBarHeight
            let inMenuBar = mouse.y >= (menuBarBottomY - 1)

            if DebugLog.enabled {
                DebugLog.log("scrollWheel dy=\(event.scrollingDeltaY) precise=\(event.hasPreciseScrollingDeltas) mouseY=\(mouse.y) menuBarBottomY=\(menuBarBottomY) inMenuBar=\(inMenuBar) visible=\(self.popoverWindow?.isVisible == true)")
            }

            // Only trigger when cursor is in the menu bar area.
            guard inMenuBar else { return }

            // Ignore tiny deltas.
            let dy = event.scrollingDeltaY
            guard abs(dy) > 2 else { return }

            // Down (negative) => show; Up (positive) => hide.
            if dy < 0 {
                if self.popoverWindow?.isVisible != true {
                    self.showPanel()
                }
            } else {
                if self.popoverWindow?.isVisible == true {
                    self.hidePanel()
                }
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
