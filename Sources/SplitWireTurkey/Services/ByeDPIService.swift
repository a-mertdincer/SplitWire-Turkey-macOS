import Foundation
import Combine
import AppKit
import Darwin

/// Durum mesajının türü (mantık metin eşleştirmesine değil bu bayrağa dayanır).
enum ByeDPIStatusKind: Equatable {
    case info, success, warning, error
}

enum ByeDPIError: LocalizedError {
    case binaryNotFound
    case emptyCustomArgs
    case portInUseByCiadpi(port: Int, pids: [Int32])
    case portInUseByOther(port: Int, command: String, pid: Int32)
    case exitedEarly(status: Int32, stderr: String, command: String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return L("ciadpi programı bulunamadı. Uygulama paketi eksik olabilir; uygulamayı yeniden indirin.",
                     "The ciadpi program was not found. The app bundle may be incomplete; download the app again.")
        case .emptyCustomArgs:
            return L("Özel (Custom) parametreler boş. Lütfen ciadpi parametrelerini girin (ör. -r 1+s) veya başka bir yöntem seçin.",
                     "Custom arguments are empty. Enter ciadpi arguments (e.g. -r 1+s) or choose another method.")
        case .portInUseByCiadpi(let port, let pids):
            let list = pids.map(String.init).joined(separator: ", ")
            return L("Port \(port) başka bir ByeDPI (ciadpi) süreci tarafından kullanılıyor (PID: \(list)).",
                     "Port \(port) is in use by another ByeDPI (ciadpi) process (PID: \(list)).")
        case .portInUseByOther(let port, let command, let pid):
            return L("Port \(port) başka bir program tarafından kullanılıyor: \(command) (PID \(pid)). Bu programı kapatın ve tekrar deneyin.",
                     "Port \(port) is in use by another program: \(command) (PID \(pid)). Quit that program and try again.")
        case .exitedEarly(let status, let stderr, let command):
            var message = L("ciadpi başlatıldıktan hemen sonra kapandı (çıkış kodu \(status)).",
                            "ciadpi exited right after starting (exit code \(status)).")
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                message += L("\n\nHata çıktısı:\n\(trimmed)", "\n\nError output:\n\(trimmed)")
            }
            message += L("\n\nKomut: \(command)", "\n\nCommand: \(command)")
            return message
        case .launchFailed(let message):
            return L("ciadpi başlatılamadı: \(message)", "Could not start ciadpi: \(message)")
        }
    }
}

/// Uygulamadan çıkış hazırlığının sonucu.
enum QuitPreparation: Equatable {
    /// Sistem proxy kapalı; ciadpi durduruldu.
    case clean
    /// Sistem proxy kapatılamadı (iptal, zaman aşımı, hata); ciadpi henüz DURDURULMADI.
    case proxyStillOn(services: [String], reason: String)
}

/// ByeDPI (ciadpi) yerel SOCKS5 proxy'sini yöneten TEK servis.
/// Pencere ve menü çubuğu aynı örneği (`ByeDPIService.shared`) kullanır.
@MainActor
final class ByeDPIService: ObservableObject {
    static let shared = ByeDPIService()

    static let presetDefaultsKey = "byedpiPreset"
    static let legacyPresetDefaultsKey = "menuBarPreset"
    static let customArgsDefaultsKey = "byedpiCustomArgs"
    static let defaultCustomArgs = "-r 1+s"

    let host = ByeDPIArguments.defaultHost
    /// SOCKS portu (uygulamanın geri kalanı 1080 varsayar; testler farklı port kullanabilir).
    let port: Int
    /// UI sırası ile presetler (Custom en sonda).
    let presets = ByeDPIPresets.all

    /// 1080 portunda bir ciadpi dinliyor mu (bizim veya harici)?
    @Published private(set) var isRunning = false
    /// Başlatma/durdurma sürüyor.
    @Published private(set) var isProcessing = false
    /// Çalışan ciadpi bu oturumda başlatılmadı (ör. önceki oturumdan kalmış).
    @Published private(set) var isExternallyStarted = false
    @Published private(set) var currentPreset: String
    /// Custom preset argümanları (değiştikçe kaydedilir).
    @Published var customArgs: String {
        didSet { defaults.set(customArgs, forKey: Self.customArgsDefaultsKey) }
    }
    /// Çalışan sürecin gerçek argümanları (görüntüleme için).
    @Published private(set) var runningArgs: String?
    /// Çalışan sürecin başlatıldığı preset (harici ise nil).
    @Published private(set) var runningPreset: String?
    /// Çalışan (harici) ciadpi yalnızca 127.0.0.1'de değil, tüm ağ arayüzlerinde dinliyor
    /// (v1.0.0 `-i` olmadan başlatıyordu): aynı ağdaki herkes proxy'yi kullanabilir.
    @Published private(set) var isExposedToNetwork = false
    /// Son durum mesajı; iki dilde saklanır, okunurken geçerli dile çözülür (#8).
    @Published private(set) var status: LocalizedText?
    @Published private(set) var statusKind: ByeDPIStatusKind = .info

    var statusMessage: String { status?.resolved ?? "" }
    var hasError: Bool { statusKind == .error }
    var proxyAddress: String { "\(host):\(port)" }

    let systemProxy: SystemProxyService

