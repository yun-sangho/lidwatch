import Foundation
import IOKit

// MARK: - Constants

let appName = "lidwatch"
let version = "0.1.2"

// MARK: - State file (enable/disable flag)

func stateDirectory() -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return "\(home)/Library/Application Support/\(appName)"
}

func stateFilePath() -> String {
    return "\(stateDirectory())/enabled"
}

func isEnabled() -> Bool {
    return FileManager.default.fileExists(atPath: stateFilePath())
}

func setEnabled(_ enabled: Bool) throws {
    let dir = stateDirectory()
    try FileManager.default.createDirectory(
        atPath: dir, withIntermediateDirectories: true
    )
    let path = stateFilePath()
    if enabled {
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
    } else {
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
    }
}

// MARK: - Clamshell state reader

func readClamshell(_ service: io_service_t) -> Bool? {
    guard let prop = IORegistryEntryCreateCFProperty(
        service,
        "AppleClamshellState" as CFString,
        kCFAllocatorDefault,
        0
    )?.takeRetainedValue() else {
        return nil
    }
    return (prop as? Bool) ?? ((prop as? NSNumber)?.boolValue)
}

// MARK: - Logging

func logLine(_ message: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    print("[\(ts)] \(message)")
}

// MARK: - Action: tell display to sleep

func runDisplaySleep() {
    let task = Process()
    task.launchPath = "/usr/bin/pmset"
    task.arguments = ["displaysleepnow"]
    do {
        try task.run()
        task.waitUntilExit()
        logLine("action: pmset displaysleepnow (exit=\(task.terminationStatus))")
    } catch {
        logLine("action: pmset failed: \(error)")
    }
}

// MARK: - Watcher

// Global — callback runs on main dispatch queue, no concurrent access.
nonisolated(unsafe) var previousClamshellClosed: Bool = false

func runWatcher() -> Never {
    setbuf(stdout, nil)
    logLine("\(appName) \(version) starting")
    logLine("state file: \(stateFilePath())")
    logLine("enabled: \(isEnabled())")

    let rootDomain = IOServiceGetMatchingService(
        kIOMainPortDefault,
        IOServiceMatching("IOPMrootDomain")
    )
    guard rootDomain != 0 else {
        logLine("fatal: could not find IOPMrootDomain")
        exit(1)
    }

    previousClamshellClosed = readClamshell(rootDomain) ?? false
    logLine("initial clamshell closed = \(previousClamshellClosed)")

    guard let notifyPort = IONotificationPortCreate(kIOMainPortDefault) else {
        logLine("fatal: IONotificationPortCreate failed")
        exit(1)
    }
    IONotificationPortSetDispatchQueue(notifyPort, DispatchQueue.main)

    let callback: IOServiceInterestCallback = { (_, service, _, _) in
        guard let current = readClamshell(service) else { return }
        let prev = previousClamshellClosed
        previousClamshellClosed = current

        // Only act on OPEN -> CLOSED transition.
        guard current, !prev else { return }

        logLine("event: lid closed")

        if !isEnabled() {
            logLine("skipped: disabled (no state file)")
            return
        }
        runDisplaySleep()
    }

    var iter: io_object_t = 0
    let kr = IOServiceAddInterestNotification(
        notifyPort, rootDomain, kIOGeneralInterest, callback, nil, &iter
    )
    guard kr == KERN_SUCCESS else {
        logLine("fatal: IOServiceAddInterestNotification failed: \(kr)")
        exit(1)
    }

    logLine("registered — awaiting events")
    dispatchMain()
}

// MARK: - CLI

func printUsage() {
    let usage = """
    \(appName) \(version) — event-driven clamshell display sleep helper

    USAGE:
      \(appName) watch             run the event watcher (used by LaunchAgent)
      \(appName) enable            turn on display-sleep-on-close
      \(appName) disable           turn it off
      \(appName) toggle            flip the enabled state
      \(appName) status            show current state + clamshell
      \(appName) help              this message
      \(appName) version           print version

    The watcher only takes action when enabled. Use launchctl (or the
    install script) to run the watcher at login.
    """
    print(usage)
}

func printStatus() {
    print("\(appName) \(version)")
    print("enabled:   \(isEnabled())")
    print("state file: \(stateFilePath())")

    let rootDomain = IOServiceGetMatchingService(
        kIOMainPortDefault, IOServiceMatching("IOPMrootDomain")
    )
    if rootDomain != 0, let closed = readClamshell(rootDomain) {
        print("clamshell: \(closed ? "CLOSED" : "OPEN")")
        IOObjectRelease(rootDomain)
    } else {
        print("clamshell: unknown")
    }

    // Is any lidwatch agent loaded? Covers both manual install
    // (com.lidwatch.agent) and Homebrew (homebrew.mxcl.lidwatch).
    let task = Process()
    task.launchPath = "/bin/launchctl"
    task.arguments = ["list"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    try? task.run()
    task.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                     encoding: .utf8) ?? ""
    let matches = out.split(separator: "\n").filter {
        $0.contains("com.lidwatch.agent") || $0.contains("homebrew.mxcl.lidwatch")
    }
    if let line = matches.first {
        let label = line.split(separator: "\t").last.map(String.init) ?? "loaded"
        print("agent:     loaded (\(label))")
    } else {
        print("agent:     not loaded")
    }
}

let args = Array(CommandLine.arguments.dropFirst())

switch args.first ?? "watch" {
case "watch":
    runWatcher()
case "enable":
    do {
        try setEnabled(true)
        print("enabled")
    } catch {
        print("error: \(error)")
        exit(1)
    }
case "disable":
    do {
        try setEnabled(false)
        print("disabled")
    } catch {
        print("error: \(error)")
        exit(1)
    }
case "toggle":
    do {
        let newState = !isEnabled()
        try setEnabled(newState)
        print(newState ? "enabled" : "disabled")
    } catch {
        print("error: \(error)")
        exit(1)
    }
case "status":
    printStatus()
case "version", "--version", "-v":
    print("\(appName) \(version)")
case "help", "--help", "-h":
    printUsage()
default:
    printUsage()
    exit(2)
}
