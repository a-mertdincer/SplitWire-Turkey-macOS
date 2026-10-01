import XCTest
@testable import SplitWireTurkey

final class LocalizationTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SplitWireTurkeyTests.Localization.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testOnlyTurkishAndEnglish() {
        XCTAssertEqual(AppLanguage.allCases, [.turkish, .english])
        XCTAssertEqual(AppLanguage.turkish.rawValue, "tr")
        XCTAssertEqual(AppLanguage.english.rawValue, "en")
        XCTAssertEqual(AppLanguage.turkish.displayName, "Türkçe")
        XCTAssertEqual(AppLanguage.english.displayName, "English")
    }

    func testStringSelection() {
        XCTAssertEqual(L10n.string("Başlat", "Start", in: .turkish), "Başlat")
        XCTAssertEqual(L10n.string("Başlat", "Start", in: .english), "Start")
    }

    func testDefaultFollowsSystemLanguage() {
        XCTAssertEqual(L10n.defaultLanguage(preferredLanguages: ["tr-TR", "en-US"]), .turkish)
        XCTAssertEqual(L10n.defaultLanguage(preferredLanguages: ["tr"]), .turkish)
        XCTAssertEqual(L10n.defaultLanguage(preferredLanguages: ["en-TR", "tr-TR"]), .english)
        XCTAssertEqual(L10n.defaultLanguage(preferredLanguages: ["ru-RU"]), .english)
        XCTAssertEqual(L10n.defaultLanguage(preferredLanguages: []), .english)

        // Hiçbir şey kayıtlı değilse varsayılan kalıcı yazılmaz (sistem dilini izlemeye devam eder)
        XCTAssertEqual(L10n.resolve(defaults: defaults, preferredLanguages: ["tr-TR"]), .turkish)
        XCTAssertNil(defaults.string(forKey: L10n.defaultsKey))
    }

    func testStoredLanguageWins() {
        defaults.set("en", forKey: L10n.defaultsKey)
        defaults.set("Türkçe", forKey: L10n.legacyDefaultsKey)
        XCTAssertEqual(L10n.resolve(defaults: defaults, preferredLanguages: ["tr-TR"]), .english)
    }

    func testLegacyMigration() {
        let cases: [(String, AppLanguage)] = [("Türkçe", .turkish), ("English", .english), ("Русский", .english)]
        for (legacy, expected) in cases {
            defaults.removeObject(forKey: L10n.defaultsKey)
            defaults.set(legacy, forKey: L10n.legacyDefaultsKey)
            XCTAssertEqual(L10n.resolve(defaults: defaults, preferredLanguages: ["de-DE"]), expected, legacy)
            XCTAssertEqual(defaults.string(forKey: L10n.defaultsKey), expected.rawValue, legacy)
            XCTAssertNil(defaults.string(forKey: L10n.legacyDefaultsKey), legacy)
        }
    }

    func testUnknownValuesFallBackToSystemLanguage() {
        defaults.set("xx", forKey: L10n.defaultsKey)
        defaults.set("Klingon", forKey: L10n.legacyDefaultsKey)
        XCTAssertEqual(L10n.resolve(defaults: defaults, preferredLanguages: ["tr-TR"]), .turkish)
        XCTAssertEqual(L10n.resolve(defaults: defaults, preferredLanguages: ["en-GB"]), .english)
    }

    /// L10n.current yazımı: kaydeder, L(...) sonucunu değiştirir ve yalnızca değişimde bildirim yayınlar.
    /// (Test sürecinin kendi standart alanını kullanır; önceki değer geri yüklenir.)
    func testSettingCurrentPersistsAndNotifies() {
        let standard = UserDefaults.standard
        let previous = standard.object(forKey: L10n.defaultsKey)
        defer {
            if let previous {
                standard.set(previous, forKey: L10n.defaultsKey)
            } else {
                standard.removeObject(forKey: L10n.defaultsKey)
            }
            L10n.resetCacheForTesting()
        }

        L10n.current = .turkish
        XCTAssertEqual(L("Merhaba", "Hello"), "Merhaba")

        let changed = expectation(forNotification: .appLanguageDidChange, object: nil) { note in
            (note.userInfo?[L10n.languageUserInfoKey] as? AppLanguage) == .english
        }
        L10n.current = .english
        wait(for: [changed], timeout: 1)
        XCTAssertEqual(L("Merhaba", "Hello"), "Hello")
        XCTAssertEqual(standard.string(forKey: L10n.defaultsKey), "en")

        // Aynı değeri tekrar yazmak bildirim yayınlamaz
        let unchanged = expectation(forNotification: .appLanguageDidChange, object: nil)
        unchanged.isInverted = true
        L10n.current = .english
        wait(for: [unchanged], timeout: 0.2)

        // Diğer iş parçacıklarından okunabilir
        let background = expectation(description: "background read")
        DispatchQueue.global().async {
            XCTAssertEqual(L("Merhaba", "Hello"), "Hello")
            background.fulfill()
        }
        wait(for: [background], timeout: 1)
    }

    /// Durum mesajları iki dilde saklanır: dil değişince zaten gösterilen mesaj da çevrilir.
    func testLocalizedTextResolvesAtReadTime() {
        let text = LT("ByeDPI durduruldu.", "ByeDPI stopped.")
        withAppLanguage(.turkish) { XCTAssertEqual(text.resolved, "ByeDPI durduruldu.") }
        withAppLanguage(.english) { XCTAssertEqual(text.resolved, "ByeDPI stopped.") }
        XCTAssertEqual(LocalizedText.verbatim("x").tr, "x")
        XCTAssertEqual(LocalizedText.verbatim("x").en, "x")

        let preset = ByeDPIPresets.preset(id: ByeDPIPresets.defaultID)!
        XCTAssertEqual(preset.localizedName, LT("Standart", "Standard"))
        withAppLanguage(.english) { XCTAssertEqual(preset.name, "Standard") }
        XCTAssertEqual(ByeDPIPresets.preset(id: "OOB")!.localizedName, .verbatim("OOB"))
    }

    /// AppKit/SwiftUI sistem menüleri (Gizle/Çık/Düzen/Pencere) uygulama içi dil seçimini izlesin (#8):
    /// AppleLanguages yalnızca gerektiğinde ve yalnızca uygulama alanında ayarlanır.
    func testSystemUILanguageFollowsAppLanguage() throws {
        let suiteName = "SplitWireTurkeyLanguage-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        func effective() -> String? {
            Bundle.preferredLocalizations(from: ["en", "tr"],
                                          forPreferences: defaults.stringArray(forKey: "AppleLanguages") ?? []).first
        }

        defaults.set(["tr-TR"], forKey: "AppleLanguages")
        AppDelegate.syncSystemUILanguage(.turkish, defaults: defaults)
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["tr-TR"], "uyuşan tercih değiştirilmez")

        AppDelegate.syncSystemUILanguage(.english, defaults: defaults)
        XCTAssertEqual(effective(), "en")
        AppDelegate.syncSystemUILanguage(.turkish, defaults: defaults)
        XCTAssertEqual(effective(), "tr")
    }
}
