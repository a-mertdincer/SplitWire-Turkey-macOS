import SwiftUI
import AppKit
import Combine

@main
struct SplitWireTurkeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Tek pencere: menü çubuğundan "Ana Pencereyi Göster" ile kapatıldıktan sonra da açılabilir.
        Window("SplitWire-Turkey", id: MainWindowController.windowID) {
            MainWindowRoot()
                .environmentObject(AppState.shared)
                .environmentObject(ByeDPIService.shared)
                .environmentObject(SystemProxyService.shared)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            MainWindowCommands()
        }
    }
}

/// Uygulama menüsündeki "Hakkında" ve Pencere menüsündeki "Ana Pencereyi Göster"
/// (MainWindowController için yedek yol) komutları.
struct MainWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    /// Dil değişince (#8) menü başlıklarının yeniden üretilmesi için izlenir.
    @AppStorage(L10n.defaultsKey) private var languageCode = ""

    var body: some Commands {
        let _ = languageCode
        CommandGroup(replacing: .appInfo) {
            Button(L("SplitWire-Turkey Hakkında", "About SplitWire-Turkey")) {
                AppDelegate.showAboutPanel()
            }
        }
        CommandGroup(before: .windowArrangement) {
            Button(MainWindowController.localizedShowMenuTitle) {
                openWindow(id: MainWindowController.windowID)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(KeyEquivalent(Character(MainWindowController.showMenuKeyEquivalent)), modifiers: [.command])
        }
    }
}

