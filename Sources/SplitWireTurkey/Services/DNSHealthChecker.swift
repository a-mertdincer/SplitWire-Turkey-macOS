import Foundation
import Combine

/// Sistem DNS'inin Discord ve Roblox adreslerini doğru çözüp çözmediğinin sonucu.
enum DNSHealthState: Equatable {
    /// Kontrol edilmedi ya da karar verilemedi (ör. DoH'a ulaşılamadı). Asla uyarı göstermez.
    case unknown
    case checking
    /// Sistem DNS'i gerçek adresleri döndürüyor.
    case ok
    /// Sistem DNS'i engelleme/sahte adres döndürüyor (#11/#9).
    case poisoned(systemIPs: [String], expectedIPs: [String])

    var isPoisoned: Bool {
        if case .poisoned = self { return true }
        return false
    }
}

/// DNS kontrolünde sorgulanan bir alan adı.
struct DNSCheckTarget: Equatable, Sendable {
    enum Rule: Equatable, Sendable {
        /// Sistem sonucu DoH sonucu ile karşılaştırılır (/16 eşleşmesi) ve bilinen engelleme adresine bakılır.
        case compareWithDoH
        /// Yalnızca bilinen engelleme adresine bakılır. CDN adresleri çözümleyicinin konumuna göre
        /// değişebildiği için (Roblox) farklı bir adres zehirlenme sayılmaz: yanlış alarm olmaz.
        case knownBlockIPOnly
    }

    let host: String
    /// Kullanıcıya gösterilen servis adı (özel isim, çevrilmez).
    let service: String
    let rule: Rule
}

/// Sistem çözümleyicisi ile DoH sonuçlarını karşılaştıran saf mantık (birim testli).
enum DNSHealthEvaluator {
    /// Türk ISS'lerinin bilinen engelleme sayfası adresleri.
    static let knownBlockIPs: Set<String> = [
        "195.175.254.2",            // Türk Telekom / BTK engelleme sayfası
        "2a01:358:4014:a00::3",     // aynı sayfanın IPv6 adresi
    ]

    /// Tek bir alan adı için karar.
    /// - Parameters:
    ///   - systemIPs: Sistem çözümleyicisinin (getaddrinfo) döndürdüğü adresler.
    ///   - dohIPs: DoH ile alınan gerçek adresler; DoH'a ulaşılamadıysa nil/boş.
    /// - Kurallar:
    ///   - Sistem bilinen bir engelleme adresi döndürüyorsa → poisoned (DoH olmasa bile kesin).
    ///   - DoH sonucu yoksa veya sistem hiç adres döndürmediyse → unknown (yanlış alarm yok).
    ///   - Sistem adreslerinden hiçbiri DoH adresleriyle aynı ağda (/16) değilse → poisoned.
    ///     (Cloudflare her sorguda farklı alt küme döndürebildiği için birebir eşleşme aranmaz.)
    static func evaluate(systemIPs: [String], dohIPs: [String]?) -> DNSHealthState {
        let system = unique(systemIPs)
        let expected = unique(dohIPs ?? [])

        if system.contains(where: { knownBlockIPs.contains($0) }) {
            return .poisoned(systemIPs: system, expectedIPs: expected)
        }
        guard !system.isEmpty, !expected.isEmpty else { return .unknown }

        let expectedNetworks = Set(expected.compactMap(networkKey))
        let overlaps = system.contains { ip in
            expected.contains(ip) || (networkKey(ip).map(expectedNetworks.contains) ?? false)
        }
        return overlaps ? .ok : .poisoned(systemIPs: system, expectedIPs: expected)
    }

    /// Hiçbir gerçek sunucuya gitmeyen IPv4 adresleri: 0.0.0.0/8 ve 127.0.0.0/8.
    /// (RFC1918 ve 198.18.0.0/15 bilerek dahil değil: Surge/Clash "fake-IP" modları ve
    /// iç ağ DNS'leri meşru olarak bunları döndürür.)
    static func isNonRoutable(_ ip: String) -> Bool {
        guard isIPv4(ip), let first = ip.split(separator: ".").first.flatMap({ UInt8($0) }) else { return false }
        return first == 0 || first == 127
    }

