import Foundation
import AppKit
import Combine
import CryptoKit
import Darwin

// MARK: - Saf yardımcılar (birim testli)

/// WireGuard / wgcf kurulumu için yan etkisiz yardımcılar.
///
/// Not: macOS'ta WireGuard uygulama bazlı bölünmüş tünel (split tunnel) DESTEKLEMEZ.
/// wgcf'nin ürettiği profil `AllowedIPs = 0.0.0.0/0, ::/0` içerir; yani TÜM trafik
/// (ve DNS) Cloudflare WARP üzerinden geçer.
enum WireGuardSupport {
    // MARK: Sabitler

    static let launchDaemonLabel = "com.splitwire.wireguard"
    static let launchDaemonPlistPath = "/Library/LaunchDaemons/com.splitwire.wireguard.plist"
    static let systemConfigDir = "/etc/wireguard"
    /// wg-quick arayüz adını dosya adından alır: `wgcf.conf` -> `wgcf`.
    static let systemConfigPath = "/etc/wireguard/wgcf.conf"
    static let daemonLogPath = "/var/log/splitwire-wireguard.log"
    static let wgQuickInterfaceName = "wgcf"

    static let installCommandHint = "brew install wireguard-tools"
    static let homebrewURL = URL(string: "https://brew.sh")!
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/ViRb3/wgcf/releases/latest")!

    /// wg-quick'in arandığı yerler (Apple Silicon ve Intel Homebrew).
    static let wgQuickCandidates = ["/opt/homebrew/bin/wg-quick", "/usr/local/bin/wg-quick"]
    static let brewCandidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    static func wgcfCandidates(home: String) -> [String] {
        ["/opt/homebrew/bin/wgcf", "/usr/local/bin/wgcf", (home as NSString).appendingPathComponent(".local/bin/wgcf")]
    }

    // MARK: CPU mimarisi

    enum CPUArch: String, Equatable, CaseIterable {
        case arm64
        case amd64

        /// wgcf sürüm dosyalarındaki ek: `wgcf_2.3.0_darwin_arm64`.
        var assetSuffix: String { "darwin_\(rawValue)" }

        /// Mach-O cputype değeri (CPU_TYPE_ARM64 / CPU_TYPE_X86_64).
        var machOCPUType: UInt32 {
            switch self {
            case .arm64: return 0x0100_000C
            case .amd64: return 0x0100_0007
            }
        }

        init?(machOCPUType: UInt32) {
            guard let arch = CPUArch.allCases.first(where: { $0.machOCPUType == machOCPUType }) else { return nil }
            self = arch
        }
    }

    /// Donanımın gerçek mimarisi. `hw.optional.arm64` Rosetta altında da 1 döner,
    /// bu yüzden uygulama x86_64 olarak çalışsa bile Apple Silicon doğru tespit edilir.
    static func hostArch() -> CPUArch {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0, value == 1 {
            return .arm64
        }
        return .amd64
    }

    // MARK: GitHub sürümü / indirme

    struct GitHubAsset: Decodable, Equatable {
        let name: String
        let browserDownloadURL: URL
        /// GitHub API'nin verdiği özet, ör. "sha256:852d…".
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case digest
        }