    private let defaults: UserDefaults
    private let ciadpiPathOverride: String?
    private var process: Process?
    private var runningTokens: [String]?
    private var stderrBuffer = LineRingBuffer(capacity: 50)
    private var isStarting = false
    private var requestedStopPIDs = Set<Int32>()
    private var pollTimer: Timer?
    private var isPolling = false
    private var pollCount = 0
    private var isShowingUnexpectedStopAlert = false
    private var isShuttingDown = false
    /// LAN'a açık dinleyicisi için zaten uyarı gösterilen PID'ler (bir kez sorulur).
    private var handledExposedPIDs = Set<Int32>()

    init(
        defaults: UserDefaults = .standard,
        systemProxy: SystemProxyService? = nil,
        port: Int = ByeDPIArguments.defaultPort,
        ciadpiPath: String? = nil
    ) {
        self.defaults = defaults
        self.port = port
        self.ciadpiPathOverride = ciadpiPath
        // Varsayılan olmayan portta (testler) gerçek 127.0.0.1:1080 proxy'sine asla dokunulmaz
        self.systemProxy = systemProxy
            ?? (port == ByeDPIArguments.defaultPort ? SystemProxyService.shared : SystemProxyService(port: port))
        self.currentPreset = ByeDPIPresets.migrate(
            stored: defaults.string(forKey: Self.presetDefaultsKey),
            legacy: defaults.string(forKey: Self.legacyPresetDefaultsKey)
        )
        self.customArgs = defaults.string(forKey: Self.customArgsDefaultsKey) ?? Self.defaultCustomArgs
        defaults.set(currentPreset, forKey: Self.presetDefaultsKey)
    }

    // MARK: - İzleme

    /// Periyodik durum kontrolünü başlatır (uygulama açılışında bir kez çağrılır).
    func startMonitoring() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        Task { await refreshStatus() }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollTick() async {
        pollCount += 1
        await refreshStatus()
        // networksetup taraması daha pahalı; ~10 sn'de bir
        if pollCount % 4 == 0, !isShuttingDown {
            await systemProxy.refresh()
        }
    }

    /// isRunning'i gerçek durumla uzlaştırır: bizim süreç VEYA 1080'de dinleyen herhangi bir ciadpi.
    func refreshStatus() async {
        guard !isPolling, !isProcessing, !isShuttingDown else { return }
        isPolling = true
        defer { isPolling = false }

        if let process, process.isRunning {
            if !isRunning { isRunning = true }
            if isExternallyStarted { isExternallyStarted = false }
            if isExposedToNetwork { isExposedToNetwork = false }
            return
        }

        let ciadpiListeners = await Self.listeners(port: port).filter(\.isCiadpi)
        // Bekleme sırasında başlatma/durdurma başladıysa sonucu yok say
        guard !isProcessing, !isShuttingDown, process == nil else { return }

        let wasRunning = isRunning
        let wasExternal = isExternallyStarted
        let nowRunning = !ciadpiListeners.isEmpty

        if nowRunning {
            if !isRunning { isRunning = true }
            if !isExternallyStarted { isExternallyStarted = true }
            if runningArgs == nil, let pid = ciadpiListeners.first?.pid {
                if runningPreset != nil { runningPreset = nil }
                runningTokens = nil
                runningArgs = await Self.commandLine(of: pid) ?? "ciadpi (PID \(pid))"
            }
            checkNetworkExposure(ciadpiListeners)
        } else {
            if isRunning { isRunning = false }
            if isExternallyStarted { isExternallyStarted = false }
            if isExposedToNetwork { isExposedToNetwork = false }
            // Değişmeyen değerleri yeniden atama: @Published her atamada yayınlar ve
            // menü çubuğu her 2,5 sn'de yeniden kurulurdu (açık alt menü kapanırdı).
            if runningArgs != nil { runningArgs = nil }
            if runningPreset != nil { runningPreset = nil }
            runningTokens = nil
            if wasRunning && wasExternal {
                setStatus(.warning, LT("Harici ByeDPI (ciadpi) süreci durdu.",
                                       "The external ByeDPI (ciadpi) process stopped."))
                await handleUnexpectedStop(details: nil)
            }
        }
    }

    /// Harici ciadpi tüm arayüzlerde dinliyorsa (v1.0.0'dan kalma, LAN'a açık SOCKS proxy)
    /// kalıcı uyarı bayrağını ayarlar ve her PID için bir kez güvenli yeniden başlatma önerir.
    private func checkNetworkExposure(_ ciadpiListeners: [PortListener]) {
        // Adresi bilinmeyen (lsof "n" satırı yok) dinleyici açık sayılmaz: yanlış alarm olmasın
        let exposed = ciadpiListeners.filter { !$0.addresses.isEmpty && !$0.isLoopbackOnly }
        let nowExposed = !exposed.isEmpty
        if isExposedToNetwork != nowExposed { isExposedToNetwork = nowExposed }

        let newlyExposed = exposed.filter { !handledExposedPIDs.contains($0.pid) }
        guard !newlyExposed.isEmpty else { return }
        handledExposedPIDs.formUnion(newlyExposed.map(\.pid))
        let uid = getuid()
        let ownedByUs = newlyExposed.allSatisfy { $0.uid == nil || $0.uid == uid }
        // Ayrı görev: refreshStatus (isPolling) uyarı penceresi boyunca bloklanmasın
        Task { await self.offerSafeRestart(ownedByUs: ownedByUs) }
    }

