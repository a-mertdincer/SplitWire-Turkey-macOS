import Foundation
import Combine

/// Sistem DNS'inin Discord adreslerini doğru çözüp çözmediğinin sonucu.
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

    /// Birden çok alan adının sonuçlarını birleştirir: biri bile poisoned ise poisoned,
    /// hepsi ok ise ok, aksi halde unknown.
    static func combine(_ states: [DNSHealthState]) -> DNSHealthState {
        if let poisoned = states.first(where: \.isPoisoned) { return poisoned }
        if !states.isEmpty, states.allSatisfy({ $0 == .ok }) { return .ok }
        return .unknown
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

/// Discord alan adlarının sistem DNS'i tarafından zehirlenip zehirlenmediğini kontrol eder.
///
/// ISS DNS'i discord.com için engelleme sayfası adresini döndürür; ciadpi hedefleri sistem
/// çözümleyicisiyle çözdüğü için ByeDPI bu durumda Discord'a bağlanamaz.
@MainActor
final class DNSHealthChecker: ObservableObject {
    static let shared = DNSHealthChecker()

    /// Kontrol edilen alan adları.
    nonisolated static let hosts = ["discord.com", "gateway.discord.gg"]

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
    /// Zehirlenmiş alan adı (uyarı metninde gösterilir).
    @Published private(set) var affectedHost: String = "discord.com"
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

        let results = await withTaskGroup(of: (String, DNSHealthState).self) { group in
            for host in Self.hosts {
                group.addTask {
                    async let system = Self.resolveSystemIPv4(host)
                    async let doh = Self.resolveDoH(host)
                    let state = DNSHealthEvaluator.evaluate(systemIPs: await system, dohIPs: await doh)
                    return (host, state)
                }
            }
            var collected: [(String, DNSHealthState)] = []
            for await item in group { collected.append(item) }
            // Sabit sıra: discord.com önce
            return collected.sorted { a, b in
                (Self.hosts.firstIndex(of: a.0) ?? 0) < (Self.hosts.firstIndex(of: b.0) ?? 0)
            }
        }

        let combined = DNSHealthEvaluator.combine(results.map(\.1))
        if let poisoned = results.first(where: { $0.1.isPoisoned }) {
            affectedHost = poisoned.0
        }
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
