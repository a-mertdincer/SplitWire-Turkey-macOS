import Foundation
import Combine

enum SystemProxyError: LocalizedError, Equatable {
    /// Yetkili komut çalışırken ciadpi artık dinlemiyordu; proxy açılmadı.
    case noListener
    /// Proxy'nin açılacağı etkin bir ağ servisi bulunamadı.
    case noActiveService
    /// Serviste kullanıcının kendi (başka bir sunucuyu gösteren) SOCKS/HTTPS proxy'si açık;
    /// üzerine yazılmaz.
    case foreignProxy(service: String, kind: String, server: String)

    /// Yetkili komutun stderr'e yazdığı işaret (yerelleştirilmez).
    static let noListenerMarker = "SPLITWIRE_NO_LISTENER"

    var errorDescription: String? {
        switch self {
        case .noListener:
            return L("ByeDPI artık çalışmıyor; sistem proxy açılmadı.",
                     "ByeDPI is no longer running; the system proxy was not turned on.")
        case .noActiveService:
            return L("Etkin ağ servisi bulunamadı", "No active network service found")
        case .foreignProxy(let service, let kind, let server):
            return L("\(service) servisinde başka bir \(kind) proxy (\(server)) açık. SplitWire onu değiştirmez; sistem proxy'yi açmak için önce o proxy'yi Sistem Ayarları > Ağ > \(service) > Ayrıntılar > Proxy'ler bölümünden kapatın.",
                     "Another \(kind) proxy (\(server)) is on for \(service). SplitWire won't overwrite it. To turn on the system proxy, first turn that proxy off in System Settings > Network > \(service) > Details > Proxies.")
        }
    }
}

/// Bir ağ servisinde hangi sistem proxy'lerinin bizim ByeDPI'ımızı (açık + 127.0.0.1:1080) gösterdiği.
struct OurProxyState: Equatable, Sendable {
    let service: String
    /// SOCKS proxy (v1.1.0 yalnızca bunu açıyordu).
    let socks: Bool
    /// Güvenli web proxy'si (HTTPS / Secure Web Proxy); v1.1.1'den itibaren SOCKS ile birlikte açılır (#13).
    let secureWeb: Bool
    /// Aynı serviste kullanıcının kendi (başka sunucuyu gösteren) SOCKS veya HTTPS proxy'si de açık mı?
    /// Öyleyse "Aç" onu ezmez; eksik ayar tamamlanmaz (yalnızca bizimki kapatılabilir).
    var hasForeignProxy: Bool = false

    /// İkisi de açık mı? (Yalnızca biri açıksa v1.1.0'dan kalma ya da yarım kalmış bir ayardır.)
    var isComplete: Bool { socks && secureWeb }

    /// Açık proxy türleri (teknik ad, çevrilmez): "SOCKS + HTTPS", "SOCKS" veya "HTTPS".
    var kindsLabel: String {
        [socks ? "SOCKS" : nil, secureWeb ? "HTTPS" : nil].compactMap { $0 }.joined(separator: " + ")
    }

    /// "Wi-Fi: SOCKS + HTTPS"
    var summary: String { "\(service): \(kindsLabel)" }

    /// Servisin iki proxy ayarına bakarak karar verir; hiçbiri bizi göstermiyorsa nil.
    static func detect(service: String, socks: ProxySettings, secureWeb: ProxySettings,
                       host: String = ByeDPIArguments.defaultHost,
                       port: Int = ByeDPIArguments.defaultPort) -> OurProxyState? {
        let socksOurs = socks.pointsTo(host: host, port: port)
        let secureWebOurs = secureWeb.pointsTo(host: host, port: port)
        guard socksOurs || secureWebOurs else { return nil }
        return OurProxyState(service: service, socks: socksOurs, secureWeb: secureWebOurs,
                             hasForeignProxy: (socks.enabled && !socksOurs) || (secureWeb.enabled && !secureWebOurs))
    }