    static var exposedWarning: LocalizedText {
        LT("ByeDPI tüm ağ arayüzlerinde dinliyor — ağınızdaki herkes bu proxy'yi kullanabilir.",
           "ByeDPI is listening on all network interfaces — anyone on your network can use this proxy.")
    }

    private func offerSafeRestart(ownedByUs: Bool) async {
        guard !isShuttingDown, isExposedToNetwork else { return }
        let warning = Self.exposedWarning
        guard ownedByUs else {
            setStatus(.warning, LT("\(warning.tr) Süreç başka bir kullanıcıya ait; kapatmak için 'Tümünü Zorla Kapat'ı kullanın.",
                                   "\(warning.en) The process belongs to another user; use 'Force stop all' to stop it."))
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("ByeDPI ağınıza açık", "ByeDPI is exposed to your network")
        alert.informativeText = L("Eski bir ByeDPI (v1.0.0'dan kalma) tüm ağ arayüzlerinde dinliyor; aynı Wi-Fi'daki herkes onu proxy olarak kullanabilir.\n\nYalnızca 127.0.0.1 üzerinde güvenli şekilde yeniden başlatılsın mı?",
                                  "An old ByeDPI (from v1.0.0) is listening on all network interfaces, so anyone on your Wi-Fi can use it as a proxy.\n\nRestart it safely on 127.0.0.1 only?")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("Güvenli Yeniden Başlat", "Restart safely"))
        alert.addButton(withTitle: L("Şimdi Değil", "Not now"))
        if alert.runModal() == .alertFirstButtonReturn {
            await restart()
        } else {
            setStatus(.warning, warning)
        }
    }

    // MARK: - Preset

    func args(for presetID: String) -> String {
        ByeDPIPresets.args(for: presetID, customArgs: customArgs)
    }

    /// Preset değiştirir ve kaydeder. ByeDPI çalışıyorsa yeni preset ile yeniden başlatır.
    func selectPreset(_ id: String) {
        guard ByeDPIPresets.preset(id: id) != nil else { return }
        let changed = id != currentPreset
        if changed {
            currentPreset = id
            defaults.set(id, forKey: Self.presetDefaultsKey)
        }
        restartIfArgumentsChanged()
    }

    /// Custom argümanları uygular (çalışıyorsa yeniden başlatır).
    func applyCustomArgs() {
        if currentPreset != ByeDPIPresets.customID {
            selectPreset(ByeDPIPresets.customID)
        } else {
            restartIfArgumentsChanged()
        }
    }

    /// Custom moduna geçer. Kullanıcının kendi kaydettiği özel parametreler ASLA ezilmez;
    /// yalnızca boşsa veya bir hazır presetle aynıysa mevcut yöntemin parametreleriyle doldurulur.
    func editAsCustom() {
        if currentPreset != ByeDPIPresets.customID {
            let existing = ByeDPIArguments.tokenize(customArgs)
            let isUntouched = existing.isEmpty
                || ByeDPIPresets.builtIn.contains { ByeDPIArguments.tokenize($0.args) == existing }
            if isUntouched {
                customArgs = args(for: currentPreset)
            }
        }
        selectPreset(ByeDPIPresets.customID)
    }

    private func restartIfArgumentsChanged() {
        guard isRunning, !isProcessing else { return }
        if currentPreset == ByeDPIPresets.customID,
           ByeDPIArguments.tokenize(customArgs).isEmpty {
            // Çalışan süreci öldürmeden önce: boş Custom ile yeniden başlatma başarısız olur
            // ve sistem proxy ölü bir 127.0.0.1:1080'i gösterirdi (#14).
            setStatus(.warning, LT("Özel parametreler boş; ByeDPI önceki yöntemle çalışmaya devam ediyor. Parametreleri girip 'Uygula'ya basın.",
                                   "Custom arguments are empty; ByeDPI keeps running with the previous method. Enter arguments and press Apply."))
            return
        }
        let newTokens = ByeDPIArguments.build(from: args(for: currentPreset), host: host, port: port)
        if !isExternallyStarted, let runningTokens, runningTokens == newTokens {
            // Aynı argümanlar: yeniden başlatmaya gerek yok
            runningPreset = currentPreset
            return
        }
        Task { await restart() }
    }

    // MARK: - Başlat / Durdur

    /// ByeDPI'ı seçili preset ile başlatır. Hatalarda uyarı penceresi gösterir.
    @discardableResult
    func start() async -> Bool {
        // LAN'a açık eski bir ciadpi "çalışıyor" sayılmaz: güvenli şekilde yeniden başlatılmalı
        if isRunning && !isExposedToNetwork { return true }
        guard !isProcessing else { return false }
        isProcessing = true
        defer { isProcessing = false }
        return await performStart(allowCleanupRetry: true)
    }

