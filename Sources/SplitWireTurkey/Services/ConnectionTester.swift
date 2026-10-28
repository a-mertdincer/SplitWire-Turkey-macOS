import Foundation
import Combine

/// ByeDPI üzerinden yapılan tek bir bağlantı denemesi (#15).
struct ConnectionCheck: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        /// Discord'un pencere/sohbet trafiği (Chromium, TLS 1.3).
        case discordApp
        /// Discord'un açılıştaki güncelleme denetimi (updater.node, en çok TLS 1.2).
        case discordUpdater
        /// Roblox istemcisinin ilk istediği ayar sunucusu (#13).
        case roblox
    }

    let kind: Kind
    let url: URL
    /// TLS en çok 1.2 ile sınırlansın mı (Discord'un güncelleyicisi gibi)?
    let tls12Only: Bool

    var id: Kind { kind }

    var title: LocalizedText {
        switch kind {
        case .discordApp: return LT("Discord (uygulama)", "Discord (app)")
        case .discordUpdater: return LT("Discord güncelleme denetimi (TLS 1.2)", "Discord update check (TLS 1.2)")
        case .roblox: return .verbatim("Roblox")
        }
    }

    static let all: [ConnectionCheck] = [
        ConnectionCheck(kind: .discordApp, url: URL(string: "https://discord.com/api/v9/gateway")!, tls12Only: false),
        ConnectionCheck(
            kind: .discordUpdater,
            url: URL(string: "https://updates.discord.com/distributions/app/manifests/latest?channel=stable&platform=osx&arch=arm64")!,
            tls12Only: true
        ),
        ConnectionCheck(kind: .roblox, url: URL(string: "https://clientsettings.roblox.com/v2/client-version/MacPlayer")!, tls12Only: false),
    ]
}

struct ConnectionCheckResult: Identifiable, Equatable, Sendable {
    let check: ConnectionCheck
    /// TLS el sıkışması tamamlandı ve sunucu HTTP yanıtı verdi (durum kodu ne olursa olsun).
    let reachable: Bool
    /// Başarısızlıkta kısa neden (sistem dilinde URLError açıklaması).
    let detail: String

    var id: ConnectionCheck.Kind { check.kind }
}

/// Test sonuçlarından kullanıcıya gösterilecek teşhis (saf mantık, birim testli).
enum ConnectionDiagnosis: Equatable {
    case allReachable
    /// TLS 1.3 geçiyor ama TLS 1.2 kesiliyor: Discord "Checking for updates…" ekranında kalır.
    case tls12Blocked
    /// Hiçbiri geçmiyor ve DNS zehirli: ciadpi engelleme adresine bağlanıyor.
    case dnsPoisoned
    case allFailed
    case someFailed([ConnectionCheck.Kind])

    static func evaluate(_ results: [ConnectionCheckResult], dnsPoisoned: Bool) -> ConnectionDiagnosis {
        let failed = results.filter { !$0.reachable }.map(\.check.kind)
        if failed.isEmpty { return .allReachable }
        if failed.count == results.count {
            return dnsPoisoned ? .dnsPoisoned : .allFailed
        }
        if failed == [.discordUpdater] { return .tls12Blocked }
        return .someFailed(failed)
    }