    /// Serviste bizi göstermeyen, AÇIK bir HTTPS veya SOCKS proxy varsa türünü ve "sunucu:port"
    /// bilgisini döndürür (açarken kullanıcının kendi proxy'sinin üzerine yazmamak için).
    static func foreignProxy(socks: ProxySettings, secureWeb: ProxySettings,
                             host: String = ByeDPIArguments.defaultHost,
                             port: Int = ByeDPIArguments.defaultPort) -> (kind: String, server: String)? {
        func address(_ p: ProxySettings) -> String {
            p.port.map { "\(p.server):\($0)" } ?? p.server
        }
        if secureWeb.enabled && !secureWeb.pointsTo(host: host, port: port) {
            return ("HTTPS", address(secureWeb))
        }
        if socks.enabled && !socks.pointsTo(host: host, port: port) {
            return ("SOCKS", address(socks))
        }
        return nil
    }
}

/// macOS sistem proxy ayarlarını (networksetup) yönetir: SOCKS + güvenli web proxy'si (HTTPS).
///
/// ciadpi `-G` ile aynı portta hem SOCKS5 hem HTTP CONNECT kabul eder; bu yüzden ikisi de
/// 127.0.0.1:1080'i gösterir. Düz web proxy'si (HTTP) ASLA ayarlanmaz: ciadpi
/// `GET http://...` biçimindeki düz HTTP proxy isteklerini karşılayamaz. Kullanıcının
/// "proxy kullanma" (bypass) listesine de dokunulmaz.
///
/// "Bizim proxy": herhangi bir ağ servisinde SOCKS veya HTTPS proxy AÇIK ve 127.0.0.1:1080'i gösteriyor
/// (v1.1.0'da yalnızca SOCKS açılmış olabilir; o da algılanır ve kapatılır).
/// ByeDPI kapalıyken bu ayar açık kalırsa trafik ölü bir proxy'ye gider (#14),
/// bu yüzden ByeDPIService durdurma/çıkış sırasında `disableAll()` çağırır.
@MainActor
final class SystemProxyService: ObservableObject {
    static let shared = SystemProxyService()

    /// Bizim proxy'mizin açık olduğu servisler ve hangi proxy türlerinin açık olduğu (son `refresh()`).
    @Published private(set) var activeProxies: [OurProxyState] = []
    /// Ayar değiştirilirken (parola penceresi vb.) true.
    @Published private(set) var isBusy = false
    /// En az bir kez kontrol edildi mi?
    @Published private(set) var hasChecked = false

    /// Bizim proxy'mizin açık olduğu servis adları.
    var activeServices: [String] { activeProxies.map(\.service) }

    var isOurProxyActive: Bool { !activeProxies.isEmpty }

    /// Durum satırları için: "Wi-Fi: SOCKS + HTTPS, USB LAN: SOCKS".
    var activeSummary: String { activeProxies.map(\.summary).joined(separator: ", ") }

    /// Bir serviste yalnızca SOCKS (ya da yalnızca HTTPS) açık: v1.1.0'dan kalma ya da yarım kalmış ayar.
    /// "Aç" bunları (birincil servis dışındakiler dahil) tek seferde tamamlar. Aynı serviste
    /// kullanıcının kendi proxy'si açıksa sayılmaz: "Aç" onun üzerine yazmaz.
    var hasIncompleteSetup: Bool { Self.needsCompletion(activeProxies) }

    /// "Aç" ile tamamlanabilecek yarım ayarlar var mı? (Saf; test edilebilir.)
    nonisolated static func needsCompletion(_ proxies: [OurProxyState]) -> Bool {
        proxies.contains { !$0.isComplete && !$0.hasForeignProxy }
    }

    let host: String
    let port: Int

    nonisolated private static let networksetup = "/usr/sbin/networksetup"