/// Ana pencerenin kökü: sahnenin `openWindow` eylemini menü çubuğu için yakalar.
struct MainWindowRoot: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ContentView()
            .onAppear {
                MainWindowController.shared.openWindowAction = openWindow
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarService: MenuBarService?
    private var cancellables = Set<AnyCancellable>()
    private var isTerminating = false
    private var readyToTerminate = false

    static func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "SplitWire-Turkey",
            .applicationVersion: AppInfo.version,
            .credits: AppInfo.aboutPanelCredits(),
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): AppInfo.copyright,
        ]
        if let build = AppInfo.build {
            // "5 (fe99aaa)": hata raporları tam kaynağı göstersin
            options[.version] = AppInfo.commit.map { "\(build) (\($0))" } ?? build
        }
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Dock simgesi tercihi pencere görünmeden uygulanmalı
        DockIconController.apply(hidden: AppState.shared.hideDockIcon, reactivate: false)
        Self.syncSystemUILanguage(L10n.current)
    }

    /// AppKit/SwiftUI'nin kendi menüleri (Gizle, Çık, Düzen, Pencere) ve sistem panelleri
    /// uygulamanın dil seçimini değil, macOS'un AppleLanguages tercihini izler (#8). Uygulama içi
    /// seçim sistem diliyle uyuşmuyorsa yalnızca bu uygulamanın alanında AppleLanguages ayarlanır;
    /// macOS bunu açılışta okur, yani sistem menüleri bir sonraki açılışta seçilen dile geçer.
    nonisolated static func syncSystemUILanguage(_ language: AppLanguage, defaults: UserDefaults = .standard) {
        let key = "AppleLanguages"
        let available = AppLanguage.allCases.map(\.rawValue)
        func systemPick() -> String? {
            Bundle.preferredLocalizations(from: available,
                                          forPreferences: defaults.stringArray(forKey: key) ?? []).first
        }
        guard systemPick() != language.rawValue else { return }
        // Önce kendi eski geçersiz kılmamızı kaldır: sistem dili zaten uyuyorsa iz bırakma
        defaults.removeObject(forKey: key)
        if systemPick() != language.rawValue {
            defaults.set([language.rawValue], forKey: key)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appState = AppState.shared
        let byedpi = ByeDPIService.shared
        let systemProxy = SystemProxyService.shared

        // Menü çubuğu, pencere hiç gösterilmese bile açılışta bir kez kurulur
        let menuBar = MenuBarService(byedpi: byedpi, systemProxy: systemProxy, appState: appState)
        menuBar.setup()
        menuBarService = menuBar

        appState.$hideDockIcon
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { hidden in
                DockIconController.apply(hidden: hidden, reactivate: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .appLanguageDidChange)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Self.syncSystemUILanguage(L10n.current)
            }
            .store(in: &cancellables)

        if appState.hideDockIcon {
            // Accessory modda pencere arka planda kalmasın
            NSApp.activate(ignoringOtherApps: true)
        }

        byedpi.startMonitoring()

        // ISS DNS zehirlenmesi kontrolü (#11/#9): ByeDPI/Ağ sekmelerindeki uyarı için
        Task { @MainActor in
            await DNSHealthChecker.shared.checkIfNeeded()
            await NetworkConfigService.shared.loadNetworkInfo()
        }

        Task { @MainActor in
            await self.checkStaleSystemProxyAtLaunch()
        }
    }

    /// Uygulama menü çubuğunda yaşar; son pencere kapanınca çıkma.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Dock simgesine tıklanınca ana pencereyi geri getir.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainWindowController.shared.show()
            return false
        }
        return true
    }

    /// Her çıkış yolunda (Cmd+Q, menü çubuğu "Çıkış", Dock): sistem proxy'yi kapat, ciadpi'yi durdur.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if readyToTerminate { return .terminateNow }
        if isTerminating { return .terminateCancel }  // zaten kapanıyor; ilk istek yanıtlanacak
        isTerminating = true
        // Oturum kapatma / yeniden başlatma / kapatma sırasında soru sorulmaz
        let sessionEnding = Self.isSystemSessionEnding()

        Task { @MainActor in
            let byedpi = ByeDPIService.shared
            var result = await byedpi.prepareForQuit()
            while case .proxyStillOn(let services, let reason) = result, !sessionEnding {
                switch self.askAboutProxyStillOn(services: services, reason: reason) {
                case .retry:
                    result = await byedpi.retryDisableProxyForQuit()
                case .quitKeepingByeDPI:
                    // ciadpi'ye dokunulmaz (SIGPIPE'ı yok sayar, uygulamadan sonra da çalışır):
                    // proxy çalışmaya devam eder; sonraki açılışta harici süreç olarak benimsenir.
                    result = .clean
                case .dontQuit:
                    self.isTerminating = false
                    byedpi.resumeAfterCancelledQuit()
                    NSApp.reply(toApplicationShouldTerminate: false)
                    return
                }
            }
            self.readyToTerminate = true
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private enum ProxyStillOnChoice { case retry, quitKeepingByeDPI, dontQuit }

    /// Çıkışta sistem proxy kapatılamadı (#14): sessizce çıkıp interneti bozuk bırakmak yerine sor.
    private func askAboutProxyStillOn(services: [String], reason: String) -> ProxyStillOnChoice {
        NSApp.activate(ignoringOtherApps: true)
        let list = services.joined(separator: ", ")
        let address = ByeDPIService.shared.proxyAddress
        let alert = NSAlert()
        alert.messageText = L("Sistem proxy hâlâ açık", "System proxy is still on")
        alert.informativeText = L(
            "\(list) hâlâ \(address) adresini gösteriyor ve kapatılamadı (\(reason)). ByeDPI durdurulursa internet bağlantınız çalışmaz.\n\n'ByeDPI çalışsın, çık' seçilirse ByeDPI arka planda çalışmaya devam eder; uygulamayı yeniden açtığınızda durdurup proxy'yi kapatabilirsiniz.",
            "\(list) still point to \(address) and could not be turned off (\(reason)). If ByeDPI is stopped, your internet will not work.\n\nIf you choose 'Quit, keep ByeDPI running', ByeDPI keeps running in the background; open the app again to stop it and turn the proxy off."
        )
        alert.alertStyle = .critical
        alert.addButton(withTitle: L("Tekrar Dene", "Try again"))
        alert.addButton(withTitle: L("ByeDPI çalışsın, çık", "Quit, keep ByeDPI running"))
        alert.addButton(withTitle: L("Çıkma", "Don't quit"))
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .retry
        case .alertSecondButtonReturn: return .quitKeepingByeDPI
        default: return .dontQuit
        }
    }

    /// Çıkış isteği oturum kapatma / yeniden başlatma / kapatmadan mı geliyor?
    private static func isSystemSessionEnding() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              let reason = event.attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason)) else {
            return false
        }
        let systemReasons: [OSType] = [
            OSType(kAELogOut), OSType(kAEReallyLogOut), OSType(kAEShowRestartDialog),
            OSType(kAEShowShutdownDialog), OSType(kAERestart), OSType(kAEShutDown),
        ]
        return systemReasons.contains(reason.enumCodeValue) || systemReasons.contains(reason.typeCodeValue)
    }

    /// Açılışta: bizim proxy açık ama 1080'de kimse dinlemiyorsa (#14) kullanıcıya sor.
    private func checkStaleSystemProxyAtLaunch() async {
        let byedpi = ByeDPIService.shared
        let services = await SystemProxyService.shared.refresh()
        guard !services.isEmpty else { return }

        let listeners = await ByeDPIService.listeners(port: byedpi.port)
        guard listeners.isEmpty, !byedpi.isRunning, !isTerminating else { return }

        NSApp.activate(ignoringOtherApps: true)
        // Ör. "Wi-Fi: SOCKS + HTTPS" (v1.1.0'dan kalma ayarda yalnızca "Wi-Fi: SOCKS")
        let serviceList = SystemProxyService.shared.activeSummary
        let alert = NSAlert()
        alert.messageText = L(
            "Sistem proxy açık ama ByeDPI çalışmıyor",
            "System proxy is on, but ByeDPI isn't running"
        )
        alert.informativeText = L(
            "Sistem proxy ayarı (\(serviceList)) ByeDPI'ı (\(byedpi.proxyAddress)) gösteriyor, ancak ByeDPI çalışmıyor. Bu durumda internet bağlantınız çalışmaz.\n\nByeDPI'ı başlatabilir veya sistem proxy'yi kapatabilirsiniz.",
            "The system proxy setting (\(serviceList)) points to ByeDPI (\(byedpi.proxyAddress)), but ByeDPI isn't running, so your internet connection won't work.\n\nYou can start ByeDPI or turn off the system proxy."
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("ByeDPI'ı Başlat", "Start ByeDPI"))
        alert.addButton(withTitle: L("Sistem Proxy'yi Kapat", "Turn off system proxy"))
        alert.addButton(withTitle: L("Yoksay", "Ignore"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            await byedpi.start()
        case .alertSecondButtonReturn:
            await byedpi.disableSystemProxy()
        default:
            break
        }
    }
}

