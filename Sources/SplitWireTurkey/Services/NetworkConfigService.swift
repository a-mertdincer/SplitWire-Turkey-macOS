import Foundation
import Combine

/// Hazır DNS sunucu seçenekleri.
enum DNSPreset: String, CaseIterable, Identifiable {
    case cloudflare
    case google
    case quad9

    var id: String { rawValue }

    var servers: [String] {
        switch self {
        case .cloudflare: return ["1.1.1.1", "1.0.0.1"]
        case .google: return ["8.8.8.8", "8.8.4.4"]
        case .quad9: return ["9.9.9.9", "149.112.112.112"]
        }
    }

    var name: String {
        switch self {
        case .cloudflare: return "Cloudflare"
        case .google: return "Google"
        case .quad9: return "Quad9"
        }
    }

    /// "Cloudflare (1.1.1.1, 1.0.0.1)"
    var title: String { "\(name) (\(servers.joined(separator: ", ")))" }

    static func matching(_ servers: [String]) -> DNSPreset? {
        allCases.first { $0.servers == servers }
    }
}

/// `networksetup` / `scutil --dns` çıktıları için saf ayrıştırıcılar (birim testli).
enum DNSConfigParser {
    /// `networksetup -getdnsservers <servis>` çıktısı. Elle ayarlı sunucu yoksa (DHCP) boş dizi,
    /// hata durumunda nil.
    static func parseGetDNSServers(_ output: String) -> [String]? {
        let lines = output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if lines.contains(where: { $0.hasPrefix("There aren't any DNS Servers set") }) { return [] }
        if lines.contains(where: { $0.contains("Error") || $0.contains("not a recognized network service") }) {
            return nil
        }
        return lines
    }

    /// `scutil --dns` çıktısından varsayılan (alan adına özel/ek olmayan) ilk çözümleyicinin
    /// sunucuları — DHCP kullanılırken gerçekte hangi DNS'in kullanıldığını göstermek için.
    static func parseEffectiveNameservers(_ output: String) -> [String] {
        // Yalnızca ilk bölüm ("DNS configuration"), kapsamlı (scoped) bölüm hariç.
        let main = output.components(separatedBy: "DNS configuration (for scoped queries)").first ?? output
        let sections = main.components(separatedBy: "resolver #").dropFirst()
        for section in sections {
            var nameservers: [String] = []
            var hasDomain = false
            var isSupplemental = false
            for rawLine in section.split(whereSeparator: \.isNewline) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard let colon = line.firstIndex(of: ":") else { continue }
                let key = line[..<colon].trimmingCharacters(in: .whitespaces)
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if key.hasPrefix("nameserver[") {
                    nameservers.append(value)
                } else if key == "domain" {
                    hasDomain = true
                } else if key == "flags", value.contains("Supplemental") {
                    isSupplemental = true
                }
            }
            if !nameservers.isEmpty, !hasDomain, !isSupplemental {
                return nameservers
            }
        }
        return []
    }
}

/// Birincil ağ servisinin DNS ayarlarını yönetir.
///
/// Önemli: `networksetup -setdnsservers` BSD aygıt adını (en0) DEĞİL, ağ SERVİSİ adını
/// (ör. "Wi-Fi") ister. Servis adı varsayılan rotanın arayüzünden
/// `networksetup -listnetworkserviceorder` ile bulunur.
@MainActor
final class NetworkConfigService: ObservableObject {
    static let shared = NetworkConfigService()

    enum StatusKind { case info, success, warning, error }

