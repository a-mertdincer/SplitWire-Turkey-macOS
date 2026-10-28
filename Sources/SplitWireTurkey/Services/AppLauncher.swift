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

/// Favori uygulamaları komut satırı argümanlarıyla (ör. --proxy-server=socks5://127.0.0.1:1080) ve
/// ortam değişkenleriyle (HTTPS_PROXY, #15) başlatır. Kabuk kullanılmaz; NSWorkspace ile açılır.
/// Argümanlar ve ortam yalnızca YENİ başlatılan örneğe iletilir, bu yüzden uygulama zaten
/// çalışıyorsa kullanıcıya yeniden başlatma önerilir.
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

    /// Uygulama ve birlikte kapatılması gereken yardımcıları (ör. Roblox'un menü çubuğu uygulaması).
    private static func familyInstances(appURL: URL, bundleIdentifier: String?) -> [NSRunningApplication] {
        let companions = Set(KnownApps.companionBundleIDs(of: bundleIdentifier))
        let helpers = companions.isEmpty ? [] : NSWorkspace.shared.runningApplications.filter { app in
            !app.isTerminated && app.bundleIdentifier.map(companions.contains) == true
        }
        return runningInstances(appURL: appURL, bundleIdentifier: bundleIdentifier) + helpers
    }

    /// Uygulamayı argümanlar ve ortam değişkenleriyle başlatır.
    /// - Parameter confirmRestart: Uygulama zaten çalışıyorsa kapatmadan önce sorulsun mu?
    ///   false yalnızca uygulama proxy'siz kendini yeniden başlattığında kullanılır (#15).
    /// - Returns: Başlatılan örnek; kullanıcı iptal ettiyse nil.
    static func launch(
        appPath: String,
        name: String,
        bundleIdentifier: String?,
        arguments: [String],
        environment: [String: String] = [:],
        confirmRestart: Bool = true
    ) async throws -> NSRunningApplication? {
        let appURL = URL(fileURLWithPath: appPath)
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw AppLaunchError.notFound(appPath)
        }
        let bundleID = bundleIdentifier ?? Bundle(url: appURL)?.bundleIdentifier

        let running = runningInstances(appURL: appURL, bundleIdentifier: bundleID)
        if !running.isEmpty, confirmRestart {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = L("\(name) zaten çalışıyor", "\(name) is already running")
            alert.informativeText = L("\(name) zaten çalışıyor. Proxy ayarının uygulanması için yeniden başlatılması gerekiyor.",
                                      "\(name) is already running. It must be restarted for the proxy setting to take effect.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("Kapat ve Yeniden Başlat", "Quit and relaunch"))
            alert.addButton(withTitle: L("İptal", "Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        }

        // Yalnızca yardımcı açıksa (ör. Roblox kapalı, menü çubuğu uygulaması açık) sormadan kapatılır:
        // açık kalırsa Roblox'u proxy'siz yeniden açar (#13)
        if !familyInstances(appURL: appURL, bundleIdentifier: bundleID).isEmpty {
            let forceWithoutAsking = KnownApps.forceQuitsWithoutAsking(bundleID)
            let remaining = await terminateFamily(appURL: appURL, bundleIdentifier: bundleID,
                                                  timeout: forceWithoutAsking ? 3 : 8, force: false)
            if !remaining.isEmpty {
                if !forceWithoutAsking {
                    NSApp.activate(ignoringOtherApps: true)
                    let force = NSAlert()
                    force.messageText = L("\(name) kapanmadı", "\(name) did not quit")
                    force.informativeText = L("\(name) 8 saniye içinde kapanmadı. Zorla kapatılsın mı? Kaydedilmemiş veriler kaybolabilir.",
                                              "\(name) did not quit within 8 seconds. Force quit it? Unsaved data may be lost.")
                    force.alertStyle = .warning
                    force.addButton(withTitle: L("Zorla Kapat", "Force quit"))
                    force.addButton(withTitle: L("İptal", "Cancel"))
                    guard force.runModal() == .alertFirstButtonReturn else { return nil }
                }
                let stillRunning = await terminateFamily(appURL: appURL, bundleIdentifier: bundleID, timeout: 4, force: true)
                guard stillRunning.isEmpty else {
                    throw AppLaunchError.stillRunning(name)
                }
            }
            // Uygulamanın tamamen kapanması için kısa bir pay
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        // Mevcut ortama eklenir (SplitWire sandbox'lı değil; sandbox'lı süreçlerde yok sayılırdı)
        configuration.environment = environment
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

        do {
            return try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        } catch {
            let reason = error.localizedDescription
            throw AppLaunchError.launchFailed(L("\(name) başlatılamadı: \(reason)", "Could not launch \(name): \(reason)"))
        }
    }

    /// Uygulamayı ve yardımcılarını kapatır. Roblox ile menü çubuğu uygulaması birbirini yeniden
    /// açtığı için tek seferlik kapatma yetmez: yeni açılanlar da kapatılır ve yardımcısı olan
    /// uygulamalarda aile kısa bir süre kapalı kalana kadar beklenir.
    /// - Returns: Süre dolduğunda hâlâ açık olanlar (boşsa hepsi kapandı).
    private static func terminateFamily(
        appURL: URL,
        bundleIdentifier: String?,
        timeout: TimeInterval,
        force: Bool
    ) async -> [NSRunningApplication] {
        let hasCompanions = !KnownApps.companionBundleIDs(of: bundleIdentifier).isEmpty
        let deadline = Date().addingTimeInterval(timeout)
        var lastRequest: [pid_t: Date] = [:]
        while true {
            let family = familyInstances(appURL: appURL, bundleIdentifier: bundleIdentifier)
            if family.isEmpty {
                guard hasCompanions else { return [] }
                // Yardımcı kapanan uygulamayı ~1 sn içinde yeniden açabilir: kapalı kaldıysa bitti
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if familyInstances(appURL: appURL, bundleIdentifier: bundleIdentifier).isEmpty { return [] }
                continue
            }
            let now = Date()
            if now >= deadline { return family }
            // Her örneğe bir kez sorulur (uygulamanın kendi "Kaydedilmemiş değişiklikler" sorusuna verilen
            // yanıt çiğnenmesin). Yardımcısı olanlarda (Roblox) yeni açılan örnek açılışını bitirmeden
            // gelen isteği kaçırabildiği için saniyede bir yinelenir.
            for app in family {
                let pid = app.processIdentifier
                if let last = lastRequest[pid], !hasCompanions || now.timeIntervalSince(last) < 1 { continue }
                lastRequest[pid] = now
                if force { app.forceTerminate() } else { app.terminate() }
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