    /// Yalnızca engelleme adreslerine bakan karar (#13, Roblox).
    /// - Parameters:
    ///   - extraBlockIPs: Bu kontrolde başka bir alan adı (ör. discord.com) için zehirli bulunan
    ///     adresler: engelleme sayfası her engelli ad için aynı adresi döndürür.
    /// - Bilinen/ek engelleme adresi ya da 0.0.0.0/127.x → poisoned; sistem hiç adres
    ///   döndürmediyse → unknown; aksi halde ok (farklı CDN adresleri alarm vermez).
    static func evaluateKnownBlockIPOnly(systemIPs: [String], extraBlockIPs: Set<String> = []) -> DNSHealthState {
        let system = unique(systemIPs)
        if system.contains(where: { knownBlockIPs.contains($0) || extraBlockIPs.contains($0) || isNonRoutable($0) }) {
            return .poisoned(systemIPs: system, expectedIPs: [])
        }
        return system.isEmpty ? .unknown : .ok
    }

    /// Hedefin kuralına göre karar. `knownBlockIPOnly` için DoH sonucu kullanılmaz.
    static func evaluate(_ target: DNSCheckTarget, systemIPs: [String], dohIPs: [String]?,
                         extraBlockIPs: Set<String> = []) -> DNSHealthState {
        switch target.rule {
        case .compareWithDoH: return evaluate(systemIPs: systemIPs, dohIPs: dohIPs)
        case .knownBlockIPOnly: return evaluateKnownBlockIPOnly(systemIPs: systemIPs, extraBlockIPs: extraBlockIPs)
        }
    }

    /// Tüm hedefleri iki geçişte değerlendirir (sonuçlar girdi sırasıyla döner):
    /// 1. `compareWithDoH` hedefleri (Discord) DoH ile karşılaştırılır.
    /// 2. Zehirli çıkanların sistem adresleri, `knownBlockIPOnly` hedefleri (Roblox) için
    ///    ek engelleme adresi olarak kullanılır. Discord (Cloudflare) ile Roblox (128.116/16,
    ///    Akamai) aynı adresi paylaşmadığı için bu yanlış alarm üretmez.
    static func evaluateAll(_ inputs: [(target: DNSCheckTarget, systemIPs: [String], dohIPs: [String]?)])
        -> [(DNSCheckTarget, DNSHealthState)] {
        var states = [DNSHealthState?](repeating: nil, count: inputs.count)
        var extraBlockIPs = Set<String>()
        for (i, input) in inputs.enumerated() where input.target.rule == .compareWithDoH {
            let state = evaluate(input.target, systemIPs: input.systemIPs, dohIPs: input.dohIPs)
            if state.isPoisoned { extraBlockIPs.formUnion(input.systemIPs) }
            states[i] = state
        }
        for (i, input) in inputs.enumerated() where input.target.rule == .knownBlockIPOnly {
            states[i] = evaluate(input.target, systemIPs: input.systemIPs, dohIPs: input.dohIPs,
                                 extraBlockIPs: extraBlockIPs)
        }
        return inputs.enumerated().map { (i, input) in (input.target, states[i] ?? .unknown) }
    }

    /// Birden çok alan adının sonuçlarını birleştirir: biri bile poisoned ise poisoned
    /// (tüm zehirlenmiş sonuçların adresleri birleştirilir), hepsi ok ise ok, aksi halde unknown.
    static func combine(_ states: [DNSHealthState]) -> DNSHealthState {
        let poisoned = states.compactMap { state -> ([String], [String])? in
            if case .poisoned(let system, let expected) = state { return (system, expected) }
            return nil
        }
        if !poisoned.isEmpty {
            return .poisoned(systemIPs: unique(poisoned.flatMap(\.0)),
                             expectedIPs: unique(poisoned.flatMap(\.1)))
        }
        if !states.isEmpty, states.allSatisfy({ $0 == .ok }) { return .ok }
        return .unknown
    }

    /// Zehirlenmiş sonuçların servis adları (hedef sırasıyla, tekrarsız): ["Discord", "Roblox"].
    static func affectedServices(_ results: [(DNSCheckTarget, DNSHealthState)]) -> [String] {
        unique(results.filter { $0.1.isPoisoned }.map(\.0.service))
    }

