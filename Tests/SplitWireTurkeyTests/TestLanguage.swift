import Foundation
@testable import SplitWireTurkey

/// Arayüz metnini kontrol eden testler sistem dilinden (ör. İngilizce CI) bağımsız olsun diye
/// L10n.current'ı geçici olarak ayarlar; önceki kayıtlı değer ve önbellek geri yüklenir.
func withAppLanguage<T>(_ language: AppLanguage, _ body: () throws -> T) rethrows -> T {
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
    L10n.current = language
    return try body()
}