    /// Elle ayarlı DNS sunucuları; boşsa DHCP (otomatik).
    @Published private(set) var manualDNS: [String] = []
    /// DHCP kullanılırken gerçekte kullanılan DNS sunucuları (scutil --dns).
    @Published private(set) var effectiveDNS: [String] = []
    /// BSD aygıt adı (ör. "en0").
    @Published private(set) var primaryInterface: String?
    /// Ağ servisi adı (ör. "Wi-Fi").
    @Published private(set) var serviceName: String?
    @Published private(set) var hasLoaded = false
    @Published private(set) var isBusy = false
    /// Son durum mesajı; iki dilde saklanır, okunurken geçerli dile çözülür (#8).
    @Published private(set) var status: LocalizedText?
    @Published private(set) var statusKind: StatusKind = .info

    var statusMessage: String { status?.resolved ?? "" }

    var hasError: Bool { statusKind == .error }
    var isDHCP: Bool { manualDNS.isEmpty }
    var activePreset: DNSPreset? { DNSPreset.matching(manualDNS) }

    /// "Wi-Fi (en0)"
    var serviceDisplayName: String {
        switch (serviceName, primaryInterface) {
        case let (name?, device?): return "\(name) (\(device))"
        case let (name?, nil): return name
        case let (nil, device?): return device
        default: return L("Bilinmiyor", "Unknown")
        }
    }

    nonisolated static let networksetup = "/usr/sbin/networksetup"

    init() {}

    // MARK: - Bilgi

    func loadNetworkInfo() async {
        let (device, service) = await Self.resolvePrimaryService()
        primaryInterface = device
        serviceName = service
        await refreshDNS()
        hasLoaded = true
    }

    func refreshDNS() async {
        guard let service = serviceName else {
            manualDNS = []
            effectiveDNS = []
            return
        }
        if let out = try? await Shell.run(Self.networksetup, ["-getdnsservers", service], timeout: 10),
           let servers = DNSConfigParser.parseGetDNSServers(out.stdout) {
            manualDNS = servers
        } else {
            manualDNS = []
        }
        if let out = try? await Shell.run("/usr/sbin/scutil", ["--dns"], timeout: 10) {
            effectiveDNS = DNSConfigParser.parseEffectiveNameservers(out.stdout)
        } else {
            effectiveDNS = []
        }
    }

