import Foundation

/// Bir ByeDPI (ciadpi) DPI aşım yöntemi.
struct ByeDPIPreset: Identifiable, Equatable, Hashable {
    /// Kalıcı kimlik (UserDefaults'ta saklanır). Asla çevrilmez; mantık yalnızca buna dayanır.
    let id: String
    /// ciadpi argümanları. "Custom" için boştur; kullanıcının argümanları kullanılır.
    let args: String

    /// Görünen ad (geçerli dilde). Teknik adlar (Split 1, Disorder, OOB...) çevrilmez.
    var name: String { localizedName.resolved }

    /// Görünen adın iki dildeki hâli (durum mesajları dil değişince de doğru kalsın).
    var localizedName: LocalizedText {
        switch id {
        case ByeDPIPresets.defaultID: return LT("Standart", "Standard")
        case ByeDPIPresets.customID: return LT("Özel", "Custom")
        default: return .verbatim(id)
        }
    }

    var isCustom: Bool { id == ByeDPIPresets.customID }
}

/// Tek ve sıralı preset tablosu (pencere ve menü çubuğu bu sırayı kullanır).
/// Tüm argümanlar macOS üzerinde doğrulanmıştır. Fake presetler macOS'ta
/// desteklenmediği için (FAKE_SUPPORT yalnızca Linux/Windows) kaldırıldı.
enum ByeDPIPresets {
    static let defaultID = "Standart"
    static let customID = "Custom"

    static let builtIn: [ByeDPIPreset] = [
        ByeDPIPreset(id: "Standart", args: "-r 1+s"),
        ByeDPIPreset(id: "Split 1", args: "-s 1 --tlsrec 1+s"),
        ByeDPIPreset(id: "Split 2", args: "-s 2 --tlsrec 1+s"),
        ByeDPIPreset(id: "Disorder", args: "--disorder 1 --auto=torst --tlsrec 1+s"),
        ByeDPIPreset(id: "Disorder SNI", args: "-d 1+s --tlsrec 1+s"),
        ByeDPIPreset(id: "OOB", args: "-o 1 --auto=torst"),
        ByeDPIPreset(id: "OOB SNI", args: "-o 1+s --tlsrec 1+s"),
        ByeDPIPreset(id: "Split + Disorder", args: "-s 1+s -d 3+s --tlsrec 1+s"),
    ]

    static let custom = ByeDPIPreset(id: customID, args: "")

    /// UI sırası: hazır presetler + Custom (en sonda).
    static let all: [ByeDPIPreset] = builtIn + [custom]

    static func preset(id: String) -> ByeDPIPreset? {
        all.first { $0.id == id }
    }

    /// Seçili preset için kullanılacak argüman metni.
    /// Custom seçiliyse kullanıcının argümanları, bilinmeyen bir id için Standart döner.
    static func args(for id: String, customArgs: String) -> String {
        if id == customID { return customArgs }
        return preset(id: id)?.args ?? builtIn[0].args
    }

    /// Kayıtlı preset değerini doğrular/taşır.
    /// - `stored`: yeni anahtar ("byedpiPreset")
    /// - `legacy`: eski menü çubuğu anahtarı ("menuBarPreset")
    /// Bilinmeyen ya da kaldırılmış presetler (ör. "Fake -1", "Fake 1") Standart'a döner.
    static func migrate(stored: String?, legacy: String?) -> String {
        let candidate = stored ?? legacy
        guard let candidate, preset(id: candidate) != nil else { return defaultID }
        return candidate
    }
}

/// ciadpi argüman ayrıştırma ve oluşturma (saf mantık, test edilebilir).
enum ByeDPIArguments {
    static let defaultHost = "127.0.0.1"
    static let defaultPort = 1080

    /// Argüman metnini boşluk/sekme/satır sonlarına göre böler.
    /// Basit çift (ve tek) tırnaklı parçaları destekler: `--user-agent="a b"` -> `--user-agent=a b`.
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var hasToken = false
        var quote: Character?

        for ch in text {
            if let q = quote {
                if ch == q {
                    quote = nil
                } else {
                    current.append(ch)
                }
                continue
            }
            if ch == "\"" || ch == "'" {
                quote = ch
                hasToken = true
            } else if ch.isWhitespace || ch.isNewline {
                if hasToken {
                    tokens.append(current)
                    current = ""
                    hasToken = false
                }
            } else {
                current.append(ch)
                hasToken = true
            }
        }
        if hasToken {
            tokens.append(current)
        }
        return tokens
    }

    static func containsListenIP(_ tokens: [String]) -> Bool {
        tokens.contains { token in
            token == "--ip" || token.hasPrefix("--ip=")
                || (token.hasPrefix("-i") && !token.hasPrefix("--"))
        }
    }

    static func containsPort(_ tokens: [String]) -> Bool {
        tokens.contains { token in
            token == "--port" || token.hasPrefix("--port=")
                || (token.hasPrefix("-p") && !token.hasPrefix("--"))
        }
    }

    /// ciadpi'ye verilecek son argüman dizisi.
    /// `-i 127.0.0.1` (LAN'a açık proxy olmasın diye) ve `-p 1080` yoksa eklenir.
    static func build(from text: String, host: String = defaultHost, port: Int = defaultPort) -> [String] {
        var tokens = tokenize(text)
        if !containsListenIP(tokens) {
            tokens = ["-i", host] + tokens
        }
        if !containsPort(tokens) {
            // -i'den hemen sonra (veya başa) ekle
            let insertAt = tokens.first == "-i" ? 2 : 0
            tokens.insert(contentsOf: ["-p", String(port)], at: min(insertAt, tokens.count))
        }
        return tokens
    }

    /// Görüntüleme için argüman dizisini tek satıra çevirir (boşluk içerenleri tırnaklar).
    static func displayString(_ tokens: [String]) -> String {
        tokens.map { token in
            token.isEmpty || token.contains(where: { $0.isWhitespace })
                ? "\"\(token)\"" : token
        }.joined(separator: " ")
    }
}