    /// Kullanıcı ByeDPI'ı durdurur; bizim sistem proxy'miz açıksa o da kapatılır.
    func stop() async {
        guard !isProcessing else { return }
        isProcessing = true
        setStatus(.info, LT("ByeDPI durduruluyor...", "Stopping ByeDPI..."))
        let remaining = await stopAllOwnedProcesses()
        markStopped()
        isProcessing = false

        if remaining.isEmpty {
            setStatus(.success, LT("ByeDPI durduruldu.", "ByeDPI stopped."))
        } else {
            isRunning = true
            isExternallyStarted = true
            setStatus(.warning, LT("\(port) portunu kullanan bir ciadpi süreci kapatılamadı (başka bir kullanıcıya ait olabilir). 'Tümünü Zorla Kapat' seçeneğini deneyin.",
                                  "A ciadpi process using port \(port) could not be stopped (it may belong to another user). Try 'Force stop all'."))
        }
        await disableSystemProxyAfterStop()
    }

    /// Yeni preset için yeniden başlatma. Yeni yöntem başlatılamazsa önce eski yöntemle
    /// yeniden açmayı dener; o da olmazsa sistem proxy'yi kapatır (ölü proxy = internet yok, #14).
    func restart() async {
        guard !isProcessing else { return }
        isProcessing = true
        setStatus(.info, LT("ByeDPI yeni yöntemle yeniden başlatılıyor...", "Restarting ByeDPI with the new method..."))
        let previousTokens = isExternallyStarted ? nil : runningTokens
        let previousPreset = runningPreset
        _ = await stopAllOwnedProcesses()
        markStopped()
        var started = await performStart(allowCleanupRetry: true)
        if !started, let previousTokens, !isShuttingDown {
            let failure = status
            do {
                try await launchAndRecord(tokens: previousTokens, presetID: previousPreset)
                started = true
                let name = previousPreset.flatMap(ByeDPIPresets.preset(id:))?.localizedName
                    ?? .verbatim(ByeDPIArguments.displayString(previousTokens))
                setStatus(.warning, LT("Yeni yöntem başlatılamadı; ByeDPI önceki yöntemle (\(name.tr)) çalışmaya devam ediyor.",
                                       "The new method could not be started; ByeDPI keeps running with the previous method (\(name.en))."))
            } catch {
                status = failure
            }
        }
        isProcessing = false
        if !started {
            await disableSystemProxyAfterStop(
                prefix: LT("ByeDPI yeni yöntemle başlatılamadı ve şu an çalışmıyor.",
                           "ByeDPI could not start with the new method and is not running.")
            )
        }
    }

