import Foundation

// MARK: - Uygulama dili (#8)
//
// Kullanım (tüm dosyalar için kural):
//   L("Türkçe metin", "English text")
//   Text(L("...", "..."))                       — düz metin
//   Text(LocalizedStringKey(L("**kalın**", "**bold**")))  — Markdown içeren metin
// Teknik metinler (CLI argümanları, komutlar, yollar, IP'ler, proxy URL'leri) çevrilmez.
// Mantık asla yerelleştirilmiş metinlere göre karar vermez.

/// Arayüz dili. Ham değer UserDefaults'ta ("appLanguage") saklanır.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }

    /// Dil adı her zaman kendi dilinde gösterilir.
    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }

    /// SwiftUI `.environment(\.locale, ...)` için (tarih/sayı biçimleri).
    var locale: Locale { Locale(identifier: rawValue) }
}

extension Notification.Name {
    /// Dil değiştiğinde ana iş parçacığında yayınlanır. userInfo[L10n.languageUserInfoKey] = AppLanguage.
    static let appLanguageDidChange = Notification.Name("SplitWireTurkey.appLanguageDidChange")
}

/// Geçerli dilin küresel, iş parçacığı güvenli deposu.
enum L10n {
    static let defaultsKey = "appLanguage"
    /// v1.0.0'ın kaydettiği anahtar: "Türkçe" / "English" / "Русский".
    static let legacyDefaultsKey = "language"
    static let languageUserInfoKey = "language"

    private static let storage = LanguageStorage()

    /// Geçerli arayüz dili. Herhangi bir iş parçacığından okunabilir.
    /// Yazmak kalıcı olarak kaydeder ve `.appLanguageDidChange` yayınlar.
    /// Arayüzden değiştirirken `AppState.shared.selectedLanguage` kullanın.
    static var current: AppLanguage {
        get { storage.value(orResolve: resolveStandard) }
        set {
            let changed = storage.set(newValue, orResolve: resolveStandard)
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            guard changed else { return }
            let post = {
                NotificationCenter.default.post(
                    name: .appLanguageDidChange,
                    object: nil,
                    userInfo: [languageUserInfoKey: newValue]
                )
            }
            if Thread.isMainThread { post() } else { DispatchQueue.main.async(execute: post) }
        }
    }

    private static func resolveStandard() -> AppLanguage {
        resolve(defaults: .standard, preferredLanguages: Locale.preferredLanguages)
    }

    /// Verilen dile göre metni seçer (`L(_:_:)` bunu geçerli dille çağırır).
    static func string(_ tr: String, _ en: String, in language: AppLanguage) -> String {
        switch language {
        case .turkish: return tr
        case .english: return en
        }
    }

    /// Kayıtlı dili bulur; yoksa eski anahtarı taşır; o da yoksa sistem diline göre seçer.
    /// Eski anahtar bulunursa yeni anahtara yazılır ve eskisi silinir.
    static func resolve(defaults: UserDefaults, preferredLanguages: [String]) -> AppLanguage {
        if let raw = defaults.string(forKey: defaultsKey), let language = AppLanguage(rawValue: raw) {
            return language
        }
        if let legacy = defaults.string(forKey: legacyDefaultsKey),
           let language = migrateLegacy(legacy) {
            defaults.set(language.rawValue, forKey: defaultsKey)
            defaults.removeObject(forKey: legacyDefaultsKey)
            return language
        }
        return defaultLanguage(preferredLanguages: preferredLanguages)
    }

    /// v1.0.0 değerleri: Rusça çeviri olmadığından "Русский" İngilizceye döner.
    static func migrateLegacy(_ value: String) -> AppLanguage? {
        switch value {
        case "Türkçe": return .turkish
        case "English", "Русский": return .english
        default: return AppLanguage(rawValue: value)
        }
    }

    /// Hiçbir şey kaydedilmemişse: sistemin ilk tercih ettiği dil Türkçe ise Türkçe, değilse İngilizce.
    static func defaultLanguage(preferredLanguages: [String]) -> AppLanguage {
        guard let first = preferredLanguages.first?.lowercased() else { return .english }
        return first.hasPrefix("tr") ? .turkish : .english
    }

    /// Yalnızca testler için: önbelleği sıfırlar (bir sonraki okuma UserDefaults'tan yapılır).
    static func resetCacheForTesting() {
        storage.reset()
    }
}

/// Geçerli dile göre Türkçe ya da İngilizce metni döndürür. Her iş parçacığından çağrılabilir.
func L(_ tr: String, _ en: String) -> String {
    L10n.string(tr, en, in: L10n.current)
}

/// Her iki dildeki hâliyle saklanan metin. Servislerin durum mesajları bununla tutulur;
/// görünüm okurken geçerli dile çözülür, böylece dil değişince eski mesajlar da çevrilir (#8).
struct LocalizedText: Equatable, Sendable {
    let tr: String
    let en: String

    /// Geçerli dildeki metin.
    var resolved: String { L10n.string(tr, en, in: L10n.current) }

    /// Her iki dilde aynı olan (teknik/çevrilmeyen) metin.
    static func verbatim(_ text: String) -> LocalizedText { LocalizedText(tr: text, en: text) }
}

/// `L(_:_:)` gibi, ancak metni hemen seçmek yerine iki dili de saklar.
func LT(_ tr: String, _ en: String) -> LocalizedText {
    LocalizedText(tr: tr, en: en)
}

/// Kilitli önbellek (servisler ana aktör dışından da `L` çağırabilir).
private final class LanguageStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var cached: AppLanguage?

    func value(orResolve resolve: () -> AppLanguage) -> AppLanguage {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let resolved = resolve()
        cached = resolved
        return resolved
    }

    /// Değeri yazar; önceki (gerekirse çözümlenen) değerden farklıysa true döner.
    func set(_ language: AppLanguage, orResolve resolve: () -> AppLanguage) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let previous = cached ?? resolve()
        cached = language
        return previous != language
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        cached = nil
    }
}
