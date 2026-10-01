import Foundation
import Combine

enum SystemProxyError: LocalizedError, Equatable {
    /// Yetkili komut çalışırken ciadpi artık dinlemiyordu; proxy açılmadı.
    case noListener
    /// Proxy'nin açılacağı etkin bir ağ servisi bulunamadı.
    case noActiveService

    /// Yetkili komutun stderr'e yazdığı işaret (yerelleştirilmez).
    static let noListenerMarker = "SPLITWIRE_NO_LISTENER"

    var errorDescription: String? {
        switch self {
        case .noListener:
            return L("ByeDPI artık çalışmıyor; sistem proxy açılmadı.",
                     "ByeDPI is no longer running; the system proxy was not turned on.")
        case .noActiveService:
            return L("Etkin ağ servisi bulunamadı", "No active network service found")
        }
    }
}

/// macOS sistem SOCKS proxy ayarını (networksetup) yönetir.
///
/// "Bizim proxy": herhangi bir ağ servisinde SOCKS proxy AÇIK ve 127.0.0.1:1080'i gösteriyor.
/// ByeDPI kapalıyken bu ayar açık kalırsa tüm trafik ölü bir proxy'ye gider (#14),
/// bu yüzden ByeDPIService durdurma/çıkış sırasında `disableAll()` çağırır.
@MainActor
final class SystemProxyService: ObservableObject {
    static let shared = SystemProxyService()

    /// Bizim proxy'mizin açık olduğu servisler (son `refresh()` sonucuna göre).
    @Published private(set) var activeServices: [String] = []
    /// Ayar değiştirilirken (parola penceresi vb.) true.
    @Published private(set) var isBusy = false
    /// En az bir kez kontrol edildi mi?
    @Published private(set) var hasChecked = false

    var isOurProxyActive: Bool { !activeServices.isEmpty }

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

    /// Tüm ağ servislerini tarar ve bizim proxy'nin açık olduğu servisleri döndürür.
    @discardableResult
    func refresh() async -> [String] {
        let services = await Self.findServicesWithOurProxy(host: host, port: port)
        if services != activeServices {
            activeServices = services
        }
        if !hasChecked { hasChecked = true }
        return services
    }

    /// MainActor dışında çalışan tarama.
    nonisolated static func findServicesWithOurProxy(host: String, port: Int) async -> [String] {
        guard let list = try? await Shell.run(networksetup, ["-listallnetworkservices"], timeout: 15),
              list.succeeded else { return [] }
        let services = NetworkSetupParser.parseAllNetworkServices(list.stdout)
        var result: [String] = []
        for service in services {
            guard let out = try? await Shell.run(networksetup, ["-getsocksfirewallproxy", service.name], timeout: 10),
                  out.succeeded else { continue }
            if NetworkSetupParser.parseSocksProxy(out.stdout).pointsTo(host: host, port: port) {
                result.append(service.name)
            }
        }
        return result
    }

    // MARK: - Komut oluşturucular (tek parola penceresinde birleştirilebilir)

    /// Proxy'yi açmadan hemen önce, AYNI root kabukta ciadpi'nin hâlâ dinlediğini doğrular:
    /// parola penceresi açıkken ByeDPI durdurulur/çöker ya da uygulamadan çıkılırsa
    /// (osascript uygulamadan sonra da yaşar) ölü bir proxy açılmaz (#14).
    nonisolated static func enableCommand(service: String, host: String = ByeDPIArguments.defaultHost,
                              port: Int = ByeDPIArguments.defaultPort) -> String {
        let s = Shell.shellQuote(service)
        return "/usr/sbin/lsof -a -nP -iTCP:\(port) -sTCP:LISTEN -c ciadpi -t >/dev/null 2>&1"
            + " || { echo \(SystemProxyError.noListenerMarker) >&2; exit 3; }"
            + " ; \(networksetup) -setsocksfirewallproxy \(s) \(Shell.shellQuote(host)) \(port)"
            + " && \(networksetup) -setsocksfirewallproxystate \(s) on"
    }

    nonisolated static func disableCommand(services: [String]) -> String {
        services
            .map { "\(networksetup) -setsocksfirewallproxystate \(Shell.shellQuote($0)) off" }
            .joined(separator: " ; ")
    }

    // MARK: - Değiştirme

    /// Parola penceresi açıklaması (proxy'yi kapatma).
    static var disablePrompt: String {
        L("SplitWire-Turkey, internet bağlantınızın çalışmaya devam etmesi için sistem proxy'sini kapatmak istiyor.",
          "SplitWire-Turkey wants to turn off the system proxy so your internet connection keeps working.")
    }

    /// Birincil ağ servisinde bizim SOCKS proxy'yi açar (tek yönetici penceresi).
    /// - Returns: Proxy'nin açıldığı servis adı.
    /// - Throws: `ShellError.userCancelled` veya diğer hatalar.
    @discardableResult
    func enable() async throws -> String {
        isBusy = true
        defer { isBusy = false }
        // Varsayılan rota bir VPN (utun) ise IPv4 adresi olan ilk etkin fiziksel servise düşer
        let resolved = await NetworkConfigService.resolvePrimaryService()
        guard let service = resolved.service else {
            throw SystemProxyError.noActiveService
        }
        do {
            try await Shell.runPrivileged(
                Self.enableCommand(service: service, host: host, port: port),
                prompt: L("SplitWire-Turkey sistem proxy'sini (\(service) → \(host):\(port)) açmak istiyor.",
                          "SplitWire-Turkey wants to turn on the system proxy (\(service) → \(host):\(port)).")
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
            Self.disableCommand(services: services),
            prompt: prompt ?? Self.disablePrompt,
            timeout: timeout
        )
        await refresh()
        return services
    }
}
