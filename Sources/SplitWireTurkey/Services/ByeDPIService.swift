import Foundation
import Combine
import AppKit

@MainActor
class ByeDPIService: ObservableObject {
    @Published var isRunning = false
    @Published var isProcessing = false
    @Published var statusMessage = ""
    @Published var currentPreset = "Standart"
    @Published var isSystemProxyEnabled = false

    private var process: Process?
    private let ciadpiPath: String

    // Preset configurations
    let presets = [
        "Standart": "-r 1+s",
        "Split 1": "-s 1 --tlsrec 1+s",
        "Split 2": "-s 2 --tlsrec 1+s",
        "Disorder": "--disorder 1 --auto=torst --tlsrec 1+s",
        "Fake -1": "--fake -1 --ttl 8",
        "Fake 1": "-f 1 --ttl 8 -s 2",
        "OOB": "-o 1 --auto=torst",
        "Split + Disorder": "-s 1 -d 2 --auto=torst",
        "Custom": ""  // User will edit this
    ]

    @Published var customArgs = "-r 1+s"

    init() {
        // Find ciadpi binary
        // Priority:
        // 1. Inside app bundle Resources
        // 2. Next to executable (for development)
        // 3. In byedpi directory (fallback)

        if let bundlePath = Bundle.main.resourcePath {
            let resourcePath = "\(bundlePath)/bin/ciadpi"
            if FileManager.default.fileExists(atPath: resourcePath) {
                self.ciadpiPath = resourcePath
                print("ByeDPI found in bundle: \(resourcePath)")
                return
            }
        }

        // Try next to executable
        if let execPath = Bundle.main.executablePath {
            let execDir = (execPath as NSString).deletingLastPathComponent
            let devPath = "\(execDir)/../../../byedpi/ciadpi"
            if FileManager.default.fileExists(atPath: devPath) {
                self.ciadpiPath = devPath
                print("ByeDPI found in dev path: \(devPath)")
                return
            }
        }

        // Fallback to byedpi directory
        let fallbackPath = FileManager.default.homeDirectoryForCurrentUser
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Downloads/SplitWire-Turkey-macOS/byedpi/ciadpi")
        self.ciadpiPath = fallbackPath.path
        print("ByeDPI fallback path: \(fallbackPath.path)")
    }

    func start(preset: String? = nil, isRetry: Bool = false) async {
        guard !isRunning else {
            statusMessage = "ByeDPI zaten çalışıyor"
            return
        }

        isProcessing = true
        statusMessage = "ByeDPI başlatılıyor..."

        do {
            let args = preset ?? presets[currentPreset] ?? customArgs
            try await startByeDPI(args: args)

            isRunning = true
            statusMessage = "ByeDPI başarıyla başlatıldı (SOCKS5 proxy: 127.0.0.1:1080)"

            await showAlert(
                title: "Başarılı",
                message: "ByeDPI başarıyla başlatıldı.\n\nSOCKS5 Proxy: 127.0.0.1:1080\n\nDiscord'u başlatmak için:\n1. Terminal'den: open -a Discord --args --proxy-server=socks5://127.0.0.1:1080\n2. Veya sistem proxy ayarlarını yapılandırın."
            )

        } catch let error as NSError {
            statusMessage = "Hata: \(error.localizedDescription)"

            // Check if this is a port conflict error
            if error.code == 4 && !isRetry {
                // Automatically try to clean up and retry
                await handlePortConflict(preset: preset)
            } else {
                await showAlert(title: "Hata", message: "ByeDPI başlatılamadı: \(error.localizedDescription)")
            }
        }

        isProcessing = false
    }

