import XCTest
@testable import SplitWireTurkey

/// #15: Discord güncellemeyi kurduktan sonra kendini proxy'siz yeniden açar; izleyici bunu yakalar.
final class SelfRestartTrackerTests: XCTestCase {
    private let discordURL = URL(fileURLWithPath: "/Applications/Discord.app")
    private let favorite = UUID()
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func discord(_ pid: Int32) -> SelfRestartTracker.Instance {
        .init(pid: pid, bundleID: "com.hnc.Discord", bundleURL: discordURL)
    }

    /// Ölçülen sıra: eski örnek kapanır, ~4 sn sonra yeni sürüm açılır.
    func testTerminateThenLaunchTriggersRelaunch() {
        var tracker = SelfRestartTracker()
        tracker.track(favorite, discord(100))
        XCTAssertNil(tracker.didTerminate(pid: 100, at: t0))
        let decision = tracker.didLaunch(discord(200), at: t0 + 4)
        XCTAssertEqual(decision, .init(favoriteID: favorite, newPID: 200))
        // Karar verilince izleme biter; yeniden başlatılan örnek yeniden `track` edilir
        XCTAssertTrue(tracker.trackedIDs.isEmpty)
    }

    /// Bildirim sırası garanti değil: yeni örnek eski kapanmadan bildirilebilir.
    func testLaunchBeforeTerminateTriggersOnTermination() {
        var tracker = SelfRestartTracker()
        tracker.track(favorite, discord(100))
        XCTAssertNil(tracker.didLaunch(discord(200), at: t0))
        XCTAssertEqual(tracker.didTerminate(pid: 100, at: t0 + 1), .init(favoriteID: favorite, newPID: 200))
    }

    /// Kullanıcı Discord'u kapatıp çok sonra Dock'tan açarsa karışılmaz.
    func testLateManualReopenIsIgnored() {
        var tracker = SelfRestartTracker()
        tracker.track(favorite, discord(100))
        XCTAssertNil(tracker.didTerminate(pid: 100, at: t0))
        XCTAssertNil(tracker.didLaunch(discord(200), at: t0 + SelfRestartPolicy.restartWindow + 1))
        XCTAssertTrue(tracker.trackedIDs.isEmpty)
    }

    /// Bizim kapatıp açtığımız (untrack edilmiş) örnek yeniden başlatma sanılmaz: döngü olmaz.
    func testUntrackedRestartIsIgnored() {
        var tracker = SelfRestartTracker()
        tracker.track(favorite, discord(100))
        XCTAssertEqual(tracker.untrack(favorite), 100)
        XCTAssertNil(tracker.didTerminate(pid: 100, at: t0))
        XCTAssertNil(tracker.didLaunch(discord(200), at: t0 + 1))
        XCTAssertNil(tracker.untrack(favorite))
    }

    /// Başka uygulamalar ve aynı örneğin kendi bildirimi tetiklemez.
    func testUnrelatedAppsAreIgnored() {
        var tracker = SelfRestartTracker()
        tracker.track(favorite, discord(100))
        XCTAssertNil(tracker.didTerminate(pid: 100, at: t0))
        let other = SelfRestartTracker.Instance(pid: 300, bundleID: "com.google.Chrome",
                                                bundleURL: URL(fileURLWithPath: "/Applications/Google Chrome.app"))
        XCTAssertNil(tracker.didLaunch(other, at: t0 + 1))
        XCTAssertNil(tracker.didLaunch(discord(100), at: t0 + 1))
        XCTAssertNil(tracker.didTerminate(pid: 999, at: t0 + 2))
        XCTAssertEqual(tracker.didLaunch(discord(200), at: t0 + 3)?.newPID, 200)
    }

    /// Bundle id yoksa paket yolu eşleşmesi yeterli.
    func testMatchesByBundleURLWithoutBundleID() {
        var tracker = SelfRestartTracker()
        tracker.track(favorite, .init(pid: 100, bundleID: nil, bundleURL: discordURL))
        XCTAssertNil(tracker.didTerminate(pid: 100, at: t0))
        XCTAssertEqual(tracker.didLaunch(.init(pid: 200, bundleID: nil, bundleURL: discordURL), at: t0 + 2)?.newPID, 200)
    }

    /// Döngüye karşı: 10 dakikada en çok 3 otomatik yeniden başlatma.
    func testRelaunchLimit() {
        var tracker = SelfRestartTracker()
        var pid: Int32 = 100
        var now = t0
        var triggered = 0
        for _ in 0..<5 {
            tracker.track(favorite, discord(pid))
            _ = tracker.didTerminate(pid: pid, at: now)
            pid += 1
            if tracker.didLaunch(discord(pid), at: now + 1) != nil {
                triggered += 1
                tracker.recordRelaunch(favorite, at: now + 1)
            }
            now += 10
        }
        XCTAssertEqual(triggered, SelfRestartPolicy.maxRelaunches)

        // Süre dolunca yeniden izin verilir
        tracker.track(favorite, discord(pid))
        _ = tracker.didTerminate(pid: pid, at: t0 + SelfRestartPolicy.relaunchPeriod + 60)
        XCTAssertNotNil(tracker.didLaunch(discord(pid + 1), at: t0 + SelfRestartPolicy.relaunchPeriod + 61))
    }