    /// Varsayılan rotanın arayüzü (en0) ve ona karşılık gelen ağ servisi adı (Wi-Fi).
    /// Ayrıştırma Core'un `NetworkSetupParser`'ını kullanır.
    nonisolated static func resolvePrimaryService() async -> (device: String?, service: String?) {
        var device: String?
        if let route = try? await Shell.run("/sbin/route", ["-n", "get", "default"], timeout: 10) {
            device = NetworkSetupParser.parseDefaultRouteInterface(route.stdout)
        }
        guard let order = try? await Shell.run(networksetup, ["-listnetworkserviceorder"], timeout: 15) else {
            return (device, nil)
        }
        let services = NetworkSetupParser.parseServiceOrder(order.stdout)
        if let device, let name = NetworkSetupParser.serviceName(forDevice: device, in: services) {
            return (device, name)
        }
        // Varsayılan rota bir VPN tüneli (utun) olabilir: IPv4 adresi olan ilk etkin fiziksel servise düş.
        for candidate in services where candidate.isEnabled {
            guard let dev = candidate.device, dev.hasPrefix("en") else { continue }
            if let addr = try? await Shell.run("/usr/sbin/ipconfig", ["getifaddr", dev], timeout: 5),
               addr.succeeded, !addr.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (dev, candidate.name)
            }
        }
        return (device, services.contains { $0.name == "Wi-Fi" } ? "Wi-Fi" : nil)
    }

    // MARK: - Komut oluşturucular

    /// DNS'i ayarlayan ve önbelleği temizleyen tek kabuk komutu (yönetici olarak çalıştırılır).
    /// `servers` boşsa DHCP'ye döner.
    nonisolated static func setDNSCommand(service: String, servers: [String]) -> String {
        let args = servers.isEmpty ? ["empty"] : servers
        let setPart = ([networksetup, "-setdnsservers", service] + args)
            .map(Shell.shellQuote)
            .joined(separator: " ")
        // Gruplama: networksetup başarısız olursa betiğin çıkış kodu onunki olur
        // (aksi hâlde "… || true" hatayı yutar ve gerçek hata metni kaybolurdu).
        return setPart + " && { " + flushCommand + "; }"
    }

    nonisolated static let flushCommand =
        "/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder || true"

    // MARK: - Değiştirme

    func apply(_ preset: DNSPreset) async {
        await setServers(preset.servers, label: preset.name)
    }

    func resetToDHCP() async {
        await setServers([], label: nil)
    }

    private func setServers(_ servers: [String], label: String?) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        if serviceName == nil { await loadNetworkInfo() }
        guard let service = serviceName else {
            setStatus(LT("Ağ servisi bulunamadı. İnternete bağlı olduğunuzdan emin olun.",
                        "No network service found. Make sure you are connected to the internet."), .error)
            return
        }

        if let label {
            setStatus(LT("DNS \(label) olarak ayarlanıyor (\(service))...",
                        "Setting DNS to \(label) (\(service))..."), .info)
        } else {
            setStatus(LT("DNS DHCP'ye sıfırlanıyor (\(service))...",
                        "Resetting DNS to DHCP (\(service))..."), .info)
        }
        do {
            try await Shell.runPrivileged(
                Self.setDNSCommand(service: service, servers: servers),
                prompt: L("SplitWire-Turkey, \(service) ağ servisinin DNS sunucularını değiştirmek istiyor.",
                          "SplitWire-Turkey wants to change the DNS servers of the \(service) network service."),
                timeout: 120
            )
        } catch ShellError.userCancelled {
            setStatus(LT("İşlem iptal edildi; DNS ayarları değiştirilmedi.",
                        "Cancelled; DNS settings were not changed."), .info)
            return
        } catch {
            setStatus(LT("DNS ayarlanamadı: \(error.localizedDescription)",
                        "Couldn't set DNS: \(error.localizedDescription)"), .error)
            return
        }

        await refreshDNS()
        if manualDNS == servers {
            if let label {
                setStatus(LT("\(service) için DNS \(label) olarak ayarlandı ve önbellek temizlendi.",
                            "DNS for \(service) set to \(label) and cache flushed."), .success)
            } else {
                setStatus(LT("\(service) için DNS DHCP'ye (otomatik) sıfırlandı ve önbellek temizlendi.",
                            "DNS for \(service) reset to DHCP (automatic) and cache flushed."), .success)
            }
        } else {
            let current = manualDNS.isEmpty ? "DHCP" : manualDNS.joined(separator: ", ")
            setStatus(LT("DNS komutu çalıştı ancak ayar doğrulanamadı (\(service)). Mevcut: \(current)",
                        "The DNS command ran but the setting couldn't be verified (\(service)). Current: \(current)"), .warning)
        }
        DNSHealthChecker.shared.scheduleRecheck(after: 2)
    }

    func flushDNSCache() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        setStatus(LT("DNS önbelleği temizleniyor...", "Flushing DNS cache..."), .info)
        do {
            try await Shell.runPrivileged(
                Self.flushCommand,
                prompt: L("SplitWire-Turkey DNS önbelleğini temizlemek istiyor.",
                          "SplitWire-Turkey wants to flush the DNS cache."),
                timeout: 120
            )
            setStatus(LT("DNS önbelleği temizlendi.", "DNS cache flushed."), .success)
            DNSHealthChecker.shared.scheduleRecheck(after: 2)
        } catch ShellError.userCancelled {
            setStatus(LT("İşlem iptal edildi.", "Cancelled."), .info)
        } catch {
            setStatus(LT("DNS önbelleği temizlenemedi: \(error.localizedDescription)",
                        "Couldn't flush DNS cache: \(error.localizedDescription)"), .error)
        }
    }

    private func setStatus(_ message: LocalizedText, _ kind: StatusKind) {
        status = message
        statusKind = kind
    }
}
