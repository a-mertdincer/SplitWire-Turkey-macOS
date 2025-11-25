import Foundation
import AppKit
import Combine

@MainActor
class MenuBarService: ObservableObject {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var statusCheckTimer: Timer?
    private var currentPreset = "Standart"
    private var isProcessing = false

    @Published var isByeDPIRunning = false

    // Available presets matching ByeDPIService
    private let presets: [String: String] = [
        "Standart": "-r 1+s",
        "Split 1": "-s 1 --tlsrec 1+s",
        "Split 2": "-s 2 --tlsrec 1+s",
        "Disorder": "--disorder 1 --auto=torst --tlsrec 1+s",
        "Fake -1": "--fake -1 --ttl 8",
        "Fake 1": "-f 1 --ttl 8 -s 2",
        "OOB": "-o 1 --auto=torst",
        "Split + Disorder": "-s 1 -d 2 --auto=torst"
    ]

    func setup() {
        // Load saved preset
        if let savedPreset = UserDefaults.standard.string(forKey: "menuBarPreset"),
           presets.keys.contains(savedPreset) {
            currentPreset = savedPreset
        }

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "shield.slash", accessibilityDescription: "ByeDPI")
            button.image?.isTemplate = true
        }

        // Create the menu
        updateMenu()

        // Start periodic status check to detect process changes
        startStatusCheck()

        // Initial check
        Task {
            await checkByeDPIStatus()
        }
    }

    private func startStatusCheck() {
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkByeDPIStatus()
            }
        }
    }

    private func checkByeDPIStatus() async {
        // Check if port 1080 is in use (indicates ByeDPI is running)
        do {
            let result = try await executeShellCommand("lsof -i :1080 2>/dev/null | grep -c ciadpi || echo 0")
            let count = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let isRunning = count > 0

            if isRunning != isByeDPIRunning {
                isByeDPIRunning = isRunning
                updateStatusIcon(isRunning: isRunning)
                updateMenu()
            }
        } catch {
            // Silently fail
        }
    }

    private func executeShellCommand(_ command: String) async throws -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func updateStatusIcon(isRunning: Bool) {
        if let button = statusItem?.button {
            let iconName = isRunning ? "shield.checkered" : "shield.slash"
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "ByeDPI")
            button.image?.isTemplate = true
        }
    }

    private func updateMenu() {
        let menu = NSMenu()

        // Status
        let statusItem = NSMenuItem(title: isByeDPIRunning ? "ByeDPI: Çalışıyor" : "ByeDPI: Durduruldu", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false

        // Add colored circle indicator
        if isByeDPIRunning {
            statusItem.image = createCircleImage(color: .systemGreen)
        } else {
            statusItem.image = createCircleImage(color: .systemRed)
        }

        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())

        // Toggle ByeDPI
        if isByeDPIRunning {
            let stopItem = NSMenuItem(title: "ByeDPI'ı Durdur", action: #selector(stopByeDPI), keyEquivalent: "s")
            stopItem.target = self
            stopItem.isEnabled = !isProcessing
            menu.addItem(stopItem)
        } else {
            let startItem = NSMenuItem(title: "ByeDPI'ı Başlat", action: #selector(startByeDPI), keyEquivalent: "b")
            startItem.target = self
            startItem.isEnabled = !isProcessing
            menu.addItem(startItem)
        }

        // Kill All
        let killAllItem = NSMenuItem(title: "Tümünü Zorla Kapat", action: #selector(killAllProcesses), keyEquivalent: "k")
        killAllItem.target = self
        killAllItem.isEnabled = !isProcessing
        menu.addItem(killAllItem)

        menu.addItem(NSMenuItem.separator())

        // Proxy Info
        if isByeDPIRunning {
            let proxyInfo = NSMenuItem(title: "SOCKS5: 127.0.0.1:1080", action: #selector(copyProxyAddress), keyEquivalent: "")
            proxyInfo.target = self
            menu.addItem(proxyInfo)

            menu.addItem(NSMenuItem.separator())
        }

        // Preset Selection Submenu
        let presetMenu = NSMenu()
        let sortedPresets = presets.keys.sorted()
        for presetName in sortedPresets {
            let presetItem = NSMenuItem(
                title: presetName,
                action: #selector(selectPreset(_:)),
                keyEquivalent: ""
            )
            presetItem.target = self
            presetItem.representedObject = presetName
            presetItem.isEnabled = !isProcessing

            // Mark current preset with checkmark
            if presetName == currentPreset {
                presetItem.state = .on
            }

            presetMenu.addItem(presetItem)
        }

        let presetMenuItem = NSMenuItem(title: "DPI Yöntemi: \(currentPreset)", action: nil, keyEquivalent: "")
        presetMenuItem.submenu = presetMenu
        presetMenuItem.isEnabled = !isProcessing
        menu.addItem(presetMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Show Main Window
        let showWindowItem = NSMenuItem(title: "Ana Pencereyi Göster", action: #selector(showMainWindow), keyEquivalent: "o")
        showWindowItem.target = self
        menu.addItem(showWindowItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Çıkış", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    private func createCircleImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 10, height: 10)
        let image = NSImage(size: size)

        image.lockFocus()
        color.setFill()
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
        path.fill()
        image.unlockFocus()

        image.isTemplate = false
        return image
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let presetName = sender.representedObject as? String else { return }
        guard !isProcessing else { return }

        currentPreset = presetName

        // Save to UserDefaults
        UserDefaults.standard.set(currentPreset, forKey: "menuBarPreset")

        // Update menu immediately to show new preset
        updateMenu()

        // Restart ByeDPI if running
        if isByeDPIRunning {
            isProcessing = true
            updateMenu()

            Task { @MainActor in
                await performStopByeDPI()
                try? await Task.sleep(nanoseconds: 500_000_000)
                await performStartByeDPI()
                isProcessing = false
                updateMenu()
            }
        }
    }

    @objc private func startByeDPI() {
        guard !isProcessing else { return }

        isProcessing = true
        updateMenu()

        Task { @MainActor in
            await performStartByeDPI()
            isProcessing = false
            updateMenu()
        }
    }

    @objc private func stopByeDPI() {
        guard !isProcessing else { return }

        isProcessing = true
        updateMenu()

        Task { @MainActor in
            await performStopByeDPI()
            isProcessing = false
            updateMenu()
        }
    }

    private func performStartByeDPI() async {
        do {
            let ciadpiPath = findCiadpiPath()
            guard FileManager.default.fileExists(atPath: ciadpiPath) else {
                await showAlert(title: "Hata", message: "ciadpi binary bulunamadı")
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: ciadpiPath)

            // Use current preset arguments
            let args = presets[currentPreset] ?? "-r 1+s"
            let argArray = args.split(separator: " ").map(String.init)
            process.arguments = argArray

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

            // Wait and verify
            try? await Task.sleep(nanoseconds: 500_000_000)
            await checkByeDPIStatus()

            if isByeDPIRunning {
                await showAlert(title: "Başarılı", message: "ByeDPI başlatıldı\nYöntem: \(currentPreset)\nSOCKS5: 127.0.0.1:1080")
            }
        } catch {
            await showAlert(title: "Hata", message: "ByeDPI başlatılamadı: \(error.localizedDescription)")
        }
    }

    private func performStopByeDPI() async {
        _ = try? await executeShellCommand("pkill -f ciadpi")
        try? await Task.sleep(nanoseconds: 300_000_000)
        _ = try? await executeShellCommand("pkill -9 -f ciadpi")
        try? await Task.sleep(nanoseconds: 300_000_000)
        await checkByeDPIStatus()
    }

    @objc private func killAllProcesses() {
        guard !isProcessing else { return }

        isProcessing = true
        updateMenu()

        Task { @MainActor in
            // Kill by port using lsof with sudo
            _ = try? await executeAppleScript("""
                do shell script "lsof -ti:1080 | xargs kill -9 2>/dev/null || true" with administrator privileges
                """)
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Kill all ciadpi processes by name
            _ = try? await executeShellCommand("pkill -9 -f ciadpi 2>/dev/null || true")
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Double check with killall
            _ = try? await executeShellCommand("killall -9 ciadpi 2>/dev/null || true")
            try? await Task.sleep(nanoseconds: 200_000_000)

            await checkByeDPIStatus()
            await showAlert(title: "Tamamlandı", message: "Tüm ByeDPI process'leri kapatıldı")

            isProcessing = false
            updateMenu()
        }
    }

    private func executeAppleScript(_ script: String) async throws {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(&error)

        if let error = error {
            throw NSError(
                domain: "AppleScript",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: error.description]
            )
        }
    }

    private func findCiadpiPath() -> String {
        // Check bundle resources
        if let bundlePath = Bundle.main.resourcePath {
            let resourcePath = "\(bundlePath)/bin/ciadpi"
            if FileManager.default.fileExists(atPath: resourcePath) {
                return resourcePath
            }
        }

        // Check next to executable
        if let execPath = Bundle.main.executablePath {
            let execDir = (execPath as NSString).deletingLastPathComponent
            let devPath = "\(execDir)/../../../byedpi/ciadpi"
            if FileManager.default.fileExists(atPath: devPath) {
                return devPath
            }
        }

        // Fallback
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Downloads/SplitWire-Turkey-macOS/byedpi/ciadpi"
    }

    private func showAlert(title: String, message: String) async {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title == "Hata" ? .warning : .informational
        alert.addButton(withTitle: "Tamam")
        alert.runModal()
    }

    @objc private func copyProxyAddress() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("socks5://127.0.0.1:1080", forType: .string)

        // Show brief notification via alert
        let alert = NSAlert()
        alert.messageText = "Kopyalandı"
        alert.informativeText = "Proxy adresi panoya kopyalandı."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Tamam")

        // Auto-dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.buttons.first?.performClick(nil)
        }

        alert.runModal()
    }

    @objc private func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quitApp() {
        // Stop ByeDPI before quitting
        Task { @MainActor in
            _ = try? await executeShellCommand("pkill -9 -f ciadpi")
            try? await Task.sleep(nanoseconds: 300_000_000)
            NSApplication.shared.terminate(nil)
        }
    }
}
