import Foundation
import Combine

class AppState: ObservableObject {
    /// Uygulama genelindeki tek örnek (pencere ve menü çubuğu paylaşır).
    static let shared = AppState()

    @Published var isLoading = false
    @Published var statusMessage = ""
    @Published var selectedTab = 1  // Default to ByeDPI tab
    @Published var isDarkMode = false
    /// Arayüz dili (#8). Değişince hemen kaydedilir, `L10n.current` güncellenir ve
    /// `.appLanguageDidChange` yayınlanır (pencere yeniden kurulur, menü çubuğu yenilenir).
    @Published var selectedLanguage: AppLanguage = L10n.current {
        didSet {
            if selectedLanguage != L10n.current {
                L10n.current = selectedLanguage
            }
        }
    }

    // Favorite Apps for Quick Actions
    @Published var favoriteApps: [FavoriteApp] = []

    /// Dock simgesini gizle (uygulama menü çubuğunda yaşamaya devam eder). #6
    @Published var hideDockIcon = false {
        didSet {
            if hideDockIcon != oldValue {
                UserDefaults.standard.set(hideDockIcon, forKey: "hideDockIcon")
            }
        }
    }

    struct FavoriteApp: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        let path: String
        let bundleIdentifier: String?
        var customArgs: String  // Custom proxy arguments for this app

        init(name: String, path: String, bundleIdentifier: String? = nil, customArgs: String = "--proxy-server=socks5://127.0.0.1:1080") {
            self.id = UUID()
            self.name = name
            self.path = path
            self.bundleIdentifier = bundleIdentifier
            self.customArgs = customArgs
        }
    }

    private var languageObserver: NSObjectProtocol?

    init() {
        loadSettings()

        // L10n.current başka bir yerden değiştirilirse seçimi eşitle
        languageObserver = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let language = L10n.current
            if self.selectedLanguage != language {
                self.selectedLanguage = language
            }
        }
    }

    deinit {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }

    func loadSettings() {
        if let isDark = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool {
            isDarkMode = isDark
        }

        // Dil L10n tarafından okunur/taşınır (eski "language" anahtarı → "appLanguage")
        selectedLanguage = L10n.current

        hideDockIcon = UserDefaults.standard.bool(forKey: "hideDockIcon")

        // v1.0.0'ın hiçbir işe yaramayan WireGuard klasör/tarayıcı ayarları (#4): eski anahtarları temizle
        UserDefaults.standard.removeObject(forKey: "customFolders")
        UserDefaults.standard.removeObject(forKey: "includeBrowsers")

        // Load favorite apps
        if let data = UserDefaults.standard.data(forKey: "favoriteApps"),
           let apps = try? JSONDecoder().decode([FavoriteApp].self, from: data) {
            favoriteApps = apps
        } else {
            // Default favorites
            favoriteApps = [
                FavoriteApp(name: "Discord", path: "/Applications/Discord.app", bundleIdentifier: "com.hnc.Discord")
            ]
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")

        // Save favorite apps
        if let data = try? JSONEncoder().encode(favoriteApps) {
            UserDefaults.standard.set(data, forKey: "favoriteApps")
        }
    }

    // Favorite Apps Management
    func addFavoriteApp(_ app: FavoriteApp) {
        if !favoriteApps.contains(where: { $0.path == app.path }) {
            favoriteApps.append(app)
            saveSettings()
        }
    }

    func removeFavoriteApp(_ app: FavoriteApp) {
        favoriteApps.removeAll { $0.id == app.id }
        saveSettings()
    }

    func updateFavoriteApp(_ app: FavoriteApp) {
        if let index = favoriteApps.firstIndex(where: { $0.id == app.id }) {
            favoriteApps[index] = app
            saveSettings()
        }
    }

    func isFavorite(_ appPath: String) -> Bool {
        favoriteApps.contains { $0.path == appPath }
    }
}