    /// Testler farklı bir port verir; böylece gerçek 127.0.0.1:1080 proxy'si asla eşleşmez
    /// ve yönetici penceresi açılmaz.
    init(host: String = ByeDPIArguments.defaultHost, port: Int = ByeDPIArguments.defaultPort) {
        self.host = host
        self.port = port
    }

    // MARK: - Durum

    /// Tüm ağ servislerini tarar ve bizim proxy'nin açık olduğu servisleri döndürür
    /// (ayrıntılar `activeProxies` içinde).
    @discardableResult
    func refresh() async -> [String] {
        let proxies = await Self.findOurProxies(host: host, port: port)
        if proxies != activeProxies {
            activeProxies = proxies
        }
        if !hasChecked { hasChecked = true }
        return proxies.map(\.service)
    }

    /// MainActor dışında çalışan tarama (yalnızca okuma: -get... komutları).
    nonisolated static func findOurProxies(host: String, port: Int) async -> [OurProxyState] {
        guard let list = try? await Shell.run(networksetup, ["-listallnetworkservices"], timeout: 15),
              list.succeeded else { return [] }
        let services = NetworkSetupParser.parseAllNetworkServices(list.stdout)
        var result: [OurProxyState] = []
        for service in services {
            let socks = await readProxy("-getsocksfirewallproxy", service: service.name)
            let secureWeb = await readProxy("-getsecurewebproxy", service: service.name)
            if let state = OurProxyState.detect(service: service.name, socks: socks, secureWeb: secureWeb,
                                                host: host, port: port) {
                result.append(state)
            }
        }
        return result
    }

    /// Okunamazsa (servis yok, zaman aşımı) kapalı sayılır.
    nonisolated static func readProxy(_ option: String, service: String) async -> ProxySettings {
        guard let out = try? await Shell.run(networksetup, [option, service], timeout: 10),
              out.succeeded else { return .off }
        return NetworkSetupParser.parseProxySettings(out.stdout)
    }

    // MARK: - Komut oluşturucular (tek parola penceresinde birleştirilebilir)

    /// SOCKS ve güvenli web (HTTPS) proxy'yi verilen servislerin her biri için ayarlayıp açar.
    ///
    /// Proxy'yi açmadan hemen önce, AYNI root kabukta ciadpi'nin hâlâ dinlediğini (bir kez) doğrular:
    /// parola penceresi açıkken ByeDPI durdurulur/çöker ya da uygulamadan çıkılırsa
    /// (osascript uygulamadan sonra da yaşar) ölü bir proxy açılmaz (#14).
    nonisolated static func enableCommand(services: [String], host: String = ByeDPIArguments.defaultHost,
                                          port: Int = ByeDPIArguments.defaultPort) -> String {
        let h = Shell.shellQuote(host)
        let guardPart = "/usr/sbin/lsof -a -nP -iTCP:\(port) -sTCP:LISTEN -c ciadpi -t >/dev/null 2>&1"
            + " || { echo \(SystemProxyError.noListenerMarker) >&2; exit 3; }"
        let perService = services.map { name -> String in
            let s = Shell.shellQuote(name)
            return "\(networksetup) -setsocksfirewallproxy \(s) \(h) \(port)"
                + " && \(networksetup) -setsecurewebproxy \(s) \(h) \(port)"
                + " && \(networksetup) -setsocksfirewallproxystate \(s) on"
                + " && \(networksetup) -setsecurewebproxystate \(s) on"
        }
        return guardPart + " ; " + perService.joined(separator: " && ")
    }

    /// Tek servis için kısayol.
    nonisolated static func enableCommand(service: String, host: String = ByeDPIArguments.defaultHost,
                                          port: Int = ByeDPIArguments.defaultPort) -> String {
        enableCommand(services: [service], host: host, port: port)
    }

