import Foundation

/// Hızlı İşlemler'de özel davranış gerektiren uygulamalar (#13).
enum KnownApps {
    static let robloxBundleID = "com.roblox.RobloxPlayer"
    /// Roblox'un menü çubuğu uygulaması (Roblox.app/Contents/MacOS/RobloxMenuBar.app).
    static let robloxMenuBarBundleID = "com.roblox.RobloxPlayer.MenuBar"

    /// Ana uygulamayla birlikte kapatılması gereken yardımcılar.
    ///
    /// Roblox ile menü çubuğu uygulaması birbirini ~1 sn içinde yeniden açar (kapatılan Roblox
    /// tepsi modunda `-launchToTray` ile geri gelir) ve yeni örnek ortamı onu açan süreçten alır.
    /// Yardımcı açık kalırsa Roblox'u HTTPS_PROXY olmadan geri açar.
    static func companionBundleIDs(of bundleID: String?) -> [String] {
        bundleID == robloxBundleID ? [robloxMenuBarBundleID] : []
    }

    /// Kapatma isteğinden sonra açık kalırsa sormadan zorla kapatılabilir mi?
    ///
    /// Roblox, menü çubuğu uygulaması açık değilken kapatılınca yalnızca penceresini kapatır ve
    /// arka planda çalışmaya devam eder; kullanıcı yeniden başlatmayı zaten onaylamıştır ve oyun
    /// ilerlemesi sunucuda tutulur.
    static func forceQuitsWithoutAsking(_ bundleID: String?) -> Bool {
        bundleID == robloxBundleID
    }
}
