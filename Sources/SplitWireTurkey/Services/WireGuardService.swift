import Foundation
import Combine
import AppKit

@MainActor
class WireGuardService: ObservableObject {
    @Published var isProcessing = false
    @Published var statusMessage = ""

    private let configDir: URL
    private let wgcfPath: URL

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.configDir = homeDir.appendingPathComponent(".config/wireguard")
        self.wgcfPath = homeDir.appendingPathComponent(".local/bin/wgcf")

        // Create directories if they don't exist
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: wgcfPath.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    func installStandard(includeBrowsers: Bool) async {
        isProcessing = true
        statusMessage = "wgcf indiriliyor..."

        do {
            // Download wgcf if needed
            try await downloadWgcf()

            statusMessage = "WireGuard profili oluşturuluyor..."

            // Register and generate profile
            try await registerAndGenerateProfile()

            // Configure profile
            try await configureProfile(customFolders: [], includeBrowsers: includeBrowsers)

            // Install WireGuard tunnel
            try await installTunnel()

            statusMessage = "Kurulum başarıyla tamamlandı!"

            // Show success alert
            await showAlert(title: "Başarılı", message: "WireGuard kurulumu başarıyla tamamlandı. Sistem yeniden başlatıldığında otomatik olarak aktif olacaktır.")

        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
            await showAlert(title: "Hata", message: "Kurulum başarısız: \(error.localizedDescription)")
        }

        isProcessing = false
    }

    func installCustom(customFolders: [String], includeBrowsers: Bool) async {
        isProcessing = true
        statusMessage = "wgcf indiriliyor..."

        do {
            try await downloadWgcf()
            statusMessage = "WireGuard profili oluşturuluyor..."
            try await registerAndGenerateProfile()
            try await configureProfile(customFolders: customFolders, includeBrowsers: includeBrowsers)
            try await installTunnel()

            statusMessage = "Özel kurulum başarıyla tamamlandı!"
            await showAlert(title: "Başarılı", message: "WireGuard özel kurulumu başarıyla tamamlandı.")

        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
            await showAlert(title: "Hata", message: "Kurulum başarısız: \(error.localizedDescription)")
        }

        isProcessing = false
    }

    func uninstall() async {
        isProcessing = true
        statusMessage = "WireGuard kaldırılıyor..."

        do {
            // Stop and remove WireGuard tunnel
            try await executeShellCommand("wg-quick down wgcf || true")

            // Remove configuration files
            let configPath = configDir.appendingPathComponent("wgcf.conf")
            let accountPath = configDir.appendingPathComponent("wgcf-account.toml")
            let profilePath = configDir.appendingPathComponent("wgcf-profile.conf")

            try? FileManager.default.removeItem(at: configPath)
            try? FileManager.default.removeItem(at: accountPath)
            try? FileManager.default.removeItem(at: profilePath)

            statusMessage = "WireGuard başarıyla kaldırıldı!"
            await showAlert(title: "Başarılı", message: "WireGuard başarıyla kaldırıldı.")

        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
            await showAlert(title: "Hata", message: "Kaldırma işlemi başarısız: \(error.localizedDescription)")
        }

        isProcessing = false
    }

    // MARK: - Private Methods

    private func downloadWgcf() async throws {
        // Check if wgcf already exists
        if FileManager.default.fileExists(atPath: wgcfPath.path) {
            print("wgcf already exists at \(wgcfPath.path)")
            return
        }

        // Download wgcf for macOS
        let downloadURL = "https://github.com/ViRb3/wgcf/releases/latest/download/wgcf_2.2.20_darwin_amd64"
        let url = URL(string: downloadURL)!

        let (localURL, _) = try await URLSession.shared.download(from: url)

        // Move to final location
        try? FileManager.default.removeItem(at: wgcfPath)
        try FileManager.default.moveItem(at: localURL, to: wgcfPath)

        // Make executable
        try await executeShellCommand("chmod +x '\(wgcfPath.path)'")
    }

    private func registerAndGenerateProfile() async throws {
        // Remove existing account if exists
        let accountPath = configDir.appendingPathComponent("wgcf-account.toml")
        try? FileManager.default.removeItem(at: accountPath)

        // Register
        let registerCommand = "cd '\(configDir.path)' && '\(wgcfPath.path)' register --accept-tos"
        try await executeShellCommand(registerCommand)

        // Generate profile
        let generateCommand = "cd '\(configDir.path)' && '\(wgcfPath.path)' generate"
        try await executeShellCommand(generateCommand)
    }

    private func configureProfile(customFolders: [String], includeBrowsers: Bool) async throws {
        let profilePath = configDir.appendingPathComponent("wgcf-profile.conf")
        let configPath = configDir.appendingPathComponent("wgcf.conf")

        guard FileManager.default.fileExists(atPath: profilePath.path) else {
            throw NSError(domain: "WireGuardService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Profil dosyası bulunamadı"])
        }

        // Read profile
        var content = try String(contentsOf: profilePath, encoding: .utf8)

        // Build allowed apps list
        var allowedApps = [
            "/Applications/Discord.app",
            "/Applications/Discord PTB.app",
            "discord",
            "Discord.app"
        ]

        if includeBrowsers {
            allowedApps += [
                "/Applications/Google Chrome.app",
                "/Applications/Firefox.app",
                "/Applications/Opera.app",
                "/Applications/Brave Browser.app",
                "/Applications/Microsoft Edge.app",
                "/Applications/Vivaldi.app",
                "/Applications/Safari.app"
            ]
        }

        allowedApps += customFolders

        // Add AllowedApps line after Endpoint
        if let endpointRange = content.range(of: "Endpoint = ") {
            let lineEnd = content[endpointRange.upperBound...].firstIndex(of: "\n") ?? content.endIndex
            let insertPosition = content.index(after: lineEnd)
            let allowedAppsLine = "# AllowedApps = \(allowedApps.joined(separator: ", "))\n"
            content.insert(contentsOf: allowedAppsLine, at: insertPosition)
        }

        // Write to final config
        try content.write(to: configPath, atomically: true, encoding: .utf8)
    }

    private func installTunnel() async throws {
        let configPath = configDir.appendingPathComponent("wgcf.conf")

        // Copy to /etc/wireguard (requires sudo)
        let copyCommand = "sudo mkdir -p /etc/wireguard && sudo cp '\(configPath.path)' /etc/wireguard/wgcf.conf"
        try await executeShellCommand(copyCommand)

        // Start tunnel
        let startCommand = "sudo wg-quick up wgcf"
        try await executeShellCommand(startCommand)

        // Enable at startup (create LaunchDaemon)
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.splitwire.wireguard</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/local/bin/wg-quick</string>
                <string>up</string>
                <string>wgcf</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """

        let plistPath = "/tmp/com.splitwire.wireguard.plist"
        try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)

        let installPlistCommand = "sudo cp '\(plistPath)' /Library/LaunchDaemons/ && sudo launchctl load /Library/LaunchDaemons/com.splitwire.wireguard.plist"
        try? await executeShellCommand(installPlistCommand)
    }

    private func executeShellCommand(_ command: String) async throws {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")

        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ShellCommand", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }
    }

    private func showAlert(title: String, message: String) async {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title == "Hata" ? .critical : .informational
        alert.addButton(withTitle: "Tamam")
        alert.runModal()
    }
}
