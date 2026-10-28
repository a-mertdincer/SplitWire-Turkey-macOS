import Foundation

/// Hızlı İşlemler'den başlatılan bir uygulamanın kendini yeniden başlatıp başlatmadığına karar
/// veren saf mantık (#15, birim testli).
///
/// Discord macOS'ta güncellemeyi kurduktan sonra yeni sürümü launchd üzerinden argümansız ve
/// ortam değişkensiz açar: yeni örnek `--proxy-server` ve HTTPS_PROXY olmadan başlar ve yine
/// "Checking for updates…" ekranında kalır. Bizim başlattığımız örnek kapandıktan kısa süre sonra
/// aynı uygulamanın yeni bir örneği açılırsa bu bir kendi kendine yeniden başlatmadır.
enum SelfRestartPolicy {
    /// Eski örneğin kapanması ile yenisinin açılması arasındaki en uzun süre.
    /// (Ölçüm: Discord 0.0.412 → 0.0.419 güncellemesinde ~4 sn.)
    static let restartWindow: TimeInterval = 30
    /// Döngüye karşı: bu süre içinde en çok `maxRelaunches` otomatik yeniden başlatma.
    static let relaunchPeriod: TimeInterval = 10 * 60
    static let maxRelaunches = 3

    /// Yeni örnek, bizim örneğin kendi kendine yeniden başlatması mı? (Kapanma ve açılma hangi
    /// sırayla bildirilirse bildirilsin, ikisi arasındaki süreye bakılır.)
    static func isSelfRestart(terminatedAt: Date?, newLaunchAt: Date) -> Bool {
        guard let terminatedAt else { return false }
        return abs(newLaunchAt.timeIntervalSince(terminatedAt)) <= restartWindow
    }

    /// Son `relaunchPeriod` içindeki otomatik yeniden başlatma sayısı sınırın altında mı?
    static func canRelaunch(previousRelaunches: [Date], now: Date) -> Bool {
        previousRelaunches.filter { now.timeIntervalSince($0) < relaunchPeriod }.count < maxRelaunches
    }

    /// Yeni örneğin komut satırı (`ps -o args=`) bizim argümanlarımızın hepsini içeriyor mu?
    /// İçeriyorsa (ör. Electron `app.relaunch()` argümanları korur) yeniden başlatmaya gerek yoktur.
    /// Komut satırı okunamazsa false: proxy'siz açıldığı varsayılır.
    static func commandLine(_ commandLine: String?, containsAll arguments: [String]) -> Bool {
        guard let commandLine else { return false }
        return arguments.allSatisfy { commandLine.contains($0) }
    }
}

/// İzlenen örneklerin durum makinesi (NSWorkspace'ten bağımsız, birim testli).
/// `SelfRestartWatcher` uygulama açılma/kapanma bildirimlerini buraya iletir.
struct SelfRestartTracker {
    /// Bir uygulama örneği: PID ve onu tanımlayan paket (bundle id veya paket yolu).
    struct Instance: Equatable {
        let pid: Int32
        let bundleID: String?
        let bundleURL: URL
    }

    /// Yeniden başlatılması gereken favori ve kendiliğinden açılan yeni örneğin PID'i.
    struct Decision: Equatable {
        let favoriteID: UUID
        let newPID: Int32
    }

    private struct Entry {
        let instance: Instance
        var terminatedAt: Date?
        /// Eski örnek henüz kapanmadan açılan yeni örnek (bildirim sırası garanti değil).
        var pendingNew: (pid: Int32, launchedAt: Date)?
    }

    private var entries: [UUID: Entry] = [:]
    private var relaunchDates: [UUID: [Date]] = [:]

    var trackedIDs: Set<UUID> { Set(entries.keys) }

    /// Bizim başlattığımız örneği izlemeye alır (aynı favori için öncekinin yerine geçer).
    mutating func track(_ favoriteID: UUID, _ instance: Instance) {
        entries[favoriteID] = Entry(instance: instance)
    }

    /// Uygulamayı kendimiz kapatıp açmadan önce: bizim kapatmamız kendi kendine yeniden başlatma
    /// sanılmasın (döngü olurdu). - Returns: İzlenen örneğin PID'i.
    @discardableResult
    mutating func untrack(_ favoriteID: UUID) -> Int32? {
        entries.removeValue(forKey: favoriteID)?.instance.pid
    }

    mutating func didTerminate(pid: Int32, at now: Date) -> Decision? {
        guard let id = entries.first(where: { $0.value.instance.pid == pid })?.key else { return nil }
        entries[id]?.terminatedAt = now
        guard let pending = entries[id]?.pendingNew,
              SelfRestartPolicy.isSelfRestart(terminatedAt: now, newLaunchAt: pending.launchedAt) else { return nil }
        return decide(id, newPID: pending.pid, now: now)
    }

    mutating func didLaunch(_ instance: Instance, at now: Date) -> Decision? {
        guard let (id, entry) = entries.first(where: { matches($0.value.instance, instance) && $0.value.instance.pid != instance.pid })
        else { return nil }
        guard let terminatedAt = entry.terminatedAt else {
            // Eski örnek hâlâ açık: kapanınca karar verilir
            entries[id]?.pendingNew = (instance.pid, now)
            return nil
        }
        guard SelfRestartPolicy.isSelfRestart(terminatedAt: terminatedAt, newLaunchAt: now) else {
            // Kullanıcı uygulamayı çok sonra kendisi açtı: karışma, izlemeyi bırak
            entries[id] = nil
            return nil
        }
        return decide(id, newPID: instance.pid, now: now)
    }

    /// Gerçekten yeniden başlatıldığında çağrılır. Yeniden başlatma gerekmeyen kararlar (yeni örnek
    /// argümanlarımızla açılmış, ör. Electron `app.relaunch()`) sınıra sayılmaz.
    mutating func recordRelaunch(_ favoriteID: UUID, at now: Date) {
        relaunchDates[favoriteID, default: []].append(now)
    }

    private mutating func decide(_ id: UUID, newPID: Int32, now: Date) -> Decision? {
        // İzleme, yeniden başlatılan örnek `track` ile yeniden eklenince sürer
        entries[id] = nil
        guard SelfRestartPolicy.canRelaunch(previousRelaunches: relaunchDates[id] ?? [], now: now) else { return nil }
        return Decision(favoriteID: id, newPID: newPID)
    }

    private func matches(_ tracked: Instance, _ other: Instance) -> Bool {
        if let bundleID = tracked.bundleID, other.bundleID == bundleID { return true }
        return tracked.bundleURL == other.bundleURL
    }
}
