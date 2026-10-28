import AppKit

/// Hızlı İşlemler'den başlatılan uygulamaları izler. Biri kapanır kapanmaz aynı uygulamanın
/// yeni bir örneği açılırsa (ör. Discord güncellemeyi kurup kendini proxy'siz yeniden başlattı, #15)
/// `onSelfRestart` çağrılır. Karar mantığı `SelfRestartTracker` / `SelfRestartPolicy` içindedir.
@MainActor
final class SelfRestartWatcher {
    private var tracker = SelfRestartTracker()
    private var observers: [NSObjectProtocol] = []
    /// Favorinin karar anındaki güncel hâli; silinmişse nil (eski kopya kullanılmaz:
    /// kullanıcı parametreleri düzenlemiş ya da favoriyi kaldırıp yeniden eklemiş olabilir).
    private let currentFavorite: (UUID) -> AppState.FavoriteApp?
    private let onSelfRestart: (AppState.FavoriteApp, NSRunningApplication) -> Void

    init(
        currentFavorite: @escaping (UUID) -> AppState.FavoriteApp?,
        onSelfRestart: @escaping (AppState.FavoriteApp, NSRunningApplication) -> Void
    ) {
        self.currentFavorite = currentFavorite
        self.onSelfRestart = onSelfRestart
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            Task { @MainActor in self?.handle(self?.tracker.didTerminate(pid: pid, at: Date())) }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let instance = Self.instance(app) else { return }
            Task { @MainActor in self?.handle(self?.tracker.didLaunch(instance, at: Date())) }
        })
    }

    /// Bizim başlattığımız örneği izlemeye alır (aynı favori için öncekinin yerine geçer).
    func track(_ favorite: AppState.FavoriteApp, instance: NSRunningApplication) {
        let fallbackURL = URL(fileURLWithPath: favorite.path)
        let tracked = SelfRestartTracker.Instance(
            pid: instance.processIdentifier,
            bundleID: instance.bundleIdentifier ?? favorite.bundleIdentifier,
            bundleURL: Self.normalized(instance.bundleURL ?? fallbackURL)
        )
        tracker.track(favorite.id, tracked)
    }

    /// Uygulamayı kendimiz kapatıp açmadan önce çağrılır: bizim kapatmamız kendi kendine
    /// yeniden başlatma sanılmasın (döngü olurdu).
    /// - Returns: İzlenen örneğin PID'i (iptal edilirse yeniden izlemek için).
    @discardableResult
    func untrack(_ favorite: AppState.FavoriteApp) -> pid_t? {
        tracker.untrack(favorite.id)
    }

    /// Otomatik yeniden başlatma yapıldı (döngü sınırına sayılır).
    func recordRelaunch(_ favorite: AppState.FavoriteApp) {
        tracker.recordRelaunch(favorite.id, at: Date())
    }

    private func handle(_ decision: SelfRestartTracker.Decision?) {
        guard let decision, let favorite = currentFavorite(decision.favoriteID),
              let app = NSRunningApplication(processIdentifier: decision.newPID), !app.isTerminated else { return }
        onSelfRestart(favorite, app)
    }

    nonisolated private static func instance(_ app: NSRunningApplication) -> SelfRestartTracker.Instance? {
        guard let url = app.bundleURL else { return nil }
        return SelfRestartTracker.Instance(pid: app.processIdentifier, bundleID: app.bundleIdentifier,
                                           bundleURL: normalized(url))
    }

    nonisolated private static func normalized(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
