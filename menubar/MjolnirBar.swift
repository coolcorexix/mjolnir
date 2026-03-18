import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusTimer: Timer?
    private var healthCheckTimer: Timer?
    private var cacheTimer: Timer?

    private var yabaiRunning = false
    private var skhdRunning = false
    private var lastSkhdHealthy = true
    private var lastYabaiHealthy = true
    private var consecutiveFailures: [String: Int] = ["skhd": 0, "yabai": 0]

    private var yabaiStatusItem: NSMenuItem!
    private var skhdStatusItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!

    private let pollingInterval: TimeInterval = 5.0
    private let healthCheckInterval: TimeInterval = 30.0
    private let maxConsecutiveFailures = 2
    private let launchAgentPath = NSString(string: "~/Library/LaunchAgents/com.nemolab.mjolnirbar.plist").expandingTildeInPath
    private let bundleIdentifier = "com.nemolab.mjolnirbar"
    private let restartScriptPath = NSString(string: "~/Documents/nemo-lab.nosync/mjolnir/bin/mjolnir-restart").expandingTildeInPath
    private let floatScriptPath = NSString(string: "~/bin/yspace-float").expandingTildeInPath
    private let cacheScriptPath = NSString(string: "~/Documents/nemo-lab.nosync/mjolnir/bin/yspace-cache").expandingTildeInPath
    private let cacheInterval: TimeInterval = 2.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupMenu()
        startStatusPolling()
        startHealthCheck()
        startCacheUpdater()
        updateServiceStatus()
        updateCache() // Initial cache population
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusTimer?.invalidate()
        healthCheckTimer?.invalidate()
        cacheTimer?.invalidate()
    }

    // MARK: - Status Bar Setup

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "\u{2692}"  // Hammer and pick
            button.toolTip = "Mjolnir Window Manager"
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Header
        let headerItem = NSMenuItem(title: "Mjolnir Status", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Status indicators
        yabaiStatusItem = NSMenuItem(title: "yabai: Checking...", action: nil, keyEquivalent: "")
        yabaiStatusItem.isEnabled = false
        menu.addItem(yabaiStatusItem)

        skhdStatusItem = NSMenuItem(title: "skhd: Checking...", action: nil, keyEquivalent: "")
        skhdStatusItem.isEnabled = false
        menu.addItem(skhdStatusItem)

        menu.addItem(NSMenuItem.separator())

        // yabai controls submenu
        let yabaiMenu = NSMenu()
        yabaiMenu.addItem(createMenuItem("Start yabai", action: #selector(startYabai)))
        yabaiMenu.addItem(createMenuItem("Stop yabai", action: #selector(stopYabai)))
        yabaiMenu.addItem(createMenuItem("Restart yabai", action: #selector(restartYabai)))

        let yabaiMenuItem = NSMenuItem(title: "yabai", action: nil, keyEquivalent: "")
        yabaiMenuItem.submenu = yabaiMenu
        menu.addItem(yabaiMenuItem)

        // skhd controls submenu
        let skhdMenu = NSMenu()
        skhdMenu.addItem(createMenuItem("Start skhd", action: #selector(startSkhd)))
        skhdMenu.addItem(createMenuItem("Stop skhd", action: #selector(stopSkhd)))
        skhdMenu.addItem(createMenuItem("Restart skhd", action: #selector(restartSkhd)))

        let skhdMenuItem = NSMenuItem(title: "skhd", action: nil, keyEquivalent: "")
        skhdMenuItem.submenu = skhdMenu
        menu.addItem(skhdMenuItem)

        menu.addItem(NSMenuItem.separator())

        // App Switcher
        menu.addItem(createMenuItem("Open App Switcher", action: #selector(openFloatUI), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // Combined controls
        menu.addItem(createMenuItem("Start All", action: #selector(startAll), keyEquivalent: "s"))
        menu.addItem(createMenuItem("Stop All", action: #selector(stopAll)))
        menu.addItem(createMenuItem("Restart All", action: #selector(restartAll), keyEquivalent: "r"))

        menu.addItem(NSMenuItem.separator())

        // Launch at Login
        launchAtLoginItem = createMenuItem("Launch at Login", action: #selector(toggleLaunchAtLogin))
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(createMenuItem("Quit MjolnirBar", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func createMenuItem(_ title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    // MARK: - Status Polling

    private func startStatusPolling() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.updateServiceStatus()
        }
        RunLoop.current.add(statusTimer!, forMode: .common)
    }

    private func updateServiceStatus() {
        yabaiRunning = isProcessRunning("yabai")
        skhdRunning = isProcessRunning("skhd")

        DispatchQueue.main.async { [weak self] in
            self?.updateMenuIndicators()
        }
    }

    private func isProcessRunning(_ processName: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", processName]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func updateMenuIndicators() {
        let greenDot = "\u{1F7E2}"
        let redDot = "\u{1F534}"

        let yabaiStatus = yabaiRunning ? "\(greenDot) Running" : "\(redDot) Stopped"
        yabaiStatusItem.title = "yabai: \(yabaiStatus)"

        let skhdStatus = skhdRunning ? "\(greenDot) Running" : "\(redDot) Stopped"
        skhdStatusItem.title = "skhd: \(skhdStatus)"
    }

    // MARK: - Shell Commands

    @discardableResult
    private func runShellCommand(_ command: String, arguments: [String] = []) -> (output: String, exitCode: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: command)
        task.arguments = arguments

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        task.environment = env

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return (output, task.terminationStatus)
        } catch {
            return ("Error: \(error.localizedDescription)", -1)
        }
    }

    private func runServiceCommand(_ service: String, action: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.runShellCommand(self.restartScriptPath, arguments: [service, action])

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.updateServiceStatus()
            }
        }
    }

    // MARK: - App List Cache

    private func startCacheUpdater() {
        cacheTimer = Timer.scheduledTimer(withTimeInterval: cacheInterval, repeats: true) { [weak self] _ in
            self?.updateCache()
        }
        RunLoop.current.add(cacheTimer!, forMode: .common)
    }

    private func updateCache() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            self.runShellCommand("/bin/bash", arguments: [self.cacheScriptPath])
        }
    }

    // MARK: - Health Check

    private func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
        RunLoop.current.add(healthCheckTimer!, forMode: .common)
    }

    private func performHealthCheck() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // Check skhd health
            let skhdHealthy = self.checkServiceHealth("skhd")
            if !skhdHealthy {
                self.consecutiveFailures["skhd", default: 0] += 1
                if self.consecutiveFailures["skhd", default: 0] >= self.maxConsecutiveFailures {
                    NSLog("MjolnirBar: skhd unhealthy, performing robust restart")
                    self.robustRestart("skhd")
                    self.consecutiveFailures["skhd"] = 0
                }
            } else {
                self.consecutiveFailures["skhd"] = 0
            }

            // Check yabai health
            let yabaiHealthy = self.checkServiceHealth("yabai")
            if !yabaiHealthy {
                self.consecutiveFailures["yabai", default: 0] += 1
                if self.consecutiveFailures["yabai", default: 0] >= self.maxConsecutiveFailures {
                    NSLog("MjolnirBar: yabai unhealthy, performing robust restart")
                    self.robustRestart("yabai")
                    self.consecutiveFailures["yabai"] = 0
                }
            } else {
                self.consecutiveFailures["yabai"] = 0
            }

            DispatchQueue.main.async {
                self.updateServiceStatus()
            }
        }
    }

    private func checkServiceHealth(_ service: String) -> Bool {
        // First check if process is running
        if !isProcessRunning(service) {
            return false
        }

        // For skhd, check if PID file is stale (process running but can't restart)
        if service == "skhd" {
            let pidFile = "/tmp/skhd_\(NSUserName()).pid"
            if FileManager.default.fileExists(atPath: pidFile) {
                // Try to read PID and verify it matches running process
                if let pidString = try? String(contentsOfFile: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                   let filePid = Int32(pidString) {
                    let (output, _) = runShellCommand("/usr/bin/pgrep", arguments: ["-x", service])
                    let runningPids = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n").compactMap { Int32($0) }
                    if !runningPids.contains(filePid) {
                        NSLog("MjolnirBar: Stale PID file detected for \(service)")
                        return false
                    }
                }
            }
        }

        // For yabai, verify it responds to queries
        if service == "yabai" {
            let (_, exitCode) = runShellCommand("/opt/homebrew/bin/yabai", arguments: ["-m", "query", "--spaces"])
            if exitCode != 0 {
                return false
            }
        }

        return true
    }

    private func robustRestart(_ service: String) {
        runShellCommand(restartScriptPath, arguments: [service, "restart"])
    }

    // MARK: - Service Actions

    @objc private func startYabai() {
        runServiceCommand("yabai", action: "start")
    }

    @objc private func stopYabai() {
        runServiceCommand("yabai", action: "stop")
    }

    @objc private func restartYabai() {
        runServiceCommand("yabai", action: "restart")
    }

    @objc private func startSkhd() {
        runServiceCommand("skhd", action: "start")
    }

    @objc private func stopSkhd() {
        runServiceCommand("skhd", action: "stop")
    }

    @objc private func restartSkhd() {
        runServiceCommand("skhd", action: "restart")
    }

    @objc private func openFloatUI() {
        // Launch via NSWorkspace to ensure GUI apps like 'choose' can display
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-l", "-c", floatScriptPath]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        task.environment = env

        do {
            try task.run()
        } catch {
            NSLog("Failed to launch float UI: \(error)")
        }
    }

    @objc private func startAll() {
        startYabai()
        startSkhd()
    }

    @objc private func stopAll() {
        stopYabai()
        stopSkhd()
    }

    @objc private func restartAll() {
        restartYabai()
        restartSkhd()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Launch at Login

    private func isLaunchAtLoginEnabled() -> Bool {
        return FileManager.default.fileExists(atPath: launchAgentPath)
    }

    @objc private func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled() {
            disableLaunchAtLogin()
        } else {
            enableLaunchAtLogin()
        }
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
    }

    private func enableLaunchAtLogin() {
        guard let appPath = Bundle.main.bundlePath as String? else { return }

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(bundleIdentifier)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(appPath)/Contents/MacOS/MjolnirBar</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """

        do {
            let launchAgentsDir = (launchAgentPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)
            try plistContent.write(toFile: launchAgentPath, atomically: true, encoding: .utf8)
            runShellCommand("/bin/launchctl", arguments: ["load", launchAgentPath])
        } catch {
            NSLog("Failed to enable launch at login: \(error)")
        }
    }

    private func disableLaunchAtLogin() {
        runShellCommand("/bin/launchctl", arguments: ["unload", launchAgentPath])

        do {
            try FileManager.default.removeItem(atPath: launchAgentPath)
        } catch {
            NSLog("Failed to disable launch at login: \(error)")
        }
    }
}

// MARK: - Main Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