        var sha256: String? {
            guard let digest, digest.lowercased().hasPrefix("sha256:") else { return nil }
            let hex = String(digest.dropFirst("sha256:".count)).lowercased()
            return isHexSHA256(hex) ? hex : nil
        }
    }

    struct GitHubRelease: Decodable, Equatable {
        let tagName: String
        let assets: [GitHubAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
    }

    struct DownloadCandidate: Equatable {
        let url: URL
        /// Zorunlu: özeti bilinmeyen hiçbir dosya kabul edilmez.
        let sha256: String
        let label: String
    }

    /// İndirme sırası: önce SABİT (SHA-256'sı koda gömülü) v2.3.0; daha yeni bir "latest" yalnızca
    /// GitHub API bir sha256 özeti veriyorsa yedek olarak eklenir. "latest" sabit sürümle aynı
    /// dosyaysa her zaman gömülü özet kullanılır (özeti olmayan API yanıtı onu atlatamaz).
    static func downloadCandidates(latest: GitHubRelease?, arch: CPUArch) -> [DownloadCandidate] {
        let pinned = pinnedCandidate(for: arch)
        var result = [pinned]
        if let latest,
           let asset = selectAsset(from: latest.assets, arch: arch),
           asset.browserDownloadURL != pinned.url,
           let sha = asset.sha256 {
            result.append(DownloadCandidate(url: asset.browserDownloadURL, sha256: sha, label: latest.tagName))
        }
        return result
    }

    /// Doğrulanmış v2.3.0 dosyaları (varsayılan indirme).
    static let pinnedVersion = "2.3.0"
    static func pinnedCandidate(for arch: CPUArch) -> DownloadCandidate {
        let name = "wgcf_\(pinnedVersion)_\(arch.assetSuffix)"
        let sha: String
        switch arch {
        case .arm64: sha = "852d7fc7b74a5f9dca54c7cbd49068689aead71fe8f42f4af74eb9429cf87642"
        case .amd64: sha = "54aac2497c1fd6ef9a90d13d18b8e1f16f043ee4907d189d7dd5c9f32cf462f0"
        }
        return DownloadCandidate(
            url: URL(string: "https://github.com/ViRb3/wgcf/releases/download/v\(pinnedVersion)/\(name)")!,
            sha256: sha,
            label: L("v\(pinnedVersion) (sabit)", "v\(pinnedVersion) (pinned)")
        )
    }

    static func decodeRelease(_ data: Data) throws -> GitHubRelease {
        try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    /// İşlemciye uygun macOS dosyasını seçer (`…_darwin_arm64` / `…_darwin_amd64`).
    static func selectAsset(from assets: [GitHubAsset], arch: CPUArch) -> GitHubAsset? {
        assets.first { asset in
            let name = asset.name.lowercased()
            return name.hasPrefix("wgcf") && name.hasSuffix("_" + arch.assetSuffix)
        }
    }

    // MARK: Mach-O doğrulama

    /// Dosyanın başı bir Mach-O (tekil 64-bit veya fat/universal) ikilisi mi?
    /// v1.0.0'ın kaydettiği "Not Found" metni burada reddedilir.
    static func isMachO(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let magic = Array(data.prefix(4))
        let known: [[UInt8]] = [
            [0xCF, 0xFA, 0xED, 0xFE], // MH_MAGIC_64 (little-endian, diskteki hali)
            [0xFE, 0xED, 0xFA, 0xCF], // MH_MAGIC_64 (big-endian)
            [0xCA, 0xFE, 0xBA, 0xBE], // FAT_MAGIC
            [0xBE, 0xBA, 0xFE, 0xCA], // FAT_CIGAM
            [0xCA, 0xFE, 0xBA, 0xBF], // FAT_MAGIC_64
        ]
        return known.contains(magic)
    }

    /// Mach-O dosyasının içerdiği mimariler (tanınmayanlar atlanır).
    static func machOArchitectures(_ data: Data) -> Set<CPUArch> {
        let bytes = [UInt8](data.prefix(4096))
        guard bytes.count >= 8 else { return [] }

        func be32(_ offset: Int) -> UInt32? {
            guard offset + 4 <= bytes.count else { return nil }
            return bytes[offset..<offset + 4].reduce(0) { ($0 << 8) | UInt32($1) }
        }
        func le32(_ offset: Int) -> UInt32? {
            guard offset + 4 <= bytes.count else { return nil }
            return bytes[offset..<offset + 4].reversed().reduce(0) { ($0 << 8) | UInt32($1) }
        }

        switch Array(bytes.prefix(4)) {
        case [0xCF, 0xFA, 0xED, 0xFE]:
            return Set([le32(4).flatMap(CPUArch.init(machOCPUType:))].compactMap { $0 })
        case [0xFE, 0xED, 0xFA, 0xCF]:
            return Set([be32(4).flatMap(CPUArch.init(machOCPUType:))].compactMap { $0 })
        case [0xCA, 0xFE, 0xBA, 0xBE], [0xCA, 0xFE, 0xBA, 0xBF]:
            let entrySize = bytes[3] == 0xBF ? 32 : 20
            guard let count = be32(4), count > 0, count < 32 else { return [] }
            var result = Set<CPUArch>()
            for index in 0..<Int(count) {
                if let cpu = be32(8 + index * entrySize), let arch = CPUArch(machOCPUType: cpu) {
                    result.insert(arch)
                }
            }
            return result
        case [0xBE, 0xBA, 0xFE, 0xCA]:
            guard let count = le32(4), count > 0, count < 32 else { return [] }
            var result = Set<CPUArch>()
            for index in 0..<Int(count) {
                if let cpu = le32(8 + index * 20), let arch = CPUArch(machOCPUType: cpu) {
                    result.insert(arch)
                }
            }
            return result
        default:
            return []
        }
    }

    /// Normal dosya (sembolik bağlantıysa hedefi) + çalıştırılabilir + Mach-O + bu Mac'in mimarisini içeriyor.
    static func isUsableExecutable(atPath path: String, arch: CPUArch) -> Bool {
        let fm = FileManager.default
        let resolved = (path as NSString).resolvingSymlinksInPath
        guard let type = try? fm.attributesOfItem(atPath: resolved)[.type] as? FileAttributeType,
              type == .typeRegular,
              fm.isExecutableFile(atPath: resolved),
              let handle = FileHandle(forReadingAtPath: resolved) else {
            return false
        }
        defer { try? handle.close() }
        let header = handle.readData(ofLength: 4096)
        return isMachO(header) && machOArchitectures(header).contains(arch)
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func isHexSHA256(_ s: String) -> Bool {
        s.count == 64 && s.allSatisfy { $0.isHexDigit }
    }

    // MARK: Profil / durum ayrıştırma

    /// `[Interface]` bölümündeki `Address = 172.16.0.2/32, 2606:…/128` satırlarından adresler (önek olmadan).
    static func parseInterfaceAddresses(config: String) -> [String] {
        var inInterface = false
        var result: [String] = []
        for rawLine in config.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inInterface = line.lowercased() == "[interface]"
                continue
            }
            guard inInterface, let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            guard key == "address" else { continue }
            let value = line[line.index(after: eq)...]
            for part in value.split(separator: ",") {
                let address = part.trimmingCharacters(in: .whitespaces)
                    .split(separator: "/", maxSplits: 1).first.map(String.init) ?? ""
                if !address.isEmpty { result.append(address) }
            }
        }
        return result
    }

    /// IP adresini kanonik biçime getirir (IPv6 sıfır sıkıştırma farklarını yok eder).
    static func normalizeIP(_ address: String) -> String {
        let bare = address.split(separator: "%", maxSplits: 1).first.map(String.init) ?? address
        var v4 = in_addr()
        if inet_pton(AF_INET, bare, &v4) == 1 {
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            if inet_ntop(AF_INET, &v4, &buffer, socklen_t(buffer.count)) != nil {
                return String(cString: buffer)
            }
        }
        var v6 = in6_addr()
        if inet_pton(AF_INET6, bare, &v6) == 1 {
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            if inet_ntop(AF_INET6, &v6, &buffer, socklen_t(buffer.count)) != nil {
                return String(cString: buffer)
            }
        }
        return bare.lowercased()
    }

    /// Tüm WARP istemcilerinin (wgcf ve resmî Cloudflare WARP uygulaması) kullandığı ortak IPv4.
    static let sharedWarpIPv4 = "172.16.0.2"

    /// `ifconfig` çıktısında tünel adreslerinden birini taşıyan utun arayüzünün adı.
    /// Profilde hesaba özgü bir adres (wgcf'de IPv6 2606:4700:110:…) varsa ortak 172.16.0.2
    /// yok sayılır; yoksa resmî WARP uygulamasının tüneli "Bağlı" görünürdü.
    static func tunnelInterface(ifconfigOutput: String, addresses: [String]) -> String? {
        let all = addresses.map(normalizeIP)
        let specific = all.filter { $0 != sharedWarpIPv4 }
        let wanted = Set(specific.isEmpty ? all : specific)
        guard !wanted.isEmpty else { return nil }
        var current: String?
        for line in ifconfigOutput.components(separatedBy: .newlines) {
            guard !line.isEmpty else { continue }
            if let first = line.first, !first.isWhitespace {
                // "utun5: flags=8051<UP,...> mtu 1280"
                current = line.split(separator: ":", maxSplits: 1).first.map(String.init)
                continue
            }
            guard let iface = current, iface.hasPrefix("utun") else { continue }
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard tokens.count >= 2, tokens[0] == "inet" || tokens[0] == "inet6" else { continue }
            if wanted.contains(normalizeIP(String(tokens[1]))) {
                return iface
            }
        }
        return nil
    }

    // MARK: Uç nokta (Endpoint)

    /// `[Peer]` bölümündeki `Endpoint = host:port` değeri (IPv6 köşeli parantezsiz döner).
    static func parseEndpoint(config: String) -> (host: String, port: String)? {
        var inPeer = false
        for rawLine in config.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inPeer = line.lowercased() == "[peer]"
                continue
            }
            guard inPeer, let eq = line.firstIndex(of: "=") else { continue }
            guard line[..<eq].trimmingCharacters(in: .whitespaces).lowercased() == "endpoint" else { continue }
            return splitHostPort(line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    static func splitHostPort(_ value: String) -> (host: String, port: String)? {
        if value.hasPrefix("["), let close = value.firstIndex(of: "]") {
            let host = String(value[value.index(after: value.startIndex)..<close])
            let rest = value[value.index(after: close)...]
            guard rest.hasPrefix(":"), !host.isEmpty else { return nil }
            let port = String(rest.dropFirst())
            return port.isEmpty ? nil : (host, port)
        }
        guard let colon = value.lastIndex(of: ":") else { return nil }
        let host = String(value[..<colon]), port = String(value[value.index(after: colon)...])
        guard !host.isEmpty, !port.isEmpty, !host.contains(":") else { return nil }
        return (host, port)
    }

    static func isIPLiteral(_ host: String) -> Bool {
        var v4 = in_addr(), v6 = in6_addr()
        return inet_pton(AF_INET, host, &v4) == 1 || inet_pton(AF_INET6, host, &v6) == 1
    }

    /// `[Peer]` içindeki ana makine adlı `Endpoint`'i verilen IP ile değiştirir
    /// (`engage.cloudflareclient.com:2408` -> `162.159.192.1:2408`; IPv6 köşeli parantezle).
    /// Açılışta ağ henüz hazır değilken `wg` ad çözümlemesini kalıcı hata sayıp tüneli kurmaz;
    /// IP ile DNS gerekmez. Uç nokta zaten IP ise veya `ip` geçerli bir IP değilse değişmez.
    static func pinEndpoint(config: String, ip: String) -> String {
        guard isIPLiteral(ip) else { return config }
        let formattedIP = ip.contains(":") ? "[\(ip)]" : ip
        var inPeer = false
        let lines = config.components(separatedBy: "\n").map { rawLine -> String in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inPeer = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "[peer]"
                return rawLine
            }
            guard inPeer, let eq = line.firstIndex(of: "=") else { return rawLine }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard key.lowercased() == "endpoint",
                  let endpoint = splitHostPort(line[line.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)),
                  !isIPLiteral(endpoint.host) else { return rawLine }
            let lineEnding = rawLine.hasSuffix("\r") ? "\r" : ""
            return "\(key) = \(formattedIP):\(endpoint.port)\(lineEnding)"
        }
        return lines.joined(separator: "\n")
    }

    // MARK: LaunchDaemon ve yetkili komutlar

    /// wg-quick'in yolundan Homebrew önekini çıkarır: `/opt/homebrew/bin/wg-quick` -> `/opt/homebrew`.
    static func brewPrefix(forWgQuick wgQuickPath: String) -> String {
        let binDir = (wgQuickPath as NSString).deletingLastPathComponent
        return (binDir as NSString).deletingLastPathComponent
    }

    /// wg-quick'in `#!/usr/bin/env bash` satırının Homebrew bash 4+'ı, wireguard-go ve wg'yi
    /// bulabilmesi için gereken PATH (root/launchd ortamında PATH minimaldir).
    static func toolPATH(forWgQuick wgQuickPath: String) -> String {
        let binDir = (wgQuickPath as NSString).deletingLastPathComponent
        return "\(binDir):/usr/bin:/bin:/usr/sbin:/sbin"
    }

    /// wg-quick'in çalışması için aynı Homebrew önekinde bulunması gereken araçlar.
    static func requiredCompanionTools(forWgQuick wgQuickPath: String) -> [String] {
        let binDir = (wgQuickPath as NSString).deletingLastPathComponent
        return ["bash", "wg", "wireguard-go"].map { (binDir as NSString).appendingPathComponent($0) }
    }

    static func launchDaemonPlist(wgQuickPath: String, configPath: String = systemConfigPath) throws -> Data {
        let plist: [String: Any] = [
            "Label": launchDaemonLabel,
            "ProgramArguments": [wgQuickPath, "up", configPath],
            "EnvironmentVariables": ["PATH": toolPATH(forWgQuick: wgQuickPath)],
            "RunAtLoad": true,
            "StandardOutPath": daemonLogPath,
            "StandardErrorPath": daemonLogPath,
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    private static func wgQuickInvocation(_ wgQuickPath: String, _ action: String) -> String {
        "/usr/bin/env PATH=\(Shell.shellQuote(toolPATH(forWgQuick: wgQuickPath))) \(Shell.shellQuote(wgQuickPath)) \(action) \(Shell.shellQuote(systemConfigPath))"
    }

    /// `wg-quick up`; arayüz zaten açıksa ("already exists") başarı sayılır.
    /// Hata olursa wg-quick çıktısı stderr'e yazılır (osascript hata mesajına düşer).
    static func upCommand(wgQuickPath: String) -> String {
        "out=$(\(wgQuickInvocation(wgQuickPath, "up")) 2>&1); rc=$?; "
            + "if [ $rc -ne 0 ]; then case \"$out\" in *'already exists'*) ;; *) printf '%s\\n' \"$out\" >&2; exit $rc;; esac; fi"
    }

    /// `wg-quick down`; arayüz zaten kapalıysa başarı sayılır.
    static func downCommand(wgQuickPath: String) -> String {
        "out=$(\(wgQuickInvocation(wgQuickPath, "down")) 2>&1); rc=$?; "
            + "if [ $rc -ne 0 ]; then case \"$out\" in *'is not a WireGuard interface'*) ;; *) printf '%s\\n' \"$out\" >&2; exit $rc;; esac; fi"
    }

    /// Eski tünelin arka plan izleyicisinin (wg-quick'in rota/DNS geri yükleme tuzağı) bitmesini
    /// en çok 10 sn bekler. Aksi hâlde eski izleyici yeni tünelin rotalarını/DNS'ini silebilir
    /// ya da yeni tünel eski WARP DNS'ini "orijinal" diye kaydeder.
    static func waitForOldTunnelCommand() -> String {
        // "." regex'te "[.]" yazılır: böylece bu betiğin kendi komut satırı desenle eşleşmez
        let pattern = "wg-quick up " + systemConfigPath.replacingOccurrences(of: ".", with: "[.]")
        return "i=0; while /usr/bin/pgrep -qf \(Shell.shellQuote(pattern)) && [ $i -lt 100 ]; do /bin/sleep 0.1; i=$((i+1)); done"
    }

    /// Tek parola penceresinde: yapılandırmayı kurar, tüneli (yeniden) açar.
    /// - Parameter sourcePlistPath: Verilirse açılışta başlatma LaunchDaemon'ı kurulur (isteğe bağlı;
    ///   Homebrew'un kullanıcı tarafından yazılabilir wg-quick/bash/wg/wireguard-go'sunu her açılışta
    ///   parola sormadan root olarak çalıştırır). nil ise varsa eski daemon kaldırılır.
    static func installCommand(wgQuickPath: String, sourceConfigPath: String, sourcePlistPath: String?) -> String {
        let plist = Shell.shellQuote(launchDaemonPlistPath)
        var steps = [
            "/bin/mkdir -p \(Shell.shellQuote(systemConfigDir))",
            "/usr/sbin/chown root:wheel \(Shell.shellQuote(systemConfigDir))",
            "/bin/chmod 700 \(Shell.shellQuote(systemConfigDir))",
            "/usr/bin/install -m 600 -o root -g wheel \(Shell.shellQuote(sourceConfigPath)) \(Shell.shellQuote(systemConfigPath))",
        ]
        if let sourcePlistPath {
            steps.append("/usr/bin/install -m 644 -o root -g wheel \(Shell.shellQuote(sourcePlistPath)) \(plist)")
        }
        var command = "\(steps.joined(separator: " && ")) || exit 1; "
            + "/bin/launchctl bootout system/\(launchDaemonLabel) >/dev/null 2>&1; "
        if sourcePlistPath == nil {
            command += "/bin/rm -f \(plist); "
        }
        // Eski bir tünel açıksa yeni yapılandırmayla yeniden açılsın
        command += "\(wgQuickInvocation(wgQuickPath, "down")) >/dev/null 2>&1; "
            + "\(waitForOldTunnelCommand()); "
            + upCommand(wgQuickPath: wgQuickPath)
        if sourcePlistPath != nil {
            // Daemon zaten açık tünel için "already exists" ile çıkar; açılışta tüneli kurar.
            command += "; /bin/launchctl bootstrap system \(plist) >/dev/null 2>&1 || { /bin/sleep 1; /bin/launchctl bootstrap system \(plist) >/dev/null 2>&1; } || true"
        }
        return command
    }

    /// Tek parola penceresinde: tüneli kapatır, daemon'ı boşaltır, sistem dosyalarını siler.
    /// wg-quick yoksa (araçlar kaldırılmışsa) wireguard-go'nun soketini silerek tüneli kapatır.
    static func uninstallCommand(wgQuickPath: String?) -> String {
        var parts: [String] = []
        if let wgQuickPath {
            parts.append("\(wgQuickInvocation(wgQuickPath, "down")) >/dev/null 2>&1")
        }
        parts.append("/bin/launchctl bootout system/\(launchDaemonLabel) >/dev/null 2>&1")
        let nameFile = "/var/run/wireguard/\(wgQuickInterfaceName).name"
        parts.append("if [ -f \(nameFile) ]; then n=$(/bin/cat \(nameFile)); [ -n \"$n\" ] && /bin/rm -f \"/var/run/wireguard/$n.sock\"; /bin/rm -f \(nameFile); fi")
        parts.append("/bin/rm -f \(Shell.shellQuote(launchDaemonPlistPath)) \(Shell.shellQuote(systemConfigPath))")
        parts.append("/bin/rmdir \(Shell.shellQuote(systemConfigDir)) >/dev/null 2>&1")
        parts.append("true")
        return parts.joined(separator: "; ")
    }

    // MARK: Hata metni

    /// Kullanıcıya gösterilecek komut çıktısını kısaltır. Hata genelde sonda olduğu için SONU korunur.
    static func trimmedOutput(_ output: String, limit: Int = 700) -> String {
        let text = output
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > limit else { return text }
        return "…" + String(text.suffix(limit))
    }
}

// MARK: - Hatalar

enum WireGuardError: LocalizedError {
    case prerequisitesMissing([String])
    case downloadFailed(String)
    case commandFailed(step: String, output: String)
    case profileInvalid(String)

    var errorDescription: String? {
        switch self {
        case .prerequisitesMissing(let tools):
            let list = tools.joined(separator: ", ")
            let hint = WireGuardSupport.installCommandHint
            return L("Gerekli WireGuard araçları bulunamadı: \(list). Terminal'de şunu çalıştırın: \(hint)",
                     "Required WireGuard tools not found: \(list). Run this in Terminal: \(hint)")
        case .downloadFailed(let message):
            return L("wgcf indirilemedi: \(message)", "Could not download wgcf: \(message)")
        case .commandFailed(let step, let output):
            let trimmed = WireGuardSupport.trimmedOutput(output)
            return trimmed.isEmpty
                ? L("\(step) başarısız oldu.", "\(step) failed.")
                : L("\(step) başarısız oldu:\n\(trimmed)", "\(step) failed:\n\(trimmed)")
        case .profileInvalid(let message):
            return L("WireGuard profili geçersiz: \(message)", "Invalid WireGuard profile: \(message)")
        }
    }
}

enum WireGuardStatusKind: Equatable {
    case info, success, warning, error
}

enum WireGuardConnectionState: Equatable {
    case notConfigured
    case configured
    case connected(interface: String)

    var title: String {
        switch self {
        case .notConfigured: return L("Yapılandırılmadı", "Not configured")
        case .configured: return L("Yapılandırıldı (bağlı değil)", "Configured (not connected)")
        case .connected: return L("Bağlı", "Connected")
        }
    }
}

// MARK: - Servis

@MainActor
final class WireGuardService: ObservableObject {
    @Published private(set) var isProcessing = false
    /// Son durum mesajı; iki dilde saklanır, okunurken geçerli dile çözülür (#8).
    @Published private(set) var status: LocalizedText?
    @Published private(set) var statusKind: WireGuardStatusKind = .info

    var statusMessage: String { status?.resolved ?? "" }

    @Published private(set) var connectionState: WireGuardConnectionState = .notConfigured
    /// Bulunan wg-quick (nil = Homebrew wireguard-tools kurulu değil).
    @Published private(set) var wgQuickPath: String?
    /// wg-quick'in yanında eksik olan araçlar (bash 4+, wg, wireguard-go).
    @Published private(set) var missingCompanionTools: [String] = []
    /// Kullanılabilir wgcf (nil = kurulum sırasında indirilecek).
    @Published private(set) var wgcfPath: String?
    /// ~/.local/bin/wgcf var ama geçersiz (ör. v1.0.0'ın kaydettiği "Not Found").
    @Published private(set) var hasInvalidWgcf = false
    @Published private(set) var brewPath: String?
    @Published private(set) var isLaunchDaemonInstalled = false
    @Published private(set) var hasAccount = false

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }

    var isConfigured: Bool { connectionState != .notConfigured }

    var prerequisitesMet: Bool { wgQuickPath != nil && missingCompanionTools.isEmpty }

    private let home: String
    private let configDir: URL
    private let localBinDir: URL
    private var accountURL: URL { configDir.appendingPathComponent("wgcf-account.toml") }
    private var profileURL: URL { configDir.appendingPathComponent("wgcf-profile.conf") }
    private var userConfigURL: URL { configDir.appendingPathComponent("wgcf.conf") }
    private let arch = WireGuardSupport.hostArch()

    init() {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        home = homeURL.path
        configDir = homeURL.appendingPathComponent(".config/wireguard")
        localBinDir = homeURL.appendingPathComponent(".local/bin")
    }

    // MARK: Durum

    func refreshStatus() async {
        let fm = FileManager.default

        wgQuickPath = WireGuardSupport.wgQuickCandidates.first { fm.isExecutableFile(atPath: $0) }
        if let wgQuickPath {
            missingCompanionTools = WireGuardSupport.requiredCompanionTools(forWgQuick: wgQuickPath)
                .filter { !fm.isExecutableFile(atPath: $0) }
                .map { ($0 as NSString).lastPathComponent }
        } else {
            missingCompanionTools = []
        }
        brewPath = WireGuardSupport.brewCandidates.first { fm.isExecutableFile(atPath: $0) }

        wgcfPath = WireGuardSupport.wgcfCandidates(home: home)
            .first { WireGuardSupport.isUsableExecutable(atPath: $0, arch: arch) }
        let localWgcf = localBinDir.appendingPathComponent("wgcf").path
        hasInvalidWgcf = wgcfPath == nil && fm.fileExists(atPath: localWgcf)

        hasAccount = fm.fileExists(atPath: accountURL.path)
        isLaunchDaemonInstalled = fm.fileExists(atPath: WireGuardSupport.launchDaemonPlistPath)
        let hasUserConfig = fm.fileExists(atPath: userConfigURL.path)

        var addresses: [String] = []
        for url in [userConfigURL, profileURL] {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                addresses = WireGuardSupport.parseInterfaceAddresses(config: text)
                if !addresses.isEmpty { break }
            }
        }

        var interface: String?
        if !addresses.isEmpty, let result = try? await Shell.run("/sbin/ifconfig", [], timeout: 10) {
            interface = WireGuardSupport.tunnelInterface(ifconfigOutput: result.stdout, addresses: addresses)
        }

        if let interface {
            connectionState = .connected(interface: interface)
        } else if isLaunchDaemonInstalled || hasUserConfig {
            connectionState = .configured
        } else {
            connectionState = .notConfigured
        }
    }

    // MARK: Kurulum

    /// - Parameter startAtBoot: Açılışta otomatik bağlanma LaunchDaemon'ı kurulsun mu (varsayılan kapalı).
    func install(startAtBoot: Bool = false) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        await refreshStatus()
        guard let wgQuick = wgQuickPath, missingCompanionTools.isEmpty else {
            let missing = wgQuickPath == nil ? ["wg-quick"] : missingCompanionTools
            let list = missing.joined(separator: ", ")
            let hint = WireGuardSupport.installCommandHint
            setStatus(LT("WireGuard araçları eksik: \(list). Önce \(hint) çalıştırın.",
                        "WireGuard tools are missing: \(list). Run \(hint) first."), .warning)
            showPrerequisiteAlert(missing: missing)
            return
        }

        var tempDir: URL?
        defer {
            if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        }

        do {
            setStatus(LT("wgcf hazırlanıyor...", "Preparing wgcf..."), .info)
            let wgcf = try await ensureWgcf()

            try createPrivateDirectory(configDir)

            setStatus(LT("Cloudflare WARP profili oluşturuluyor...", "Creating the Cloudflare WARP profile..."), .info)
            guard try await createProfile(wgcf: wgcf) else {
                setStatus(LT("Kurulum iptal edildi.", "Setup cancelled."), .info)
                return
            }

            let profile = try String(contentsOf: profileURL, encoding: .utf8)
            guard profile.contains("[Interface]"), profile.contains("[Peer]"),
                  !WireGuardSupport.parseInterfaceAddresses(config: profile).isEmpty else {
                throw WireGuardError.profileInvalid(L("wgcf-profile.conf beklenen [Interface]/[Peer]/Address alanlarını içermiyor.",
                                                     "wgcf-profile.conf is missing the expected [Interface]/[Peer]/Address fields."))
            }
            // Uç noktayı IP'ye sabitle: açılışta (ağ hazır değilken) ad çözümlemesi gerekmesin.
            // DoH ile çözülür (ISS DNS'i zehirli olabilir); çözülemezse ana makine adı kalır.
            var config = profile
            if let endpoint = WireGuardSupport.parseEndpoint(config: profile),
               !WireGuardSupport.isIPLiteral(endpoint.host) {
                setStatus(LT("WARP sunucu adresi çözülüyor...", "Resolving the WARP server address..."), .info)
                if let ip = await DNSHealthChecker.resolveDoH(endpoint.host)?
                    .first(where: DNSHealthEvaluator.isIPv4) {
                    config = WireGuardSupport.pinEndpoint(config: profile, ip: ip)
                }
            }
            try writePrivateFile(Data(config.utf8), to: userConfigURL)

            var plistPath: String?
            if startAtBoot {
                // LaunchDaemon plist'ini kullanıcıya özel, tahmin edilemeyen bir geçici klasöre yaz
                let dir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("splitwire-wg-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false,
                                                        attributes: [.posixPermissions: 0o700])
                tempDir = dir
                let plistURL = dir.appendingPathComponent("\(WireGuardSupport.launchDaemonLabel).plist")
                try WireGuardSupport.launchDaemonPlist(wgQuickPath: wgQuick).write(to: plistURL, options: .atomic)
                plistPath = plistURL.path
            }

            setStatus(LT("Yönetici izni bekleniyor (tünel kuruluyor)...",
                        "Waiting for administrator permission (setting up the tunnel)..."), .info)
            let command = WireGuardSupport.installCommand(
                wgQuickPath: wgQuick,
                sourceConfigPath: userConfigURL.path,
                sourcePlistPath: plistPath
            )
            try await Shell.runPrivileged(command, prompt: Self.privilegedPrompt, timeout: 300)

            await refreshAfterAction()
            if isConnected {
                setStatus(startAtBoot
                          ? LT("Kurulum tamamlandı. Tüm trafik Cloudflare WARP üzerinden geçiyor; açılışta otomatik bağlanır.",
                               "Setup complete. All traffic now goes through Cloudflare WARP; it connects automatically at startup.")
                          : LT("Kurulum tamamlandı. Tüm trafik Cloudflare WARP üzerinden geçiyor. Bilgisayar yeniden başlatıldıktan sonra 'Bağlan'a basın.",
                               "Setup complete. All traffic now goes through Cloudflare WARP. After restarting the computer, press 'Connect'."), .success)
            } else {
                setStatus(LT("Kurulum tamamlandı ancak tünel arayüzü henüz görünmüyor. Birkaç saniye sonra durumu yenileyin veya 'Bağlan'a basın.",
                            "Setup complete, but the tunnel interface is not visible yet. Refresh the status in a few seconds or press 'Connect'."), .warning)
            }
        } catch ShellError.userCancelled {
            setStatus(LT("Yönetici izni verilmedi; sistemde hiçbir değişiklik yapılmadı.",
                        "Administrator permission was not granted; nothing was changed on the system."), .info)
        } catch {
            fail(LT("Kurulum başarısız", "Setup failed"), error)
        }
        await refreshStatus()
    }

    // MARK: Bağlan / Bağlantıyı kes

    func connect() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        await refreshStatus()
        guard let wgQuick = wgQuickPath, missingCompanionTools.isEmpty else {
            showPrerequisiteAlert(missing: wgQuickPath == nil ? ["wg-quick"] : missingCompanionTools)
            return
        }
        do {
            setStatus(LT("Yönetici izni bekleniyor (bağlanılıyor)...",
                        "Waiting for administrator permission (connecting)..."), .info)
            try await Shell.runPrivileged(WireGuardSupport.upCommand(wgQuickPath: wgQuick),
                                          prompt: Self.privilegedPrompt, timeout: 180)
            await refreshAfterAction()
            if isConnected {
                setStatus(LT("Cloudflare WARP'a bağlandı.", "Connected to Cloudflare WARP."), .success)
            } else {
                setStatus(LT("Komut başarılı ama tünel arayüzü görünmüyor. Durumu birazdan yenileyin.",
                            "The command succeeded, but the tunnel interface is not visible. Refresh the status shortly."), .warning)
            }
        } catch ShellError.userCancelled {
            setStatus(LT("Bağlantı iptal edildi.", "Connection cancelled."), .info)
        } catch {
            fail(LT("Bağlantı başarısız", "Connection failed"), error)
        }
    }

    func disconnect() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        await refreshStatus()
        guard let wgQuick = wgQuickPath else {
            showPrerequisiteAlert(missing: ["wg-quick"])
            return
        }
        do {
            setStatus(LT("Yönetici izni bekleniyor (bağlantı kesiliyor)...",
                        "Waiting for administrator permission (disconnecting)..."), .info)
            try await Shell.runPrivileged(WireGuardSupport.downCommand(wgQuickPath: wgQuick),
                                          prompt: Self.privilegedPrompt, timeout: 180)
            await refreshStatus()
            setStatus(isLaunchDaemonInstalled
                      ? LT("Bağlantı kesildi. Bilgisayar yeniden başlatıldığında otomatik olarak tekrar bağlanır.",
                           "Disconnected. It will reconnect automatically when the computer restarts.")
                      : LT("Bağlantı kesildi.", "Disconnected."), .success)
        } catch ShellError.userCancelled {
            setStatus(LT("İşlem iptal edildi; bağlantı değişmedi.", "Cancelled; the connection was not changed."), .info)
        } catch {
            fail(LT("Bağlantı kesilemedi", "Could not disconnect"), error)
        }
    }

    // MARK: Kaldırma

    /// Onay sorar, ardından tek parola penceresinde sistem tarafını kaldırır.
    func uninstall() async {
        guard !isProcessing else { return }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("WireGuard kaldırılsın mı?", "Uninstall WireGuard?")
        alert.informativeText = L("Tünel kapatılır, açılışta otomatik başlatma kaldırılır ve WireGuard yapılandırması silinir.",
                                  "The tunnel will be closed, start at boot will be removed and the WireGuard configuration will be deleted.")
        alert.alertStyle = .warning
        let checkbox = NSButton(checkboxWithTitle: L("Cloudflare hesabını da sil (wgcf-account.toml)",
                                                     "Also delete the Cloudflare account (wgcf-account.toml)"),
                                   target: nil, action: nil)
        checkbox.state = .off
        alert.accessoryView = checkbox
        alert.addButton(withTitle: L("Kaldır", "Uninstall"))
        alert.addButton(withTitle: L("İptal", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let deleteAccount = checkbox.state == .on

        isProcessing = true
        defer { isProcessing = false }
        await refreshStatus()

        do {
            setStatus(LT("Yönetici izni bekleniyor (kaldırılıyor)...",
                        "Waiting for administrator permission (uninstalling)..."), .info)
            try await Shell.runPrivileged(WireGuardSupport.uninstallCommand(wgQuickPath: wgQuickPath),
                                          prompt: Self.privilegedPrompt, timeout: 180)

            let fm = FileManager.default
            try? fm.removeItem(at: userConfigURL)
            try? fm.removeItem(at: profileURL)
            if deleteAccount {
                try? fm.removeItem(at: accountURL)
            }
            await refreshStatus()
            setStatus(deleteAccount
                      ? LT("WireGuard ve Cloudflare hesap dosyası kaldırıldı.",
                           "WireGuard and the Cloudflare account file were removed.")
                      : LT("WireGuard kaldırıldı. Cloudflare hesabı (wgcf-account.toml) yeniden kurulum için saklandı.",
                          "WireGuard was removed. The Cloudflare account (wgcf-account.toml) was kept for reinstalling."), .success)
        } catch ShellError.userCancelled {
            setStatus(LT("Kaldırma iptal edildi; hiçbir şey değiştirilmedi.", "Uninstall cancelled; nothing was changed."), .info)
        } catch {
            fail(LT("Kaldırma başarısız", "Uninstall failed"), error)
        }
    }

    // MARK: Önkoşul yardımı

    func copyInstallCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(WireGuardSupport.installCommandHint, forType: .string)
        let hint = WireGuardSupport.installCommandHint
        setStatus(LT("Komut panoya kopyalandı: \(hint)", "Command copied to clipboard: \(hint)"), .info)
    }

    func openHomebrewSite() {
        NSWorkspace.shared.open(WireGuardSupport.homebrewURL)
    }

    private func showPrerequisiteAlert(missing: [String]) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("WireGuard araçları gerekli", "WireGuard tools required")
        let list = missing.joined(separator: ", ")
        let hint = WireGuardSupport.installCommandHint
        var text = L("Bu özellik Homebrew'un wireguard-tools paketini kullanır (wg-quick, wg, wireguard-go ve bash 4+). "
                        + "Eksik: \(list).\n\n"
                        + "Terminal'de şu komutu çalıştırın, ardından tekrar deneyin:\n\(hint)",
                     "This feature uses Homebrew's wireguard-tools package (wg-quick, wg, wireguard-go and bash 4+). "
                        + "Missing: \(list).\n\n"
                        + "Run this command in Terminal, then try again:\n\(hint)")
        if brewPath == nil {
            text += L("\n\nHomebrew kurulu görünmüyor. Önce brew.sh adresindeki talimatlarla Homebrew'u kurun.",
                      "\n\nHomebrew doesn't appear to be installed. Install Homebrew first by following the instructions at brew.sh.")
        }
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("Komutu Kopyala", "Copy command"))
        if brewPath == nil {
            alert.addButton(withTitle: L("brew.sh'i Aç", "Open brew.sh"))
        }
        alert.addButton(withTitle: L("Kapat", "Close"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            copyInstallCommand()
        } else if brewPath == nil, response == .alertSecondButtonReturn {
            openHomebrewSite()
        }
    }

    // MARK: wgcf

    /// Geçerli bir wgcf bulur; yoksa (veya v1.0.0'dan kalma "Not Found" dosyası varsa) indirir.
    private func ensureWgcf() async throws -> String {
        if let existing = WireGuardSupport.wgcfCandidates(home: home)
            .first(where: { WireGuardSupport.isUsableExecutable(atPath: $0, arch: arch) }) {
            return existing
        }
        setStatus(LT("wgcf indiriliyor...", "Downloading wgcf..."), .info)
        return try await downloadWgcf()
    }

    /// Önce SHA-256'sı koda gömülü sabit sürüm; o başarısız olursa yalnızca GitHub'ın sha256
    /// özetini verdiği daha yeni bir sürüm denenir (özeti olmayan dosya asla kabul edilmez).
    private func downloadWgcf() async throws -> String {
        var errors: [String] = []
        let pinned = WireGuardSupport.pinnedCandidate(for: arch)
        do {
            return try await installWgcf(try await fetchBinary(pinned))
        } catch {
            errors.append("\(pinned.label): \(error.localizedDescription)")
        }

        var latest: WireGuardSupport.GitHubRelease?
        do {
            latest = try await fetchLatestRelease()
        } catch {
            errors.append("GitHub API: \(error.localizedDescription)")
        }
        for candidate in WireGuardSupport.downloadCandidates(latest: latest, arch: arch).dropFirst() {
            do {
                return try await installWgcf(try await fetchBinary(candidate))
            } catch {
                errors.append("\(candidate.label): \(error.localizedDescription)")
            }
        }
        throw WireGuardError.downloadFailed(errors.joined(separator: "\n"))
    }

    private func fetchLatestRelease() async throws -> WireGuardSupport.GitHubRelease {
        var request = URLRequest(url: WireGuardSupport.latestReleaseAPI, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SplitWire-Turkey-macOS", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw WireGuardError.downloadFailed(L("GitHub API yanıtı: HTTP \(status)", "GitHub API response: HTTP \(status)"))
        }
        return try WireGuardSupport.decodeRelease(data)
    }

    private func fetchBinary(_ candidate: WireGuardSupport.DownloadCandidate) async throws -> Data {
        var request = URLRequest(url: candidate.url, timeoutInterval: 120)
        request.setValue("SplitWire-Turkey-macOS", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            throw WireGuardError.downloadFailed("HTTP \(status) (\(candidate.url.lastPathComponent))")
        }
        guard WireGuardSupport.isMachO(data) else {
            throw WireGuardError.downloadFailed(L("İndirilen dosya bir macOS programı değil (\(data.count) bayt).",
                                                  "The downloaded file is not a macOS program (\(data.count) bytes)."))
        }
        guard WireGuardSupport.machOArchitectures(data).contains(arch) else {
            throw WireGuardError.downloadFailed(L("İndirilen dosya bu Mac'in işlemcisine (\(arch.rawValue)) uygun değil.",
                                                  "The downloaded file does not match this Mac's processor (\(arch.rawValue))."))
        }
        let expected = candidate.sha256.lowercased()
        let actual = WireGuardSupport.sha256Hex(data)
        guard WireGuardSupport.isHexSHA256(expected), actual == expected else {
            let want = expected.prefix(12), got = actual.prefix(12)
            throw WireGuardError.downloadFailed(L("SHA-256 doğrulaması başarısız (beklenen \(want)…, gelen \(got)…).",
                                                  "SHA-256 verification failed (expected \(want)…, got \(got)…)."))
        }
        return data
    }

    /// ~/.local/bin/wgcf'ye atomik olarak (geçici dosya + rename) 0755 kurar.
    private func installWgcf(_ data: Data) async throws -> String {
        let fm = FileManager.default
        try fm.createDirectory(at: localBinDir, withIntermediateDirectories: true)
        let destination = localBinDir.appendingPathComponent("wgcf")
        let staging = localBinDir.appendingPathComponent(".wgcf-\(UUID().uuidString).tmp")
        do {
            try data.write(to: staging, options: .withoutOverwriting)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staging.path)
            guard rename(staging.path, destination.path) == 0 else {
                let reason = String(cString: strerror(errno))
                throw WireGuardError.downloadFailed(L("wgcf kurulamadı: \(reason)", "Could not install wgcf: \(reason)"))
            }
        } catch {
            try? fm.removeItem(at: staging)
            throw error
        }
        // Karantina işaretini kaldır (yoksa hata yok sayılır)
        _ = try? await Shell.run("/usr/bin/xattr", ["-d", "com.apple.quarantine", destination.path], timeout: 10)
        return destination.path
    }

    /// wgcf-account.toml yoksa kaydolur, ardından profili üretir.
    /// Mevcut hesapla üretim başarısız olursa kullanıcıya yeni hesap önerir.
    /// - Returns: Kullanıcı iptal ettiyse false.
    private func createProfile(wgcf: String) async throws -> Bool {
        let accountExisted = FileManager.default.fileExists(atPath: accountURL.path)
        if !accountExisted {
            try await registerAccount(wgcf: wgcf)
        }
        do {
            try await generateProfile(wgcf: wgcf)
            return true
        } catch {
            guard accountExisted else { throw error }
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = L("Profil oluşturulamadı", "Could not create profile")
            let reason = error.localizedDescription
            alert.informativeText = L("Mevcut Cloudflare WARP hesabıyla profil oluşturulamadı:\n\n"
                                        + "\(reason)\n\n"
                                        + "Hesap geçersiz olabilir. Yeni bir hesap oluşturulsun mu? (Eski hesap dosyası yedeklenir.)",
                                      "Could not create a profile with the existing Cloudflare WARP account:\n\n"
                                        + "\(reason)\n\n"
                                        + "The account may be invalid. Create a new account? (The old account file will be backed up.)")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("Yeni Hesap Oluştur", "Create new account"))
            alert.addButton(withTitle: L("İptal", "Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return false }

            let backup = configDir.appendingPathComponent("wgcf-account.toml.bak-\(Int(Date().timeIntervalSince1970))")
            try FileManager.default.moveItem(at: accountURL, to: backup)
            setStatus(LT("Yeni Cloudflare WARP hesabı oluşturuluyor...", "Creating a new Cloudflare WARP account..."), .info)
            try await registerAccount(wgcf: wgcf)
            try await generateProfile(wgcf: wgcf)
            return true
        }
    }

    private func registerAccount(wgcf: String) async throws {
        let result = try await Shell.run(
            wgcf, ["register", "--accept-tos", "--config", accountURL.path],
            timeout: 90
        )
        guard result.succeeded, FileManager.default.fileExists(atPath: accountURL.path) else {
            throw WireGuardError.commandFailed(step: "wgcf register", output: result.combinedOutput)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: accountURL.path)
    }

    private func generateProfile(wgcf: String) async throws {
        try? FileManager.default.removeItem(at: profileURL)
        let result = try await Shell.run(
            wgcf, ["generate", "--config", accountURL.path, "--profile", profileURL.path],
            timeout: 90
        )
        guard result.succeeded, FileManager.default.fileExists(atPath: profileURL.path) else {
            throw WireGuardError.commandFailed(step: "wgcf generate", output: result.combinedOutput)
        }
    }

    // MARK: Yardımcılar

    /// Tünelin oluşması birkaç saniye sürebilir; kısa süre bekleyerek durumu yeniler.
    private func refreshAfterAction() async {
        for _ in 0..<6 {
            await refreshStatus()
            if isConnected { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func createPrivateDirectory(_ url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    private func writePrivateFile(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Parola penceresi açıklaması.
    static var privilegedPrompt: String {
        L("SplitWire-Turkey, Cloudflare WARP (WireGuard) tünelini yönetmek için yönetici iznine ihtiyaç duyuyor.",
          "SplitWire-Turkey needs administrator permission to manage the Cloudflare WARP (WireGuard) tunnel.")
    }

    private func setStatus(_ message: LocalizedText, _ kind: WireGuardStatusKind) {
        status = message
        statusKind = kind
    }

    private func fail(_ title: LocalizedText, _ error: Error) {
        let message: String
        if let shellError = error as? ShellError {
            message = WireGuardSupport.trimmedOutput(shellError.localizedDescription)
        } else {
            message = error.localizedDescription
        }
        setStatus(LT("\(title.tr): \(message)", "\(title.en): \(message)"), .error)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title.resolved
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: L("Tamam", "OK"))
        alert.runModal()
    }
}