    func message(currentPreset: String) -> LocalizedText {
        switch self {
        case .allReachable:
            return LT("ByeDPI üzerinden Discord (güncelleme denetimi dahil) ve Roblox'a ulaşılabiliyor.",
                      "Discord (including its update check) and Roblox are reachable through ByeDPI.")
        case .tls12Blocked:
            if currentPreset == ByeDPIPresets.defaultID {
                return LT("Bu yöntem TLS 1.2 bağlantılarını geçirmiyor; Discord açılışta \"Checking for updates…\" ekranında kalır. Özel yöntemde ör. -s 3 --tlsrec 1+s deneyin.",
                          "This method doesn't get TLS 1.2 connections through; Discord will stay on \"Checking for updates…\" at startup. Try e.g. -s 3 --tlsrec 1+s as a custom method.")
            }
            let name = ByeDPIPresets.preset(id: ByeDPIPresets.defaultID)!.localizedName
            return LT("Seçili yöntem TLS 1.2 bağlantılarını geçirmiyor; Discord açılışta \"Checking for updates…\" ekranında kalır. \(name.tr) yöntemini seçin.",
                      "The selected method doesn't get TLS 1.2 connections through; Discord will stay on \"Checking for updates…\" at startup. Choose the \(name.en) method.")
        case .dnsPoisoned:
            return LT("Hiçbir bağlantı kurulamadı: DNS engellemesi var (ByeDPI engelleme adresine bağlanıyor). Önce yukarıdaki uyarıdan DNS'i düzeltin.",
                      "No connection could be made: DNS is being blocked (ByeDPI connects to the block address). Fix DNS first using the warning above.")
        case .allFailed:
            return LT("Hiçbir bağlantı kurulamadı. Başka bir yöntem deneyin; Ağ Ayarları'ndan DNS'i de kontrol edin.",
                      "No connection could be made. Try another method, and check DNS in the Network tab.")
        case .someFailed(let kinds):
            let names = kinds.compactMap { kind in ConnectionCheck.all.first { $0.kind == kind }?.title }
            let tr = names.map(\.tr).joined(separator: ", ")
            let en = names.map(\.en).joined(separator: ", ")
            return LT("Şunlara ulaşılamadı: \(tr). Başka bir yöntem deneyin.",
                      "Couldn't reach: \(en). Try another method.")
        }
    }
}

/// ByeDPI'ın HTTPS proxy'si (HTTP CONNECT, ciadpi -G) üzerinden gerçek istekler yaparak yöntemin
/// bu ağda işe yarayıp yaramadığını ölçer. "ByeDPI çalışıyor ama Discord açılmıyor" (#15)
/// durumunu kullanıcıya gösterir: Discord'un güncelleyicisi ve Roblox da bu yoldan geçer.
@MainActor
final class ConnectionTester: ObservableObject {
    static let shared = ConnectionTester()

    @Published private(set) var results: [ConnectionCheckResult] = []
    @Published private(set) var isTesting = false
    /// Sonuçların ait olduğu ciadpi argümanları (yöntem değişince eski sonuç gösterilmez).
    @Published private(set) var testedArgs: String?
    /// Test sırasında DNS zehirli miydi? Teşhis sonuçlarla aynı ana ait olmalı: kullanıcı DNS'i
    /// sonradan düzeltirse eski "hepsi başarısız" sonucu "başka yöntem deneyin"e dönmesin.
    @Published private(set) var dnsPoisonedDuringTest = false

    private var generation = 0

    func run(host: String, port: Int, args: String?) async {
        generation += 1
        let current = generation
        isTesting = true
        results = []
        testedArgs = args
        dnsPoisonedDuringTest = DNSHealthChecker.shared.lastResult.isPoisoned

        let outcomes = await withTaskGroup(of: ConnectionCheckResult.self) { group in
            for check in ConnectionCheck.all {
                group.addTask { await Self.probe(check, host: host, port: port) }
            }
            var collected: [ConnectionCheckResult] = []
            for await result in group { collected.append(result) }
            return collected
        }
        // Bu sırada yeni bir test başladıysa (ör. yöntem değişti) eski sonucu yazma
        guard current == generation else { return }
        results = ConnectionCheck.all.compactMap { check in outcomes.first { $0.check.kind == check.kind } }
        isTesting = false
    }

    func clear() {
        generation += 1
        // Değişmeyen değerleri yeniden atama: @Published her atamada yayınlar
        if !results.isEmpty { results = [] }
        if testedArgs != nil { testedArgs = nil }
        if isTesting { isTesting = false }
    }

    nonisolated static func probe(_ check: ConnectionCheck, host: String, port: Int) async -> ConnectionCheckResult {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPSEnable as String: 1,
            kCFNetworkProxiesHTTPSProxy as String: host,
            kCFNetworkProxiesHTTPSPort as String: port,
        ]
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        if check.tls12Only {
            configuration.tlsMaximumSupportedProtocolVersion = .TLSv12
        }
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        do {
            let (_, response) = try await session.data(from: check.url)
            let reachable = response is HTTPURLResponse
            return ConnectionCheckResult(check: check, reachable: reachable, detail: "")
        } catch {
            return ConnectionCheckResult(check: check, reachable: false, detail: error.localizedDescription)
        }
    }
}