    /// Zehirlenmiş alan adları (hedef sırasıyla).
    static func affectedHosts(_ results: [(DNSCheckTarget, DNSHealthState)]) -> [String] {
        unique(results.filter { $0.1.isPoisoned }.map(\.0.host))
    }

    /// IPv4 için ilk iki oktet ("162.159"); geçersiz/IPv6 ise nil.
    static func networkKey(_ ip: String) -> String? {
        let parts = ip.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({ UInt8($0) != nil }) else { return nil }
        return parts[0] + "." + parts[1]
    }

    static func isIPv4(_ s: String) -> Bool { networkKey(s) != nil }

    /// DoH JSON yanıtından (application/dns-json) A kayıtlarını çıkarır.
    /// Yanıt geçersizse veya Status != 0 (NOERROR) ise nil.
    static func parseDoHJSON(_ data: Data) -> [String]? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = object["Status"] as? Int, status == 0
        else { return nil }
        let answers = object["Answer"] as? [[String: Any]] ?? []
        let ips = answers.compactMap { answer -> String? in
            guard (answer["type"] as? Int) == 1, let ip = answer["data"] as? String, isIPv4(ip) else { return nil }
            return ip
        }
        return unique(ips)
    }

    static func unique(_ ips: [String]) -> [String] {
        var seen = Set<String>()
        return ips.filter { seen.insert($0).inserted }
    }
}

/// Discord ve Roblox alan adlarının sistem DNS'i tarafından zehirlenip zehirlenmediğini kontrol eder.
///
/// ISS DNS'i discord.com ve www.roblox.com için engelleme sayfası adresini döndürür; ciadpi
/// hedefleri (SOCKS ve HTTP CONNECT) sistem çözümleyicisiyle çözdüğü için ByeDPI bu durumda
/// bu servislere bağlanamaz.
@MainActor
final class DNSHealthChecker: ObservableObject {
    static let shared = DNSHealthChecker()

    /// Kontrol edilen alan adları (sıra = uyarıdaki sıra).
    nonisolated static let targets: [DNSCheckTarget] = [
        DNSCheckTarget(host: "discord.com", service: "Discord", rule: .compareWithDoH),
        DNSCheckTarget(host: "gateway.discord.gg", service: "Discord", rule: .compareWithDoH),
        DNSCheckTarget(host: "www.roblox.com", service: "Roblox", rule: .knownBlockIPOnly),
    ]

    nonisolated static var hosts: [String] { targets.map(\.host) }

    /// Kontrol edilen servis adları (tekrarsız, sıralı): ["Discord", "Roblox"].
    nonisolated static var services: [String] { DNSHealthEvaluator.unique(targets.map(\.service)) }

    /// DoH JSON uç noktaları; IP adresli olanlar önce (DNS'e ihtiyaç duymazlar).
    nonisolated static let dohEndpoints = [
        "https://1.1.1.1/dns-query",
        "https://8.8.8.8/resolve",
        "https://1.0.0.1/dns-query",
        "https://cloudflare-dns.com/dns-query",
        "https://dns.google/resolve",
    ]

    @Published private(set) var state: DNSHealthState = .unknown
    /// En son tamamlanan kontrolün sonucu (kontrol sürerken banner'ın kaybolmaması için).
    @Published private(set) var lastResult: DNSHealthState = .unknown
    /// Zehirlenmiş alan adları ve servisler (uyarı metninde gösterilir).
    @Published private(set) var affectedHosts: [String] = []
    @Published private(set) var affectedServices: [String] = []
    @Published private(set) var lastChecked: Date?

    var isChecking: Bool { state == .checking }

    private var recheckTask: Task<Void, Never>?

    init() {}

    /// Henüz hiç kontrol edilmediyse kontrol eder (ilk görünüm / açılış).
    func checkIfNeeded() async {
        guard lastChecked == nil, !isChecking else { return }
        await check()
    }

    /// DNS değişikliğinden sonra (önbellek boşalsın diye) kısa bir gecikmeyle yeniden kontrol.
    func scheduleRecheck(after seconds: Double = 2) {
        recheckTask?.cancel()
        recheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            // Başka bir kontrol sürüyorsa (eski DNS ile başlamış olabilir) bitmesini bekle;
            // aksi halde check() erken döner ve yeniden kontrol sessizce atlanırdı.
            while !Task.isCancelled, self?.isChecking == true {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            guard !Task.isCancelled else { return }
            await self?.check()
        }
    }

