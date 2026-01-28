import Foundation
import AppKit
import ApplicationServices

let cmdPath = "/tmp/QuickLogAutomationAgent.cmd"
let resultPath = "/tmp/QuickLogAutomationAgent.result.json"
let defaultProjectPath = "/Users/smile/Documents/coding/happy/QuickLog"

func writeResult(ok: Bool, message: String) {
    let ts = Int(Date().timeIntervalSince1970)
    let esc = message
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
    let json = "{\"ok\":\(ok ? "true" : "false"),\"message\":\"\(esc)\",\"ts\":\(ts)}"
    try? json.data(using: .utf8)?.write(to: URL(fileURLWithPath: resultPath), options: [.atomic])
}

func runShell(_ command: String) throws -> String {
    // For commands that should return small output.
    let p = Process()
    p.launchPath = "/bin/zsh"
    p.arguments = ["-lc", command]

    let out = Pipe()
    let err = Pipe()
    p.standardOutput = out
    p.standardError = err

    try p.run()
    p.waitUntilExit()

    let outData = out.fileHandleForReading.readDataToEndOfFile()
    let errData = err.fileHandleForReading.readDataToEndOfFile()
    let outStr = String(data: outData, encoding: .utf8) ?? ""
    let errStr = String(data: errData, encoding: .utf8) ?? ""

    if p.terminationStatus != 0 {
        throw NSError(domain: "QuickLogAutomationAgentSwift", code: Int(p.terminationStatus), userInfo: [
            NSLocalizedDescriptionKey: "Shell failed (\(p.terminationStatus)): \(command)\n\(errStr)\n\(outStr)"
        ])
    }
    return outStr.trimmingCharacters(in: .whitespacesAndNewlines)
}

func runShellNoCapture(_ command: String, logPath: String = "/tmp/QuickLogAutomationAgentSwift.shell.log") throws {
    // For noisy commands (e.g., swift build) to avoid pipe-buffer deadlocks.
    let p = Process()
    p.launchPath = "/bin/zsh"
    p.arguments = ["-lc", command]

    let fm = FileManager.default
    if !fm.fileExists(atPath: logPath) {
        fm.createFile(atPath: logPath, contents: nil)
    }

    let fh = try FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
    try fh.seekToEnd()
    p.standardOutput = fh
    p.standardError = fh

    try p.run()
    p.waitUntilExit()
    try? fh.close()

    if p.terminationStatus != 0 {
        throw NSError(domain: "QuickLogAutomationAgentSwift", code: Int(p.terminationStatus), userInfo: [
            NSLocalizedDescriptionKey: "Shell failed (\(p.terminationStatus)): \(command)\nSee: \(logPath)"
        ])
    }
}

func runAppleScript(_ source: String) throws {
    if let script = NSAppleScript(source: source) {
        var err: NSDictionary?
        script.executeAndReturnError(&err)
        if let err = err {
            throw NSError(domain: "QuickLogAutomationAgentSwift", code: 1, userInfo: [NSLocalizedDescriptionKey: "AppleScript error: \(err)"])
        }
    } else {
        throw NSError(domain: "QuickLogAutomationAgentSwift", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to compile AppleScript"])
    }
}

@MainActor
final class Agent: NSObject {
    private var timer: Timer?

    func start() {
        // Prompt for Accessibility if not granted.
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(opts)

        // Runloop timer.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func tick() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cmdPath) else { return }

        do {
            let raw = try String(contentsOfFile: cmdPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            try? fm.removeItem(atPath: cmdPath)
            let projectPath = raw.isEmpty ? defaultProjectPath : raw

            writeResult(ok: false, message: "STARTED")

            // Build
            writeResult(ok: false, message: "BUILDING")
            try runShellNoCapture("cd \(projectPath.quotedForShell) && swift build -c debug")
            writeResult(ok: false, message: "BUILT")

            // Find binary
            let binRel = try runShell("cd \(projectPath.quotedForShell) && /usr/bin/find .build -type f -path '*/debug/QuickLogMVP' -maxdepth 8 | /usr/bin/head -n 1")
            if binRel.isEmpty { throw NSError(domain: "QuickLogAutomationAgentSwift", code: 2, userInfo: [NSLocalizedDescriptionKey: "Built binary not found"]) }
            writeResult(ok: false, message: "FOUND_BIN")

            // Launch
            _ = try runShell("cd \(projectPath.quotedForShell) && (./\(binRel) >/tmp/QuickLogMVP.stdout.log 2>/tmp/QuickLogMVP.stderr.log &) ; /bin/sleep 0.3")
            let pid = try runShell("/usr/bin/pgrep -n QuickLogMVP")
            writeResult(ok: false, message: "LAUNCHED pid=\(pid)")
            defer {
                _ = try? runShell("/bin/kill \(pid)")
            }

            // UI toggle via System Events
            // Status bar items are sometimes exposed under the app process, sometimes under SystemUIServer.
            // Try app process first, then fallback to SystemUIServer search by description.
            let asrc = """
            with timeout of 6 seconds
              tell application \"System Events\"
                if exists application process \"QuickLogMVP\" then
                  try
                    tell application process \"QuickLogMVP\"
                      set frontmost to true
                      delay 0.2
                      if (count of menu bars) > 0 then
                        click (first menu bar item of menu bar 1)
                        delay 0.4
                        click (first menu bar item of menu bar 1)
                        return
                      end if
                    end tell
                  end try
                end if

                tell application process \"SystemUIServer\"
                  repeat with mb in menu bars
                    repeat with mi in menu bar items of mb
                      try
                        set d to description of mi
                      on error
                        set d to \"\"
                      end try
                      try
                        set n to name of mi
                      on error
                        set n to \"\"
                      end try
                      if (d contains \"QuickLog\") or (n contains \"QuickLog\") then
                        click mi
                        delay 0.4
                        click mi
                        return
                      end if
                    end repeat
                  end repeat
                end tell

                error \"QuickLog status item not found\"
              end tell
            end timeout
            """
            try runAppleScript(asrc)

            writeResult(ok: true, message: "UI click toggle OK")
        } catch {
            writeResult(ok: false, message: String(describing: error))
        }
    }
}

extension String {
    var quotedForShell: String {
        // simple single-quote escaping
        return "'" + self.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

@main
struct Main {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let agent = Agent()
        Task { @MainActor in
            agent.start()
        }
        app.run()
    }
}
