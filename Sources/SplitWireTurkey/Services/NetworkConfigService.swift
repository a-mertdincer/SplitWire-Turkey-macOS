import Foundation
import Combine

@MainActor
class NetworkConfigService: ObservableObject {
    @Published var currentDNS: [String] = []
    @Published var primaryInterface: String?
    @Published var statusMessage = ""
    @Published var hasError = false

    init() {
        Task {
            await loadNetworkInfo()
        }
    }

    func loadNetworkInfo() async {
        await getPrimaryInterface()
        await getCurrentDNS()
    }

    func getPrimaryInterface() async {
        do {
            let output = try await executeShellCommand("route -n get default | grep interface | awk '{print $2}'")
            primaryInterface = output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Failed to get primary interface: \(error)")
            primaryInterface = "en0" // fallback
        }
    }

    func getCurrentDNS() async {
        guard let interface = primaryInterface else {
            await getPrimaryInterface()
            return
        }

        do {
            // Get the network service name for the interface
            let serviceOutput = try await executeShellCommand("networksetup -listallhardwareports | grep -A 1 '\(interface)' | grep 'Hardware Port' | awk -F': ' '{print $2}'")
            let serviceName = serviceOutput.trimmingCharacters(in: .whitespacesAndNewlines)

            // Use service name if found, otherwise try Wi-Fi and Ethernet
            let serviceNames = [serviceName, "Wi-Fi", "Ethernet", "USB 10/100/1000 LAN"]
            var dnsFound = false

            for service in serviceNames where !service.isEmpty {
                do {
                    let output = try await executeShellCommand("networksetup -getdnsservers '\(service)'")
                    let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

                    if !lines.contains("There aren't any DNS Servers set") &&
                       !lines.contains("*** Error") &&
                       !lines.isEmpty {
                        currentDNS = lines
                        dnsFound = true
                        break
                    } else if lines.contains("There aren't any DNS Servers set") {
                        currentDNS = ["DHCP (Otomatik)"]
                        dnsFound = true
                        break
                    }
                } catch {
                    continue
                }
            }

            if !dnsFound {
                currentDNS = ["DHCP (Otomatik)"]
            }
        } catch {
            currentDNS = ["DHCP (Otomatik)"]
            print("Failed to get DNS: \(error)")
        }
    }

    func setOptimalDNS() async {
        guard let interface = primaryInterface else {
            statusMessage = "Ağ arayüzü bulunamadı"
            hasError = true
            return
        }

        do {
            statusMessage = "DNS ayarları yapılandırılıyor..."
            hasError = false

            // Set Google DNS (8.8.8.8) and Quad9 (9.9.9.9)
            let command = "networksetup -setdnsservers '\(interface)' 8.8.8.8 9.9.9.9"
            let script = """
            do shell script "\(command)" with administrator privileges
            """

            try await executeAppleScript(script)

            await getCurrentDNS()
            statusMessage = "DNS başarıyla ayarlandı (Google + Quad9)"
            hasError = false

        } catch {
            statusMessage = "DNS ayarlanamadı: \(error.localizedDescription)"
            hasError = true
        }
    }

    func resetDNS() async {
        guard let interface = primaryInterface else {
            statusMessage = "Ağ arayüzü bulunamadı"
            hasError = true
            return
        }

        do {
            statusMessage = "DNS ayarları sıfırlanıyor..."
            hasError = false

            // Reset to DHCP
            let command = "networksetup -setdnsservers '\(interface)' empty"
            let script = """
            do shell script "\(command)" with administrator privileges
            """

            try await executeAppleScript(script)

            await getCurrentDNS()
            statusMessage = "DNS ayarları DHCP'ye sıfırlandı"
            hasError = false

        } catch {
            statusMessage = "DNS sıfırlanamadı: \(error.localizedDescription)"
            hasError = true
        }
    }

    func flushDNSCache() async {
        do {
            statusMessage = "DNS önbelleği temizleniyor..."
            hasError = false

            let script = """
            do shell script "dscacheutil -flushcache && killall -HUP mDNSResponder" with administrator privileges
            """

            try await executeAppleScript(script)

            statusMessage = "DNS önbelleği başarıyla temizlendi"
            hasError = false

        } catch {
            statusMessage = "DNS önbelleği temizlenemedi: \(error.localizedDescription)"
            hasError = true
        }
    }

    // MARK: - Private Methods

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
        let output = String(data: data, encoding: .utf8) ?? ""

        if task.terminationStatus != 0 {
            throw NSError(domain: "ShellCommand", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }

        return output
    }

    private func executeAppleScript(_ script: String) async throws {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(&error)

        if let error = error {
            throw NSError(domain: "AppleScript", code: -1, userInfo: [NSLocalizedDescriptionKey: error.description])
        }
    }
}
