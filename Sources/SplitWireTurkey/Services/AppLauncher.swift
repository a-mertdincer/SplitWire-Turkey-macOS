import AppKit

enum AppLaunchError: LocalizedError {
    case notFound(String)
    case stillRunning(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let path):
            return L("Uygulama bulunamadı: \(path)", "App not found: \(path)")
        case .stillRunning(let name):
            return L("\(name) kapatılamadı. Uygulamayı elle kapatıp tekrar deneyin.",
                     "Could not quit \(name). Quit the app manually and try again.")
        case .launchFailed(let message):
            return message
        }
    }
}

/// Favori uygulamaları komut satırı argümanlarıyla (ör. --proxy-server=socks5://127.0.0.1:1080) başlatır.
/// Kabuk kullanılmaz; NSWorkspace ile açılır. Argümanlar yalnızca YENİ başlatılan örneğe iletilir,
/// bu yüzden uygulama zaten çalışıyorsa kullanıcıya yeniden başlatma önerilir.
@MainActor
enum AppLauncher {
    /// Aynı uygulamanın çalışan örnekleri (paket yolu veya bundle id eşleşmesi).
    static func runningInstances(appURL: URL, bundleIdentifier: String?) -> [NSRunningApplication] {
        let target = appURL.standardizedFileURL.resolvingSymlinksInPath()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.filter { app in
            guard app.processIdentifier != ownPID, !app.isTerminated else { return false }
            if let url = app.bundleURL?.standardizedFileURL.resolvingSymlinksInPath(), url == target {
                return true
            }
            if let bundleIdentifier, let id = app.bundleIdentifier, id == bundleIdentifier {
                return true
            }
            return false
        }
    }

    /// Uygulamayı argümanlarla başlatır.
    /// - Returns: Başlatıldıysa true; kullanıcı iptal ettiyse false.
    static func launch(appPath: String, name: String, bundleIdentifier: String?, arguments: [String]) async throws -> Bool {
        let appURL = URL(fileURLWithPath: appPath)
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw AppLaunchError.notFound(appPath)
        }
        let bundleID = bundleIdentifier ?? Bundle(url: appURL)?.bundleIdentifier

        let running = runningInstances(appURL: appURL, bundleIdentifier: bundleID)
        if !running.isEmpty {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = L("\(name) zaten çalışıyor", "\(name) is already running")
            alert.informativeText = L("\(name) zaten çalışıyor. Proxy ayarının uygulanması için yeniden başlatılması gerekiyor.",
                                      "\(name) is already running. It must be restarted for the proxy setting to take effect.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("Kapat ve Yeniden Başlat", "Quit and relaunch"))
            alert.addButton(withTitle: L("İptal", "Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return false }

            running.forEach { $0.terminate() }
            if !(await waitForTermination(running, timeout: 8)) {
                NSApp.activate(ignoringOtherApps: true)
                let force = NSAlert()
                force.messageText = L("\(name) kapanmadı", "\(name) did not quit")
                force.informativeText = L("\(name) 8 saniye içinde kapanmadı. Zorla kapatılsın mı? Kaydedilmemiş veriler kaybolabilir.",
                                          "\(name) did not quit within 8 seconds. Force quit it? Unsaved data may be lost.")
                force.alertStyle = .warning
                force.addButton(withTitle: L("Zorla Kapat", "Force quit"))
                force.addButton(withTitle: L("İptal", "Cancel"))
                guard force.runModal() == .alertFirstButtonReturn else { return false }
                running.forEach { $0.forceTerminate() }
                guard await waitForTermination(running, timeout: 4) else {
                    throw AppLaunchError.stillRunning(name)
                }
            }
            // Uygulamanın tamamen kapanması için kısa bir pay
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

        do {
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        } catch {
            let reason = error.localizedDescription
            throw AppLaunchError.launchFailed(L("\(name) başlatılamadı: \(reason)", "Could not launch \(name): \(reason)"))
        }
        return true
    }

    private static func waitForTermination(_ apps: [NSRunningApplication], timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if apps.allSatisfy({ $0.isTerminated }) { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return apps.allSatisfy { $0.isTerminated }
    }
}
