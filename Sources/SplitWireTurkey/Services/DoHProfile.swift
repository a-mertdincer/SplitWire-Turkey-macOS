import Foundation
import AppKit

/// Cloudflare DNS over HTTPS (DoH) yapılandırma profili (.mobileconfig) üretir.
///
/// Bazı ISS'ler 53. port DNS trafiğini yakalayıp kendi cevabını döndürür; bu durumda DNS'i
/// 1.1.1.1 yapmak işe yaramaz. DoH, sorguları HTTPS (443) üzerinden şifreli gönderdiği için
/// bu müdahaleyi atlatır. Profil kullanıcı tarafından Sistem Ayarları'ndan yüklenir —
/// uygulama profili kendisi YÜKLEMEZ.
enum DoHProfile {
    static let identifier = "com.splitwire.doh.cloudflare"
    static let displayName = "SplitWire – Cloudflare DNS over HTTPS"
    static let serverURL = "https://cloudflare-dns.com/dns-query"
    /// ServerAddresses verildiği için ServerURL'deki ad (cloudflare-dns.com) zehirli DNS ile
    /// çözülmez; sistem doğrudan bu adreslere bağlanır.
    static let serverAddresses = [
        "1.1.1.1",
        "1.0.0.1",
        "2606:4700:4700::1111",
        "2606:4700:4700::1001",
    ]
    static let fileName = "SplitWire-Cloudflare-DoH.mobileconfig"

    /// Profil sözlüğü (her çağrıda yeni UUID'ler).
    static func makePayload(
        profileUUID: UUID = UUID(),
        dnsPayloadUUID: UUID = UUID()
    ) -> [String: Any] {
        let dnsPayload: [String: Any] = [
            "DNSSettings": [
                "DNSProtocol": "HTTPS",
                "ServerURL": serverURL,
                "ServerAddresses": serverAddresses,
            ] as [String: Any],
            "PayloadType": "com.apple.dnsSettings.managed",
            "PayloadIdentifier": "\(identifier).dnssettings",
            "PayloadUUID": dnsPayloadUUID.uuidString,
            "PayloadVersion": 1,
            "PayloadDisplayName": "Cloudflare DoH (1.1.1.1)",
            "PayloadDescription": L("DNS sorgularını Cloudflare'e HTTPS üzerinden şifreli gönderir.",
                                    "Sends DNS queries to Cloudflare encrypted over HTTPS."),
        ]
        return [
            "PayloadContent": [dnsPayload],
            "PayloadType": "Configuration",
            "PayloadIdentifier": identifier,
            "PayloadUUID": profileUUID.uuidString,
            "PayloadVersion": 1,
            "PayloadDisplayName": displayName,
            "PayloadDescription": L("ISS DNS engellemesini aşmak için DNS sorgularını Cloudflare DNS over HTTPS (1.1.1.1) üzerinden yapar. Sistem Ayarları > Genel > Aygıt Yönetimi (macOS 13–14: Gizlilik ve Güvenlik > Profiller) bölümünden istediğiniz zaman kaldırabilirsiniz.",
                                    "Sends DNS queries through Cloudflare DNS over HTTPS (1.1.1.1) to get around ISP DNS blocking. You can remove it at any time in System Settings > General > Device Management (macOS 13–14: Privacy & Security > Profiles)."),
            "PayloadOrganization": "SplitWire-Turkey",
            "PayloadScope": "System",
            "PayloadRemovalDisallowed": false,
        ]
    }

    /// XML plist (.mobileconfig) verisi.
    static func makeData(
        profileUUID: UUID = UUID(),
        dnsPayloadUUID: UUID = UUID()
    ) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: makePayload(profileUUID: profileUUID, dnsPayloadUUID: dnsPayloadUUID),
            format: .xml,
            options: 0
        )
    }

    /// Varsayılan kayıt yeri: ~/Downloads/SplitWire-Cloudflare-DoH.mobileconfig
    static func defaultURL() -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        return downloads.appendingPathComponent(fileName)
    }

    /// Profili yazar (varsa üzerine) ve URL'sini döndürür.
    @discardableResult
    static func write(to url: URL = defaultURL()) throws -> URL {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try makeData().write(to: url, options: .atomic)
        return url
    }

    /// Profili kaydeder ve macOS'a açtırır (Sistem Ayarları "Profil indirildi" bildirimi gösterir).
    /// Yükleme kullanıcı onayı gerektirir; uygulama yüklemez.
    @MainActor
    @discardableResult
    static func saveAndOpen() throws -> URL {
        let url = try write()
        NSWorkspace.shared.open(url)
        return url
    }

    /// Sistem Ayarları > Genel > Aygıt Yönetimi (Profiller) bölmesini açar.
    @MainActor
    static func openProfilesSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Profiles-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.configurationprofiles",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }
}