// MARK: - Uygulama bilgileri

/// Sürüm, telif ve bağlantılar (Hakkında paneli ve Hakkında sekmesi ortak kullanır).
enum AppInfo {
    /// CFBundleShortVersionString; paketlenmemiş (swift run) derlemelerde "dev".
    static var version: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let value, !value.isEmpty else { return "dev" }
        return value
    }

    /// CFBundleVersion (yalnızca paketli derlemelerde).
    static var build: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// Derlendiği git commit'i (build.sh Info.plist'e SWGitCommit olarak yazar; "-dirty" ekli olabilir).
    static var commit: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "SWGitCommit") as? String
        guard let value, !value.isEmpty, value != "unknown" else { return nil }
        return value
    }

    static let repositoryURL = URL(string: "https://github.com/a-mertdincer/SplitWire-Turkey-macOS")!
    static let issuesURL = URL(string: "https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues")!
    static let releasesURL = URL(string: "https://github.com/a-mertdincer/SplitWire-Turkey-macOS/releases")!
    static let originalProjectURL = URL(string: "https://github.com/cagritaskn/SplitWire-Turkey")!
    static let byedpiURL = URL(string: "https://github.com/hufrea/byedpi")!
    static let wgcfURL = URL(string: "https://github.com/ViRb3/wgcf")!
    static let wireGuardURL = URL(string: "https://www.wireguard.com")!
    static let authorURL = URL(string: "https://github.com/a-mertdincer")!

    /// LICENSE dosyasıyla aynı: MIT, © 2025 Mert Dinçer.
    static var copyright: String {
        L("Telif hakkı © 2025 Mert Dinçer — MIT Lisansı", "Copyright © 2025 Mert Dinçer — MIT License")
    }

    /// Standart Hakkında panelindeki teşekkür metni (bağlantılı).
    static func aboutPanelCredits() -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]

        let result = NSMutableAttributedString()
        func append(_ text: String) {
            result.append(NSAttributedString(string: text, attributes: base))
        }
        func link(_ text: String, _ url: URL) {
            var attributes = base
            attributes[.link] = url
            result.append(NSAttributedString(string: text, attributes: attributes))
        }

        append(L("macOS uyarlaması: Mert Dinçer — ", "macOS port by Mert Dinçer — "))
        link("GitHub", repositoryURL)
        append("\n")
        append(L("Orijinal Windows uygulaması: ", "Based on the original Windows app "))
        link("SplitWire-Turkey", originalProjectURL)
        append(L(" (Çağrı Taşkın)\n", " by Çağrı Taşkın\n"))
        append(L("DPI aşımı: ", "DPI bypass: "))
        link("ByeDPI", byedpiURL)
        append(L(" (hufrea) · WARP: ", " by hufrea · WARP: "))
        link("wgcf", wgcfURL)
        append(L(" (ViRb3)", " by ViRb3"))
        return result
    }
}

// MARK: - Yerelleştirilmiş ortak başlıklar

extension MainWindowController {
    /// "Ana Pencereyi Göster" (menü çubuğu + Pencere menüsü). Tek kaynak; dil değişince yeniden okunur.
    static var localizedShowMenuTitle: String {
        L("Ana Pencereyi Göster", "Show main window")
    }
}

// MARK: - Uygulama düzeyindeki paylaşılan servisler

extension WireGuardService {
    /// Tek örnek: dil değişince pencere yeniden kurulsa da (#8) kurulum/bağlantı durumu korunur.
    static let shared = WireGuardService()
}