    /// Yalnızca bizi gösteren proxy türlerini kapatır; kullanıcının başka bir sunucuya ayarlı
    /// kendi proxy'sine, düz web proxy'sine (HTTP) ve bypass listesine dokunmaz.
    nonisolated static func disableCommand(proxies: [OurProxyState]) -> String {
        var parts: [String] = []
        for proxy in proxies {
            let s = Shell.shellQuote(proxy.service)
            if proxy.socks {
                parts.append("\(networksetup) -setsocksfirewallproxystate \(s) off")
            }
            if proxy.secureWeb {
                parts.append("\(networksetup) -setsecurewebproxystate \(s) off")
            }
        }
        return parts.joined(separator: " ; ")
    }

    // MARK: - Değiştirme

    /// Parola penceresi açıklaması (proxy'yi kapatma).
    static var disablePrompt: String {
        L("SplitWire-Turkey, internet bağlantınızın çalışmaya devam etmesi için sistem proxy'sini kapatmak istiyor.",
          "SplitWire-Turkey wants to turn off the system proxy so your internet connection keeps working.")
    }

    /// Birincil ağ servisinde bizim SOCKS + HTTPS proxy'mizi açar; başka servislerde bizi gösteren
    /// yarım ayarlar (ör. v1.1.0'dan kalma yalnızca SOCKS) varsa aynı yönetici penceresinde tamamlar.
    /// Kullanıcının kendi (başka sunucuyu gösteren) SOCKS/HTTPS proxy'sinin üzerine asla yazmaz.
    /// - Returns: Proxy'nin açıldığı servis adı.
    /// - Throws: `SystemProxyError.foreignProxy`, `ShellError.userCancelled` veya diğer hatalar.
    @discardableResult
    func enable() async throws -> String {
        isBusy = true
        defer { isBusy = false }
        await refresh()
        // Varsayılan rota bir VPN (utun) ise IPv4 adresi olan ilk etkin fiziksel servise düşer
        let resolved = await NetworkConfigService.resolvePrimaryService()
        guard let service = resolved.service else {
            throw SystemProxyError.noActiveService
        }
        let socks = await Self.readProxy("-getsocksfirewallproxy", service: service)
        let secureWeb = await Self.readProxy("-getsecurewebproxy", service: service)
        if let f = OurProxyState.foreignProxy(socks: socks, secureWeb: secureWeb, host: host, port: port) {
            throw SystemProxyError.foreignProxy(service: service, kind: f.kind, server: f.server)
        }
        let others = activeProxies
            .filter { !$0.isComplete && !$0.hasForeignProxy && $0.service != service }
            .map(\.service)
        let targets = [service] + others
        let list = targets.joined(separator: ", ")
        do {
            try await Shell.runPrivileged(
                Self.enableCommand(services: targets, host: host, port: port),
                prompt: L("SplitWire-Turkey sistem proxy'sini (SOCKS + HTTPS, \(list) → \(host):\(port)) açmak istiyor.",
                          "SplitWire-Turkey wants to turn on the system proxy (SOCKS + HTTPS, \(list) → \(host):\(port)).")
            )
        } catch ShellError.privilegedCommandFailed(let message)
                    where message.contains(SystemProxyError.noListenerMarker) {
            await refresh()
            throw SystemProxyError.noListener
        }
        await refresh()
        return service
    }

    /// Bizim proxy'nin açık olduğu TÜM servislerde kapatır (tek yönetici penceresi).
    /// - Parameter timeout: Parola penceresi için üst süre (çıkışta takılmamak için).
    /// - Returns: Kapatılan servisler (hiçbiri açık değilse boş).
    @discardableResult
    func disableAll(prompt: String? = nil, timeout: TimeInterval? = nil) async throws -> [String] {
        isBusy = true
        defer { isBusy = false }
        let services = await refresh()
        guard !services.isEmpty else { return [] }
        try await Shell.runPrivileged(
            Self.disableCommand(proxies: activeProxies),
            prompt: prompt ?? Self.disablePrompt,
            timeout: timeout
        )
        await refresh()
        return services
    }
}