    /// Tüm ciadpi süreçlerini zorla kapatır (gerekirse tek yönetici penceresi ile),
    /// bizim sistem proxy'miz açıksa aynı pencerede kapatır.
    func killAllProcesses() async {
        guard !isProcessing else { return }
        isProcessing = true
        setStatus(.info, LT("Tüm ByeDPI süreçleri zorla kapatılıyor...", "Force stopping all ByeDPI processes..."))

        await terminateOwnProcess()
        _ = try? await Shell.run("/usr/bin/pkill", ["-9", "-x", "ciadpi"], timeout: 10)
        try? await Task.sleep(nanoseconds: 300_000_000)

        let remaining = await Self.listeners(port: port).filter(\.isCiadpi)
        let proxyServices = await systemProxy.refresh()

        var privilegedParts: [String] = []
        if !remaining.isEmpty {
            privilegedParts.append("/usr/bin/pkill -9 -x ciadpi || true")
        }
        if !proxyServices.isEmpty {
            privilegedParts.append(SystemProxyService.disableCommand(services: proxyServices))
        }

        var proxyWarning: LocalizedText?
        if !privilegedParts.isEmpty {
            do {
                try await Shell.runPrivileged(
                    privilegedParts.joined(separator: " ; "),
                    prompt: L("SplitWire-Turkey tüm ByeDPI (ciadpi) süreçlerini kapatmak ve gerekirse sistem proxy'sini kapatmak istiyor.",
                              "SplitWire-Turkey wants to stop all ByeDPI (ciadpi) processes and turn off the system proxy if needed.")
                )
            } catch ShellError.userCancelled {
                if !proxyServices.isEmpty {
                    proxyWarning = Self.proxyStillActiveWarning
                }
            } catch {
                let reason = error.localizedDescription
                proxyWarning = LT("Yönetici komutu başarısız oldu: \(reason)",
                                  "The administrator command failed: \(reason)")
            }
            await systemProxy.refresh()
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        let stillListening = await Self.listeners(port: port)
        markStopped()
        isProcessing = false

        if let proxyWarning {
            setStatus(.warning, LT("ByeDPI süreçleri kapatıldı. \(proxyWarning.tr)",
                                   "ByeDPI processes stopped. \(proxyWarning.en)"))
        } else if stillListening.contains(where: \.isCiadpi) {
            isRunning = true
            isExternallyStarted = true
            setStatus(.warning, LT("Uyarı: Port \(port) hâlâ bir ciadpi süreci tarafından kullanılıyor.",
                                  "Warning: port \(port) is still in use by a ciadpi process."))
        } else if !proxyServices.isEmpty && !systemProxy.isOurProxyActive {
            setStatus(.success, LT("Tüm ByeDPI süreçleri kapatıldı ve sistem proxy kapatıldı.",
                                   "All ByeDPI processes stopped and the system proxy was turned off."))
        } else {
            setStatus(.success, LT("Tüm ByeDPI süreçleri kapatıldı.", "All ByeDPI processes stopped."))
        }
    }

    // MARK: - Çıkış

    /// Uygulama kapanırken: bizim sistem proxy'yi kapatır, sonra kendi ciadpi sürecimizi öldürür.
    /// Proxy kapatılamazsa ciadpi'ye DOKUNMAZ ve `.proxyStillOn` döner (çağıran kullanıcıya sorar):
    /// aksi hâlde proxy ölü bir 127.0.0.1:1080'i gösterir ve internet çalışmaz (#14).
    func prepareForQuit() async -> QuitPreparation {
        isShuttingDown = true
        stopMonitoring()
        // Açık bir "proxy'yi aç" parola penceresi varsa sonucunu bekle (en çok ~60 sn)
        let deadline = Date().addingTimeInterval(60)
        while systemProxy.isBusy && Date() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        let services = await systemProxy.refresh()
        guard !services.isEmpty else {
            await terminateOwnProcess()
            return .clean
        }
        setStatus(.info, LT("Çıkmadan önce sistem proxy kapatılıyor...", "Turning off the system proxy before quitting..."))
        return await retryDisableProxyForQuit()
    }

    /// Çıkışta proxy'yi (yeniden) kapatmayı dener; başarılıysa ciadpi'yi durdurur.
    func retryDisableProxyForQuit() async -> QuitPreparation {
        var reason = ""
        do {
            try await systemProxy.disableAll(prompt: Self.quitPrompt, timeout: 120)
        } catch {
            reason = error.localizedDescription
        }
        let still = await systemProxy.refresh()
        guard !still.isEmpty else {
            await terminateOwnProcess()
            return .clean
        }
        if reason.isEmpty {
            reason = L("ayar hâlâ açık", "the setting is still on")
        }
        return .proxyStillOn(services: still, reason: reason)
    }

    /// Kullanıcı "Çıkma"yı seçti: izlemeyi yeniden başlat.
    func resumeAfterCancelledQuit() {
        isShuttingDown = false
        startMonitoring()
        Task { await refreshStatus() }
    }

    static var quitPrompt: String {
        L("SplitWire-Turkey kapanıyor ve internet bağlantınızın çalışmaya devam etmesi için sistem proxy'sini kapatması gerekiyor.",
          "SplitWire-Turkey is quitting and needs to turn off the system proxy so your internet keeps working.")
    }

    // MARK: - Sistem proxy

    static var proxyStillActiveWarning: LocalizedText {
        LT("Sistem proxy hâlâ AÇIK ve durdurulmuş ByeDPI'ı (127.0.0.1:1080) gösteriyor; bu durumda internet ÇALIŞMAZ. 'Sistem Proxy' bölümünden kapatın veya ByeDPI'ı yeniden başlatın.",
           "The system proxy is still ON and points to the stopped ByeDPI (127.0.0.1:1080), so the internet will NOT work. Turn it off in the 'System proxy' section or restart ByeDPI.")
    }

    /// Sistem SOCKS proxy'yi açar (ByeDPI çalışıyor olmalı).
    func enableSystemProxy() async {
        guard isRunning else {
            setStatus(.error, LT("Sistem proxy'yi açmadan önce ByeDPI'ı başlatın.",
                                 "Start ByeDPI before turning on the system proxy."))
            return
        }
        do {
            let service = try await systemProxy.enable()
            // Parola penceresi açıkken ByeDPI durdu/çöktü ya da çıkış başladı: proxy'yi açık bırakma
            guard isRunning, !isShuttingDown else {
                if !isShuttingDown {
                    setStatus(.warning, Self.proxyStillActiveWarning)
                    await disableSystemProxyAfterStop()
                }
                return
            }
            setStatus(.success, LT("Sistem proxy açıldı (\(service) → \(proxyAddress)). Yalnızca ByeDPI çalışırken güvenlidir; ByeDPI durdurulduğunda veya uygulamadan çıkıldığında otomatik kapatılır.",
                                   "System proxy turned on (\(service) → \(proxyAddress)). It is only safe while ByeDPI is running; it turns off automatically when ByeDPI stops or you quit the app."))
        } catch SystemProxyError.noListener {
            setStatus(.warning, LT("ByeDPI, sistem proxy açılmadan önce durdu; proxy açılmadı.",
                                   "ByeDPI stopped before the system proxy could be turned on; it was not turned on."))
        } catch ShellError.userCancelled {
            setStatus(.info, LT("Sistem proxy açılmadı (yönetici izni verilmedi).",
                                "The system proxy was not turned on (administrator permission was not given)."))
        } catch {
            let reason = error.localizedDescription
            setStatus(.error, LT("Sistem proxy açılamadı: \(reason)", "Could not turn on the system proxy: \(reason)"))
            presentAlert(title: L("Hata", "Error"),
                         message: L("Sistem proxy açılamadı:\n\(reason)", "Could not turn on the system proxy:\n\(reason)"),
                         style: .warning)
        }
    }

    /// Bizim proxy'nin açık olduğu tüm servislerde kapatır.
    func disableSystemProxy() async {
        do {
            let services = try await systemProxy.disableAll()
            if services.isEmpty {
                setStatus(.info, LT("Sistem proxy zaten kapalı.", "The system proxy is already off."))
            } else {
                let list = services.joined(separator: ", ")
                setStatus(.success, LT("Sistem proxy kapatıldı (\(list)).", "System proxy turned off (\(list))."))
            }
        } catch ShellError.userCancelled {
            if systemProxy.isOurProxyActive && !isRunning {
                setStatus(.warning, Self.proxyStillActiveWarning)
            } else {
                setStatus(.info, LT("Sistem proxy kapatılmadı (yönetici izni verilmedi).",
                                    "The system proxy was not turned off (administrator permission was not given)."))
            }
        } catch {
            let reason = error.localizedDescription
            setStatus(.error, LT("Sistem proxy kapatılamadı: \(reason)", "Could not turn off the system proxy: \(reason)"))
        }
    }

    /// ByeDPI artık çalışmıyorsa ve bizim proxy açıksa kapatır (#14).
    /// - Parameter prefix: Mesajın başı (neden durduğu).
    private func disableSystemProxyAfterStop(
        prefix: LocalizedText = LT("ByeDPI durduruldu.", "ByeDPI stopped.")
    ) async {
        let services = await systemProxy.refresh()
        guard !services.isEmpty, !isRunning else { return }
        do {
            try await systemProxy.disableAll()
            setStatus(.success, LT("\(prefix.tr) Sistem proxy de kapatıldı (ByeDPI kapalıyken internet bağlantısının kesilmemesi için).",
                                   "\(prefix.en) The system proxy was turned off too, so your internet keeps working while ByeDPI is off."))
        } catch ShellError.userCancelled {
            let warning = Self.proxyStillActiveWarning
            setStatus(.warning, LT("\(prefix.tr) Yönetici izni verilmediği için sistem proxy kapatılamadı. \(warning.tr)",
                                   "\(prefix.en) The system proxy could not be turned off because administrator permission was not given. \(warning.en)"))
        } catch {
            let reason = error.localizedDescription
            let warning = Self.proxyStillActiveWarning
            setStatus(.error, LT("\(prefix.tr) Sistem proxy kapatılamadı: \(reason). \(warning.tr)",
                                 "\(prefix.en) The system proxy could not be turned off: \(reason). \(warning.en)"))
        }
    }

    /// ciadpi beklenmedik şekilde durduysa ve bizim proxy açıksa kullanıcıya sor.
    private func handleUnexpectedStop(details: String?) async {
        guard !isShowingUnexpectedStopAlert, !isShuttingDown else { return }
        let services = await systemProxy.refresh()
        guard !services.isEmpty, !isRunning, !isShuttingDown else { return }

        isShowingUnexpectedStopAlert = true
        defer { isShowingUnexpectedStopAlert = false }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("ByeDPI beklenmedik şekilde durdu", "ByeDPI stopped unexpectedly")
        let list = services.joined(separator: ", ")
        var info = L("ByeDPI beklenmedik şekilde durdu, ancak sistem proxy hâlâ açık (\(list) → \(proxyAddress)). ByeDPI çalışmazken internet bağlantınız çalışmaz.\n\nByeDPI'ı yeniden başlatın veya sistem proxy'yi kapatın.",
                     "ByeDPI stopped unexpectedly, but the system proxy is still on (\(list) → \(proxyAddress)). Your internet connection won't work while ByeDPI isn't running.\n\nRestart ByeDPI or turn off the system proxy.")
        if let details, !details.isEmpty {
            info += L("\n\nciadpi çıktısı:\n\(details)", "\n\nciadpi output:\n\(details)")
        }
        alert.informativeText = info
        alert.alertStyle = .critical
        alert.addButton(withTitle: L("Yeniden Başlat", "Restart"))
        alert.addButton(withTitle: L("Sistem Proxy'yi Kapat", "Turn off system proxy"))
        alert.addButton(withTitle: L("Yoksay", "Ignore"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            await start()
        case .alertSecondButtonReturn:
            await disableSystemProxy()
        default:
            setStatus(.warning, Self.proxyStillActiveWarning)
        }
    }

    // MARK: - Favori uygulamalar

    /// ByeDPI'ı (gerekirse) başlatır ve uygulamayı proxy argümanlarıyla açar.
    func launchFavoriteApp(_ app: AppState.FavoriteApp) async {
        if !isRunning {
            guard await start() else { return }
            // Proxy'nin dinlemeye başlaması için kısa pay
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        let arguments = ByeDPIArguments.tokenize(app.customArgs)
        do {
            let launched = try await AppLauncher.launch(
                appPath: app.path,
                name: app.name,
                bundleIdentifier: app.bundleIdentifier,
                arguments: arguments
            )
            if launched {
                setStatus(.success, LT("\(app.name) ByeDPI proxy ile başlatıldı.",
                                       "\(app.name) was launched with the ByeDPI proxy."))
            } else {
                setStatus(.info, LT("\(app.name) başlatma iptal edildi.",
                                    "Launching \(app.name) was cancelled."))
            }
        } catch {
            let reason = error.localizedDescription
            // AppLaunchError metinleri zaten uygulama adını/yolunu içerir (çift "başlatılamadı" olmasın)
            let message = error is AppLaunchError
                ? LocalizedText.verbatim(reason)
                : LT("\(app.name) başlatılamadı: \(reason)", "Could not launch \(app.name): \(reason)")
            setStatus(.error, message)
            presentAlert(title: L("Hata", "Error"), message: reason, style: .warning)
        }
    }

    // MARK: - Süreç yönetimi

    private func performStart(allowCleanupRetry: Bool) async -> Bool {
        let presetID = currentPreset
        let argsText = args(for: presetID)
        setStatus(.info, LT("ByeDPI başlatılıyor...", "Starting ByeDPI..."))

        do {
            if presetID == ByeDPIPresets.customID,
               ByeDPIArguments.tokenize(argsText).isEmpty {
                throw ByeDPIError.emptyCustomArgs
            }
            let tokens = ByeDPIArguments.build(from: argsText, host: host, port: port)
            try await launchAndRecord(tokens: tokens, presetID: presetID)
            let presetName = ByeDPIPresets.preset(id: presetID)?.localizedName ?? .verbatim(presetID)
            setStatus(.success, LT("ByeDPI başlatıldı (SOCKS5: \(proxyAddress), yöntem: \(presetName.tr)).",
                                   "ByeDPI started (SOCKS5: \(proxyAddress), method: \(presetName.en))."))
            return true
        } catch ByeDPIError.portInUseByCiadpi(_, let pids) where allowCleanupRetry {
            setStatus(.warning, LT("Port \(port) başka bir ByeDPI süreci tarafından kullanılıyor.",
                                  "Port \(port) is in use by another ByeDPI process."))
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = L("Port \(port) Kullanımda", "Port \(port) is in use")
            alert.informativeText = L("Port \(port) zaten başka bir ByeDPI (ciadpi) süreci tarafından kullanılıyor (önceki bir oturumdan kalmış olabilir).\n\nBu süreçleri kapatıp tekrar denemek ister misiniz?",
                                      "Port \(port) is already in use by another ByeDPI (ciadpi) process (it may be left over from a previous session).\n\nStop these processes and try again?")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("Süreçleri Kapat ve Tekrar Dene", "Stop processes and retry"))
            alert.addButton(withTitle: L("İptal", "Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else {
                setStatus(.info, LT("Başlatma iptal edildi.", "Start cancelled."))
                return false
            }
            setStatus(.info, LT("Eski ByeDPI süreçleri kapatılıyor...", "Stopping old ByeDPI processes..."))
            let remaining = await killCiadpiListeners(pids: pids)
            guard remaining.isEmpty else {
                let message = LT("Port \(port) hâlâ kullanımda. 'Tümünü Zorla Kapat' seçeneğini deneyin.",
                                 "Port \(port) is still in use. Try 'Force stop all'.")
                setStatus(.error, message)
                presentAlert(title: L("Hata", "Error"), message: message.resolved, style: .warning)
                return false
            }
            return await performStart(allowCleanupRetry: false)
        } catch {
            let reason = error.localizedDescription
            setStatus(.error, LT("ByeDPI başlatılamadı: \(reason)", "Could not start ByeDPI: \(reason)"))
            presentAlert(title: L("ByeDPI başlatılamadı", "Could not start ByeDPI"), message: reason, style: .warning)
            return false
        }
    }

    /// ciadpi'yi verilen argümanlarla başlatır ve çalışan durumu kaydeder.
    private func launchAndRecord(tokens: [String], presetID: String?) async throws {
        try await launchProcess(tokens: tokens)
        isRunning = true
        isExternallyStarted = false
        if isExposedToNetwork { isExposedToNetwork = false }
        runningTokens = tokens
        runningArgs = ByeDPIArguments.displayString(tokens)
        runningPreset = presetID
    }

    /// ciadpi sürecini verilen (son hâli oluşturulmuş) argümanlarla başlatır.
    private func launchProcess(tokens: [String]) async throws {
        guard let ciadpiPath = ciadpiPathOverride ?? Self.findCiadpiPath() else {
            throw ByeDPIError.binaryNotFound
        }

        // Port kontrolü: yalnızca LISTEN soketleri sayılır
        let listeners = await Self.listeners(port: port)
        if !listeners.isEmpty {
            let uid = getuid()
            let ownCiadpi = listeners.filter { $0.isCiadpi && ($0.uid == nil || $0.uid == uid) }
            if ownCiadpi.count == listeners.count {
                throw ByeDPIError.portInUseByCiadpi(port: port, pids: ownCiadpi.map(\.pid))
            }
            let other = listeners.first { !($0.isCiadpi && ($0.uid == nil || $0.uid == uid)) } ?? listeners[0]
            throw ByeDPIError.portInUseByOther(port: port, command: other.command.isEmpty ? "?" : other.command, pid: other.pid)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ciadpiPath)
        process.arguments = tokens
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice

        let buffer = LineRingBuffer(capacity: 50)
        stderrBuffer = buffer
        let errorPipe = Pipe()
        process.standardError = errorPipe
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                buffer.append(data)
            }
        }
        process.terminationHandler = { [weak self] proc in
            let pid = proc.processIdentifier
            let status = proc.terminationStatus
            Task { @MainActor in
                self?.handleTermination(pid: pid, status: status)
            }
        }

        let commandLine = ([ciadpiPath] + tokens).joined(separator: " ")
        isStarting = true
        defer { isStarting = false }

        do {
            try process.run()
        } catch {
            errorPipe.fileHandleForReading.readabilityHandler = nil
            throw ByeDPIError.launchFailed(error.localizedDescription)
        }
        self.process = process

        // Hemen kapanan (ör. geçersiz parametre, bind hatası) süreçleri yakala
        try? await Task.sleep(nanoseconds: 600_000_000)
        if !process.isRunning {
            self.process = nil
            // stderr'in son parçası gelsin
            try? await Task.sleep(nanoseconds: 100_000_000)
            throw ByeDPIError.exitedEarly(status: process.terminationStatus, stderr: buffer.text, command: commandLine)
        }
    }

    private func handleTermination(pid: Int32, status: Int32) {
        if requestedStopPIDs.remove(pid) != nil { return }
        guard let process, process.processIdentifier == pid else { return }
        // Başlatma sırasında erken çıkış performStart tarafından raporlanır
        guard !isStarting, !isShuttingDown else { return }

        self.process = nil
        isRunning = false
        isExternallyStarted = false
        runningArgs = nil
        runningPreset = nil
        runningTokens = nil

        let tail = stderrBuffer.text
        let suffix = tail.isEmpty ? "" : "\n\(tail)"
        setStatus(.error, LT("ByeDPI beklenmedik şekilde durdu (çıkış kodu \(status)).\(suffix)",
                             "ByeDPI stopped unexpectedly (exit code \(status)).\(suffix)"))
        Task { await handleUnexpectedStop(details: tail) }
    }

    /// Kendi sürecimizi öldürür (ciadpi SIGTERM'i yok saydığından SIGKILL).
    private func terminateOwnProcess() async {
        guard let process else { return }
        self.process = nil
        let pid = process.processIdentifier
        guard process.isRunning else { return }
        requestedStopPIDs.insert(pid)
        process.terminate()
        if !(await Self.waitForExit(process, timeout: 0.3)) {
            kill(pid, SIGKILL)
            _ = await Self.waitForExit(process, timeout: 2)
        }
    }

    /// Kendi sürecimiz + 1080'de dinleyen (aynı kullanıcıya ait) ciadpi'leri öldürür.
    /// - Returns: Hâlâ 1080'de dinleyen ciadpi'ler.
    private func stopAllOwnedProcesses() async -> [PortListener] {
        await terminateOwnProcess()
        let uid = getuid()
        let orphans = await Self.listeners(port: port).filter {
            $0.isCiadpi && ($0.uid == nil || $0.uid == uid)
        }
        if orphans.isEmpty {
            return await Self.listeners(port: port).filter(\.isCiadpi)
        }
        return await killCiadpiListeners(pids: orphans.map(\.pid))
    }

    /// Verilen ciadpi PID'lerini SIGKILL ile öldürür ve portun boşalmasını bekler.
    private func killCiadpiListeners(pids: [Int32]) async -> [PortListener] {
        for pid in pids where pid > 0 {
            kill(pid, SIGKILL)
        }
        var remaining: [PortListener] = []
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 150_000_000)
            remaining = await Self.listeners(port: port).filter(\.isCiadpi)
            if remaining.isEmpty { break }
        }
        return remaining
    }

    private func markStopped() {
        isRunning = false
        isExternallyStarted = false
        isExposedToNetwork = false
        runningArgs = nil
        runningPreset = nil
        runningTokens = nil
    }

    // MARK: - Yardımcılar

    private func setStatus(_ kind: ByeDPIStatusKind, _ message: LocalizedText) {
        statusKind = kind
        status = message
    }

    private func presentAlert(title: String, message: String, style: NSAlert.Style) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: L("Tamam", "OK"))
        alert.runModal()
    }

    private static func waitForExit(_ process: Process, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return !process.isRunning
    }

    /// `port` üzerinde LISTEN durumundaki süreçler.
    nonisolated static func listeners(port: Int) async -> [PortListener] {
        guard let result = try? await Shell.run(
            "/usr/sbin/lsof",
            ["-nP", "+c", "0", "-iTCP:\(port)", "-sTCP:LISTEN", "-F", "pcun"],
            timeout: 10
        ) else { return [] }
        return LsofParser.parseListeners(result.stdout)
    }

    nonisolated static func commandLine(of pid: Int32) async -> String? {
        guard let result = try? await Shell.run("/bin/ps", ["-o", "args=", "-p", String(pid)], timeout: 5),
              result.succeeded else { return nil }
        let line = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return line.isEmpty ? nil : line
    }

    /// ciadpi ikili dosyasını bulur: uygulama paketi (Contents/Resources/bin/ciadpi) →
    /// geliştirme yolu (<repo>/byedpi/ciadpi, scripts/build-ciadpi.sh ile derlenir).
    /// Not: SwiftPM `*.bundle` klasörleri taranmaz; eski bir .build içinde v1.0.0'dan kalma
    /// (minos 15.0, yalnızca arm64) bir ciadpi bulunabilir.
    nonisolated static func findCiadpiPath() -> String? {
        let fm = FileManager.default
        var candidates: [String] = []

        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("bin/ciadpi").path)
            candidates.append(resources.appendingPathComponent("ciadpi").path)
        }

        if let execURL = Bundle.main.executableURL {
            // Geliştirme: <repo>/.build/<config>/ veya <repo>/.build/out/Products/<config>/ → <repo>
            var dir = execURL.deletingLastPathComponent()
            for _ in 0..<5 {
                dir = dir.deletingLastPathComponent()
                candidates.append(dir.appendingPathComponent("byedpi/ciadpi").path)
            }
        }

        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }
}