    func check() async {
        guard !isChecking else { return }
        state = .checking

        typealias Lookup = (target: DNSCheckTarget, systemIPs: [String], dohIPs: [String]?)
        let lookups = await withTaskGroup(of: Lookup.self) { group in
            for target in Self.targets {
                group.addTask {
                    async let system = Self.resolveSystemIPv4(target.host)
                    // Yalnızca engelleme adresine bakan hedefler için DoH sorgusu gerekmez
                    var doh: [String]?
                    if target.rule == .compareWithDoH {
                        doh = await Self.resolveDoH(target.host)
                    }
                    return (target, await system, doh)
                }
            }
            var collected: [Lookup] = []
            for await item in group { collected.append(item) }
            // Sabit sıra: discord.com önce
            return collected.sorted { a, b in
                (Self.targets.firstIndex(of: a.target) ?? 0) < (Self.targets.firstIndex(of: b.target) ?? 0)
            }
        }
        let results = DNSHealthEvaluator.evaluateAll(lookups)

        let combined = DNSHealthEvaluator.combine(results.map(\.1))
        affectedHosts = DNSHealthEvaluator.affectedHosts(results)
        affectedServices = DNSHealthEvaluator.affectedServices(results)
        lastResult = combined
        state = combined
        lastChecked = Date()
    }

    // MARK: - Çözümleme (MainActor dışında)

    /// Sistem çözümleyicisi (getaddrinfo, ciadpi'nin kullandığıyla aynı) ile IPv4 adresleri.
    nonisolated static func resolveSystemIPv4(_ host: String, timeout: TimeInterval = 6) async -> [String] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            let once = ResumeOnce(continuation)
            DispatchQueue.global(qos: .utility).async {
                once.resume(getaddrinfoIPv4(host))
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                once.resume([])
            }
        }
    }

    nonisolated static func getaddrinfoIPv4(_ host: String) -> [String] {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { return [] }
        defer { freeaddrinfo(first) }

        var ips: [String] = []
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let info = cursor {
            if info.pointee.ai_family == AF_INET, let addr = info.pointee.ai_addr {
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                    var inAddr = sin.pointee.sin_addr
                    _ = inet_ntop(AF_INET, &inAddr, &buffer, socklen_t(INET_ADDRSTRLEN))
                }
                let ip = String(cString: buffer)
                if !ip.isEmpty { ips.append(ip) }
            }
            cursor = info.pointee.ai_next
        }
        return DNSHealthEvaluator.unique(ips)
    }

    /// DoH ile gerçek adresler. Uç noktalar sırayla denenir; hiçbirine ulaşılamazsa nil.
    nonisolated static func resolveDoH(_ host: String) async -> [String]? {
        let session = makeDirectSession()
        defer { session.finishTasksAndInvalidate() }
        for endpoint in dohEndpoints {
            guard var components = URLComponents(string: endpoint) else { continue }
            components.queryItems = [
                URLQueryItem(name: "name", value: host),
                URLQueryItem(name: "type", value: "A"),
            ]
            guard let url = components.url else { continue }
            var request = URLRequest(url: url)
            request.setValue("application/dns-json", forHTTPHeaderField: "accept")
            do {
                let (data, response) = try await session.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      let ips = DNSHealthEvaluator.parseDoHJSON(data), !ips.isEmpty
                else { continue }
                return ips
            } catch {
                continue
            }
        }
        return nil
    }

    /// Önbelleksiz, kısa zaman aşımlı ve proxy'siz oturum: eski bir sistem SOCKS proxy'si
    /// (ölü 127.0.0.1:1080) kontrolü bozmasın.
    nonisolated static func makeDirectSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = false
        config.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable as String: false,
            kCFNetworkProxiesHTTPSEnable as String: false,
            kCFNetworkProxiesSOCKSEnable as String: false,
            kCFNetworkProxiesProxyAutoConfigEnable as String: false,
            kCFNetworkProxiesProxyAutoDiscoveryEnable as String: false,
        ]
        return URLSession(configuration: config)
    }
}

/// Bir continuation'ı yalnızca bir kez sürdürür (zaman aşımı ile yarış için).
private final class ResumeOnce<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(returning: value)
    }
}