    /// Yeniden başlatma gerekmeyen kararlar (Electron `app.relaunch()` argümanları korur) sınıra
    /// sayılmaz: sonraki gerçek güncelleme yine yakalanır.
    func testDecisionsWithoutRelaunchDoNotCountTowardLimit() {
        var tracker = SelfRestartTracker()
        var pid: Int32 = 100
        for step in 0..<(SelfRestartPolicy.maxRelaunches + 2) {
            let now = t0 + Double(step) * 10
            tracker.track(favorite, discord(pid))
            _ = tracker.didTerminate(pid: pid, at: now)
            pid += 1
            XCTAssertNotNil(tracker.didLaunch(discord(pid), at: now + 1))
        }
    }

    /// Electron app.relaunch() argümanları korur: o zaman yeniden açmaya gerek yok.
    func testCommandLineContainsArguments() {
        let args = ["--proxy-server=socks5://127.0.0.1:1080"]
        XCTAssertTrue(SelfRestartPolicy.commandLine(
            "/Applications/Discord.app/Contents/MacOS/Discord --proxy-server=socks5://127.0.0.1:1080", containsAll: args))
        XCTAssertFalse(SelfRestartPolicy.commandLine("/Applications/Discord.app/Contents/MacOS/Discord", containsAll: args))
        XCTAssertFalse(SelfRestartPolicy.commandLine(nil, containsAll: args))
    }

    /// #13: Roblox menü çubuğu uygulamasıyla birlikte kapatılır ve kapanmazsa sormadan zorla kapatılır;
    /// diğer uygulamalarda davranış değişmez.
    func testKnownApps() {
        XCTAssertEqual(KnownApps.companionBundleIDs(of: KnownApps.robloxBundleID), [KnownApps.robloxMenuBarBundleID])
        XCTAssertEqual(KnownApps.companionBundleIDs(of: "com.hnc.Discord"), [])
        XCTAssertEqual(KnownApps.companionBundleIDs(of: nil), [])
        XCTAssertTrue(KnownApps.forceQuitsWithoutAsking(KnownApps.robloxBundleID))
        XCTAssertFalse(KnownApps.forceQuitsWithoutAsking("com.hnc.Discord"))
        XCTAssertFalse(KnownApps.forceQuitsWithoutAsking(nil))
    }
}

/// #15: bağlantı testi sonuçlarından teşhis.
final class ConnectionDiagnosisTests: XCTestCase {
    private func results(_ reachable: [ConnectionCheck.Kind: Bool]) -> [ConnectionCheckResult] {
        ConnectionCheck.all.map { ConnectionCheckResult(check: $0, reachable: reachable[$0.kind] ?? true, detail: "") }
    }

    func testChecks() {
        XCTAssertEqual(ConnectionCheck.all.map(\.kind), [.discordApp, .discordUpdater, .roblox])
        // Yalnızca güncelleyici denetimi TLS 1.2 ile sınırlı (updater.node gibi)
        XCTAssertEqual(ConnectionCheck.all.filter(\.tls12Only).map(\.kind), [.discordUpdater])
        XCTAssertEqual(ConnectionCheck.all.first { $0.kind == .discordUpdater }?.url.host, "updates.discord.com")
    }

    func testDiagnosis() {
        XCTAssertEqual(ConnectionDiagnosis.evaluate(results([:]), dnsPoisoned: true), .allReachable)
        // Ölçülen durum: Standart yöntemle TLS 1.3 geçiyor, TLS 1.2 kesiliyor
        XCTAssertEqual(ConnectionDiagnosis.evaluate(results([.discordUpdater: false]), dnsPoisoned: false), .tls12Blocked)
        let none: [ConnectionCheck.Kind: Bool] = [.discordApp: false, .discordUpdater: false, .roblox: false]
        XCTAssertEqual(ConnectionDiagnosis.evaluate(results(none), dnsPoisoned: true), .dnsPoisoned)
        XCTAssertEqual(ConnectionDiagnosis.evaluate(results(none), dnsPoisoned: false), .allFailed)
        XCTAssertEqual(ConnectionDiagnosis.evaluate(results([.roblox: false]), dnsPoisoned: false), .someFailed([.roblox]))
    }

    func testTLS12MessageSuggestsRecommendedMethod() {
        withAppLanguage(.english) {
            let fromStandard = ConnectionDiagnosis.tls12Blocked.message(currentPreset: "Standart").resolved
            XCTAssertTrue(fromStandard.contains("Split 2 (recommended)"), fromStandard)
            // Zaten önerilen yöntemdeyse başka bir yöntem önerilir
            let fromDefault = ConnectionDiagnosis.tls12Blocked.message(currentPreset: ByeDPIPresets.defaultID).resolved
            XCTAssertFalse(fromDefault.contains("Choose the"), fromDefault)
            XCTAssertTrue(fromDefault.contains("-s 3 --tlsrec 1+s"), fromDefault)
        }
    }
}