    private func handlePortConflict(preset: String?) async {
        let alert = NSAlert()
        alert.messageText = "Port 1080 Kullanımda"
        alert.informativeText = "Port 1080 zaten başka bir process tarafından kullanılıyor.\n\nTüm ByeDPI process'lerini otomatik olarak kapatıp tekrar denemek ister misiniz?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Tüm Process'leri Temizle ve Tekrar Dene")
        alert.addButton(withTitle: "İptal")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // User wants to clean up and retry
            await cleanupAllProcessesAndRetry(preset: preset)
        }
    }

    private func cleanupAllProcessesAndRetry(preset: String?) async {
        isProcessing = true
        statusMessage = "Tüm ByeDPI process'leri temizleniyor..."

        // Kill all ciadpi processes
        _ = try? await executeShellCommand("pkill -f ciadpi")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Force kill if still running
        _ = try? await executeShellCommand("pkill -9 -f ciadpi")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Verify port is free
        let portCheckResult = try? await executeShellCommand("lsof -i :1080")
        if let portCheck = portCheckResult, !portCheck.isEmpty {
            // Port still in use, show error
            await showAlert(
                title: "Hata",
                message: "Port 1080 hala kullanımda. Lütfen aşağıdaki komutu Terminal'de çalıştırın:\n\nsudo lsof -ti:1080 | xargs kill -9"
            )
            isProcessing = false
            return
        }

        statusMessage = "Process'ler temizlendi, yeniden başlatılıyor..."

        // Retry starting ByeDPI
        await start(preset: preset, isRetry: true)

        isProcessing = false
    }

    func stop() async {
        isProcessing = true
        statusMessage = "ByeDPI durduruluyor..."

        // Terminate our process if exists
        if let process = process {
            process.terminate()

            // Wait a bit for graceful shutdown
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Force kill if still running
            if process.isRunning {
                process.interrupt()
            }

            self.process = nil
        }

        // Kill any running ciadpi processes
        _ = try? await executeShellCommand("pkill -9 -f ciadpi")

        // Wait a moment to ensure port is released
        try? await Task.sleep(nanoseconds: 500_000_000)

        isRunning = false
        statusMessage = "ByeDPI durduruldu"
        isProcessing = false
    }

    func killAllProcesses() async {
        isProcessing = true
        statusMessage = "Tüm ByeDPI process'leri zorla kapatılıyor..."

        // First terminate our managed process
        if let process = process {
            process.terminate()
            try? await Task.sleep(nanoseconds: 200_000_000)
            if process.isRunning {
                process.interrupt()
            }
            self.process = nil
        }

        // Kill by port using lsof with sudo (AppleScript for privilege)
        let killPortScript = """
        do shell script "lsof -ti:1080 | xargs kill -9 2>/dev/null || true" with administrator privileges
        """
        _ = try? await executeAppleScriptCommand(killPortScript)
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Kill all ciadpi processes by name
        _ = try? await executeShellCommand("pkill -9 -f ciadpi 2>/dev/null || true")
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Double check with killall
        _ = try? await executeShellCommand("killall -9 ciadpi 2>/dev/null || true")
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Verify port is free
        let portCheck = try? await executeShellCommand("lsof -i :1080 2>/dev/null")
        if let check = portCheck, !check.isEmpty {
            statusMessage = "Uyarı: Port 1080 hala kullanımda olabilir"
        } else {
            statusMessage = "Tüm ByeDPI process'leri kapatıldı"
        }

        isRunning = false
        isProcessing = false
    }

    private func executeAppleScriptCommand(_ script: String) async throws {
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

    func startWithDiscord() async {
        await start()

        if isRunning {
            // Wait a moment for proxy to be ready
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // Launch Discord with proxy
            do {
                try await launchDiscordWithProxy()
                await showAlert(
                    title: "Discord Başlatıldı",
                    message: "Discord uygulaması ByeDPI proxy ile başlatıldı."
                )
            } catch {
                await showAlert(
                    title: "Uyarı",
                    message: "ByeDPI başlatıldı ancak Discord açılamadı. Discord'u manuel olarak şu komutla başlatın:\n\nopen -a Discord --args --proxy-server=socks5://127.0.0.1:1080"
                )
            }
        }
    }

    func startWithApp(appPath: String, appName: String, customArgs: String? = nil) async {
        // Start ByeDPI if not already running
        if !isRunning {
            await start()
        }

        if isRunning {
            // Wait a moment for proxy to be ready
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // Launch app with proxy
            do {
                try await launchAppWithProxy(appPath: appPath, customArgs: customArgs)
                await showAlert(
                    title: "\(appName) Başlatıldı",
                    message: "\(appName) uygulaması ByeDPI proxy ile başlatıldı."
                )
            } catch {
                await showAlert(
                    title: "Uyarı",
                    message: "ByeDPI başlatıldı ancak \(appName) açılamadı.\n\nHata: \(error.localizedDescription)"
                )
            }
        }
    }

    func configureSystemProxy(enable: Bool) async {
        do {
            let interface = try await getPrimaryInterface()

            if enable {
                // Set SOCKS proxy
                let script = """
                do shell script "networksetup -setsocksfirewallproxy '\(interface)' 127.0.0.1 1080 && networksetup -setsocksfirewallproxystate '\(interface)' on" with administrator privileges
                """

                try await executeAppleScript(script)
                isSystemProxyEnabled = true
                statusMessage = "Sistem proxy ayarlandı (127.0.0.1:1080)"

                await showAlert(
                    title: "Başarılı",
                    message: "Sistem SOCKS proxy ayarları yapılandırıldı.\n\nTüm uygulamalar artık ByeDPI üzerinden bağlanacak."
                )
            } else {
                // Disable SOCKS proxy
                let script = """
                do shell script "networksetup -setsocksfirewallproxystate '\(interface)' off" with administrator privileges
                """

                try await executeAppleScript(script)
                isSystemProxyEnabled = false
                statusMessage = "Sistem proxy kapatıldı"
            }
        } catch {
            await showAlert(
                title: "Hata",
                message: "Proxy ayarları yapılandırılamadı: \(error.localizedDescription)"
            )
        }
    }

    func checkSystemProxyStatus() async {
        do {
            let interface = try await getPrimaryInterface()
            let output = try await executeShellCommand("networksetup -getsocksfirewallproxy '\(interface)'")

            // Check if enabled and pointing to our proxy
            let isEnabled = output.contains("Enabled: Yes")
            let hasCorrectServer = output.contains("Server: 127.0.0.1") && output.contains("Port: 1080")

            isSystemProxyEnabled = isEnabled && hasCorrectServer
        } catch {
            isSystemProxyEnabled = false
        }
    }

    func checkByeDPIStatus() async {
        // Check if port 1080 is in use (indicates ByeDPI is running)
        do {
            let result = try await executeShellCommand("lsof -i :1080 2>/dev/null | grep -c ciadpi || echo 0")
            let count = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let isCurrentlyRunning = count > 0

            if isCurrentlyRunning != isRunning {
                isRunning = isCurrentlyRunning
            }
        } catch {
            // Silently fail
        }
    }

    func toggleSystemProxy() async {
        await checkSystemProxyStatus()
        await configureSystemProxy(enable: !isSystemProxyEnabled)
    }

    // MARK: - Private Methods

    private func startByeDPI(args: String) async throws {
        guard FileManager.default.fileExists(atPath: ciadpiPath) else {
            throw NSError(
                domain: "ByeDPIService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "ciadpi binary bulunamadı: \(ciadpiPath)"]
            )
        }

        // Check if port 1080 is already in use
        let portCheckResult = try? await executeShellCommand("lsof -i :1080")
        if let portCheck = portCheckResult, !portCheck.isEmpty {
            throw NSError(
                domain: "ByeDPIService",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Port 1080 zaten kullanımda!\n\nDiğer ByeDPI/SOCKS5 proxy'leri kapatın veya şu komutu çalıştırın:\npkill -f ciadpi"]
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ciadpiPath)

        // Parse arguments
        let argArray = args.split(separator: " ").map(String.init)
        process.arguments = argArray

        print("🚀 Starting ByeDPI: \(ciadpiPath) \(argArray.joined(separator: " "))")

        // Set up pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            self.process = process

            print("🚀 Process started with PID: \(process.processIdentifier)")

            // Background task to read output (non-blocking)
            Task.detached {
                let outputHandle = outputPipe.fileHandleForReading
                let errorHandle = errorPipe.fileHandleForReading

                // Read output in background without blocking
                DispatchQueue.global(qos: .background).async {
                    while true {
                        let outData = outputHandle.availableData
                        if !outData.isEmpty {
                            if let output = String(data: outData, encoding: .utf8) {
                                print("ByeDPI stdout: \(output)")
                            }
                        }

                        let errData = errorHandle.availableData
                        if !errData.isEmpty {
                            if let error = String(data: errData, encoding: .utf8) {
                                print("ByeDPI stderr: \(error)")
                            }
                        }

                        Thread.sleep(forTimeInterval: 0.1)
                    }
                }
            }

            // Give it a moment to start and check for immediate failures
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            // Check if still running
            if !process.isRunning {
                // Try to read any error output (non-blocking)
                let errorData = try? errorPipe.fileHandleForReading.availableData
                let outputData = try? outputPipe.fileHandleForReading.availableData

                var errorMessage = "ByeDPI başlatılamadı (process durdu)"

                if let errorData = errorData, !errorData.isEmpty,
                   let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                    errorMessage += "\n\nHata çıktısı:\n\(errorOutput)"
                }

                if let outputData = outputData, !outputData.isEmpty,
                   let stdOutput = String(data: outputData, encoding: .utf8), !stdOutput.isEmpty {
                    errorMessage += "\n\nÇıktı:\n\(stdOutput)"
                }

                errorMessage += "\n\nKomut: \(ciadpiPath) \(argArray.joined(separator: " "))"
                errorMessage += "\n\nTermination Status: \(process.terminationStatus)"

                throw NSError(
                    domain: "ByeDPIService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
            }

            print("✅ ByeDPI started successfully with PID \(process.processIdentifier)")

        } catch let error as NSError {
            if error.domain == "ByeDPIService" {
                throw error
            }
            throw NSError(
                domain: "ByeDPIService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Process başlatma hatası: \(error.localizedDescription)"]
            )
        }
    }

    private func launchDiscordWithProxy() async throws {
        let discordPath = "/Applications/Discord.app/Contents/MacOS/Discord"

        guard FileManager.default.fileExists(atPath: discordPath) else {
            throw NSError(
                domain: "ByeDPIService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Discord bulunamadı"]
            )
        }

        let command = "open -a '\(discordPath)' --args --proxy-server=socks5://127.0.0.1:1080 --ignore-certificate-errors"
        _ = try await executeShellCommand(command)
    }

    private func launchAppWithProxy(appPath: String, customArgs: String? = nil) async throws {
        guard FileManager.default.fileExists(atPath: appPath) else {
            throw NSError(
                domain: "ByeDPIService",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Uygulama bulunamadı: \(appPath)"]
            )
        }

        // Check if it's a .app bundle
        if appPath.hasSuffix(".app") {
            // Use custom args if provided, otherwise use default proxy args
            let args = customArgs ?? "--proxy-server=socks5://127.0.0.1:1080"
            let command = "open -a '\(appPath)' --args \(args)"
            _ = try await executeShellCommand(command)
        } else {
            // For executables, just open
            let command = "open '\(appPath)'"
            _ = try await executeShellCommand(command)
        }
    }

    private func getPrimaryInterface() async throws -> String {
        let output = try await executeShellCommand("route -n get default | grep interface | awk '{print $2}'")
        let interface = output.trimmingCharacters(in: .whitespacesAndNewlines)

        if interface.isEmpty {
            return "Wi-Fi" // fallback
        }

        // Convert interface name to service name (e.g., en0 -> Wi-Fi)
        let serviceOutput = try await executeShellCommand("networksetup -listallhardwareports | grep -B 1 '\(interface)' | head -1 | awk -F': ' '{print $2}'")
        let serviceName = serviceOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        return serviceName.isEmpty ? "Wi-Fi" : serviceName
    }

    func executeShellCommand(_ command: String) async throws -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if task.terminationStatus != 0 {
            throw NSError(
                domain: "ShellCommand",
                code: Int(task.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output]
            )
        }

        return output
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

    private func showAlert(title: String, message: String) async {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title == "Hata" || title == "Uyarı" ? .warning : .informational
        alert.addButton(withTitle: "Tamam")

        if message.contains("open -a Discord") {
            alert.addButton(withTitle: "Kopyala")
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                // Copy command to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString("open -a Discord --args --proxy-server=socks5://127.0.0.1:1080", forType: .string)
            }
        } else {
            alert.runModal()
        }
    }
}
