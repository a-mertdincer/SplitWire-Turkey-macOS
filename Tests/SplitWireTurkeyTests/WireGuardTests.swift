import XCTest
@testable import SplitWireTurkey

final class WireGuardTests: XCTestCase {
    typealias WG = WireGuardSupport

    // MARK: - Sürüm / dosya seçimi

    let releaseJSON = """
    {
      "tag_name": "v2.3.0",
      "assets": [
        {"name": "checksums.txt", "browser_download_url": "https://github.com/ViRb3/wgcf/releases/download/v2.3.0/checksums.txt", "digest": null},
        {"name": "wgcf_2.3.0_darwin_amd64", "browser_download_url": "https://github.com/ViRb3/wgcf/releases/download/v2.3.0/wgcf_2.3.0_darwin_amd64", "digest": "sha256:54aac2497c1fd6ef9a90d13d18b8e1f16f043ee4907d189d7dd5c9f32cf462f0"},
        {"name": "wgcf_2.3.0_darwin_arm64", "browser_download_url": "https://github.com/ViRb3/wgcf/releases/download/v2.3.0/wgcf_2.3.0_darwin_arm64", "digest": "sha256:852d7fc7b74a5f9dca54c7cbd49068689aead71fe8f42f4af74eb9429cf87642"},
        {"name": "wgcf_2.3.0_freebsd_arm64", "browser_download_url": "https://github.com/ViRb3/wgcf/releases/download/v2.3.0/wgcf_2.3.0_freebsd_arm64"},
        {"name": "wgcf_2.3.0_linux_amd64", "browser_download_url": "https://github.com/ViRb3/wgcf/releases/download/v2.3.0/wgcf_2.3.0_linux_amd64"},
        {"name": "wgcf_2.3.0_windows_arm64.exe", "browser_download_url": "https://github.com/ViRb3/wgcf/releases/download/v2.3.0/wgcf_2.3.0_windows_arm64.exe"}
      ]
    }
    """

    func testDecodeReleaseAndSelectAsset() throws {
        let release = try WG.decodeRelease(Data(releaseJSON.utf8))
        XCTAssertEqual(release.tagName, "v2.3.0")

        let arm = try XCTUnwrap(WG.selectAsset(from: release.assets, arch: .arm64))
        XCTAssertEqual(arm.name, "wgcf_2.3.0_darwin_arm64")
        XCTAssertEqual(arm.sha256, "852d7fc7b74a5f9dca54c7cbd49068689aead71fe8f42f4af74eb9429cf87642")

        let intel = try XCTUnwrap(WG.selectAsset(from: release.assets, arch: .amd64))
        XCTAssertEqual(intel.name, "wgcf_2.3.0_darwin_amd64")
        XCTAssertEqual(intel.browserDownloadURL.lastPathComponent, "wgcf_2.3.0_darwin_amd64")

        XCTAssertNil(release.assets.first { $0.name == "checksums.txt" }?.sha256)
    }

    func testSelectAssetReturnsNilWithoutDarwinBuild() {
        let assets = [
            WG.GitHubAsset(name: "wgcf_2.3.0_linux_arm64", browserDownloadURL: URL(string: "https://example.com/a")!, digest: nil),
            WG.GitHubAsset(name: "wgcf_2.3.0_darwin_arm64.sig", browserDownloadURL: URL(string: "https://example.com/b")!, digest: nil),
        ]
        XCTAssertNil(WG.selectAsset(from: assets, arch: .arm64))
    }

    func testPinnedCandidates() {
        let arm = WG.pinnedCandidate(for: .arm64)
        XCTAssertEqual(arm.url.absoluteString, "https://github.com/ViRb3/wgcf/releases/download/v2.3.0/wgcf_2.3.0_darwin_arm64")
        XCTAssertTrue(WG.isHexSHA256(arm.sha256))
        let intel = WG.pinnedCandidate(for: .amd64)
        XCTAssertEqual(intel.url.lastPathComponent, "wgcf_2.3.0_darwin_amd64")
        XCTAssertNotEqual(arm.sha256, intel.sha256)
    }

    // MARK: - İndirme adayları (sabit sürüm önce, özetsiz dosya asla)

    private func release(tag: String, version: String, digest: String?) -> WG.GitHubRelease {
        let name = "wgcf_\(version)_darwin_arm64"
        return WG.GitHubRelease(tagName: tag, assets: [
            WG.GitHubAsset(name: name,
                           browserDownloadURL: URL(string: "https://github.com/ViRb3/wgcf/releases/download/\(tag)/\(name)")!,
                           digest: digest),
        ])
    }

    func testDownloadCandidatesPreferPinnedAndRequireDigest() {
        let pinned = WG.pinnedCandidate(for: .arm64)
        XCTAssertEqual(WG.downloadCandidates(latest: nil, arch: .arm64), [pinned])

        // latest == v2.3.0 ama API özet vermiyor: yalnızca gömülü özetli sabit aday
        XCTAssertEqual(WG.downloadCandidates(latest: release(tag: "v2.3.0", version: "2.3.0", digest: nil), arch: .arm64),
                       [pinned])
        // latest == v2.3.0 ve farklı (sahte) özet: yine gömülü özet geçerli
        let bogus = "sha256:" + String(repeating: "0", count: 64)
        XCTAssertEqual(WG.downloadCandidates(latest: release(tag: "v2.3.0", version: "2.3.0", digest: bogus), arch: .arm64),
                       [pinned])

        // Daha yeni sürüm + özet: sabit adaydan SONRA yedek olarak
        let sha = String(repeating: "ab", count: 32)
        let newer = WG.downloadCandidates(latest: release(tag: "v2.4.0", version: "2.4.0", digest: "sha256:" + sha), arch: .arm64)
        XCTAssertEqual(newer.count, 2)
        XCTAssertEqual(newer.first, pinned)
        XCTAssertEqual(newer.last?.sha256, sha)
        XCTAssertEqual(newer.last?.label, "v2.4.0")

        // Daha yeni sürüm ama özet yok: reddedilir
        XCTAssertEqual(WG.downloadCandidates(latest: release(tag: "v2.4.0", version: "2.4.0", digest: nil), arch: .arm64),
                       [pinned])
    }

    func testDigestParsing() {
        let url = URL(string: "https://example.com")!
        XCTAssertNil(WG.GitHubAsset(name: "x", browserDownloadURL: url, digest: "md5:abc").sha256)
        XCTAssertNil(WG.GitHubAsset(name: "x", browserDownloadURL: url, digest: "sha256:zz").sha256)
        XCTAssertEqual(
            WG.GitHubAsset(name: "x", browserDownloadURL: url, digest: "SHA256:" + String(repeating: "AB", count: 32)).sha256,
            String(repeating: "ab", count: 32)
        )
    }

    // MARK: - Mach-O

    /// Tekil 64-bit Mach-O başlığı (little-endian).
    private func thinHeader(cpu: UInt32) -> Data {
        var bytes: [UInt8] = [0xCF, 0xFA, 0xED, 0xFE]
        bytes += withUnsafeBytes(of: cpu.littleEndian, Array.init)
        bytes += [UInt8](repeating: 0, count: 24)
        return Data(bytes)
    }

    /// İki mimarili fat (universal) başlık (big-endian).
    private func fatHeader(cpus: [UInt32]) -> Data {
        var bytes: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE]
        bytes += withUnsafeBytes(of: UInt32(cpus.count).bigEndian, Array.init)
        for cpu in cpus {
            bytes += withUnsafeBytes(of: cpu.bigEndian, Array.init)
            bytes += [UInt8](repeating: 0, count: 16)
        }
        return Data(bytes)
    }

    func testMachOMagic() {
        XCTAssertTrue(WG.isMachO(thinHeader(cpu: 0x0100_000C)))
        XCTAssertTrue(WG.isMachO(Data([0xFE, 0xED, 0xFA, 0xCF, 0, 0, 0, 0])))
        XCTAssertTrue(WG.isMachO(fatHeader(cpus: [0x0100_0007, 0x0100_000C])))
        XCTAssertTrue(WG.isMachO(Data([0xBE, 0xBA, 0xFE, 0xCA])))

        // v1.0.0'ın 404 sayfasından kaydettiği içerik
        XCTAssertFalse(WG.isMachO(Data("Not Found".utf8)))
        XCTAssertFalse(WG.isMachO(Data("#!/bin/bash\n".utf8)))
        XCTAssertFalse(WG.isMachO(Data()))
        XCTAssertFalse(WG.isMachO(Data([0xCF, 0xFA])))
    }

    func testMachOArchitectures() {
        XCTAssertEqual(WG.machOArchitectures(thinHeader(cpu: 0x0100_000C)), [.arm64])
        XCTAssertEqual(WG.machOArchitectures(thinHeader(cpu: 0x0100_0007)), [.amd64])
        XCTAssertEqual(WG.machOArchitectures(fatHeader(cpus: [0x0100_0007, 0x0100_000C])), [.arm64, .amd64])
        XCTAssertEqual(WG.machOArchitectures(thinHeader(cpu: 12)), []) // 32-bit ARM: desteklenmez
        XCTAssertEqual(WG.machOArchitectures(Data("Not Found".utf8)), [])
    }

    func testIsUsableExecutable() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wgtest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        func make(_ name: String, _ data: Data, mode: Int) throws -> String {
            let url = dir.appendingPathComponent(name)
            try data.write(to: url)
            try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: url.path)
            return url.path
        }

        let notFound = try make("notfound", Data("Not Found".utf8), mode: 0o755)
        XCTAssertFalse(WG.isUsableExecutable(atPath: notFound, arch: .arm64))

        let arm = try make("arm", thinHeader(cpu: 0x0100_000C), mode: 0o755)
        XCTAssertTrue(WG.isUsableExecutable(atPath: arm, arch: .arm64))
        XCTAssertFalse(WG.isUsableExecutable(atPath: arm, arch: .amd64))

        let notExecutable = try make("noexec", thinHeader(cpu: 0x0100_000C), mode: 0o644)
        XCTAssertFalse(WG.isUsableExecutable(atPath: notExecutable, arch: .arm64))

        let universal = try make("fat", fatHeader(cpus: [0x0100_0007, 0x0100_000C]), mode: 0o755)
        XCTAssertTrue(WG.isUsableExecutable(atPath: universal, arch: .amd64))

        // Homebrew gibi sembolik bağlantılar hedefe göre değerlendirilir
        let link = dir.appendingPathComponent("link").path
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: arm)
        XCTAssertTrue(WG.isUsableExecutable(atPath: link, arch: .arm64))

        XCTAssertFalse(WG.isUsableExecutable(atPath: dir.path, arch: .arm64)) // klasör
        XCTAssertFalse(WG.isUsableExecutable(atPath: dir.appendingPathComponent("yok").path, arch: .arm64))
    }

    func testSHA256() {
        XCTAssertEqual(WG.sha256Hex(Data("abc".utf8)),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertTrue(WG.isHexSHA256(WG.sha256Hex(Data())))
        XCTAssertFalse(WG.isHexSHA256("abc"))
    }

    // MARK: - Profil / ifconfig

    let profile = """
    [Interface]
    PrivateKey = aGVsbG8=
    Address = 172.16.0.2/32, 2606:4700:110:8a36:0:0:0:1/128
    DNS = 1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001
    MTU = 1280
    [Peer]
    PublicKey = bmRY=
    AllowedIPs = 0.0.0.0/0, ::/0
    Endpoint = engage.cloudflareclient.com:2408
    """

    func testParseInterfaceAddresses() {
        XCTAssertEqual(WG.parseInterfaceAddresses(config: profile), ["172.16.0.2", "2606:4700:110:8a36:0:0:0:1"])
        XCTAssertEqual(WG.parseInterfaceAddresses(config: "[Peer]\nAddress = 10.0.0.1/32\n"), [])
        XCTAssertEqual(WG.parseInterfaceAddresses(config: "[Interface]\naddress=10.0.0.1/32\nAddress = 10.0.0.2\n"),
                       ["10.0.0.1", "10.0.0.2"])
    }

    let ifconfigOutput = """
    lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
    \tinet 127.0.0.1 netmask 0xff000000
    en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    \tinet 172.16.0.2 netmask 0xffffff00 broadcast 172.16.0.255
    utun3: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 2000
    \tinet6 fe80::4851:4104:a7ac:5d1a%utun3 prefixlen 64 scopeid 0x15
    utun8: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1280
    \tinet 172.16.0.2 --> 172.16.0.2 netmask 0xffffffff
    \tinet6 2606:4700:110:8a36::1 prefixlen 128
    """

    func testTunnelInterfaceDetection() {
        let addresses = WG.parseInterfaceAddresses(config: profile)
        // en0'daki aynı IPv4 sayılmaz; yalnızca utun arayüzleri
        XCTAssertEqual(WG.tunnelInterface(ifconfigOutput: ifconfigOutput, addresses: addresses), "utun8")
        // IPv6 kanonikleştirme: 0:0:0:1 == ::1
        XCTAssertEqual(WG.tunnelInterface(ifconfigOutput: ifconfigOutput, addresses: ["2606:4700:110:8a36:0:0:0:1"]), "utun8")
        XCTAssertNil(WG.tunnelInterface(ifconfigOutput: ifconfigOutput, addresses: ["10.9.9.9"]))
        XCTAssertNil(WG.tunnelInterface(ifconfigOutput: ifconfigOutput, addresses: []))

        let onlyEn0 = """
        en0: flags=8863<UP> mtu 1500
        \tinet 172.16.0.2 netmask 0xffffff00
        """
        XCTAssertNil(WG.tunnelInterface(ifconfigOutput: onlyEn0, addresses: ["172.16.0.2"]))
    }

    /// Resmî Cloudflare WARP uygulaması da 172.16.0.2 kullanır; profilin hesaba özgü IPv6'sı yoksa "Bağlı" denmemeli.
    func testTunnelInterfaceIgnoresSharedWarpIPv4() {
        let addresses = WG.parseInterfaceAddresses(config: profile)
        let officialWarp = """
        utun3: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1280
        \tinet 172.16.0.2 --> 172.16.0.2 netmask 0xffffffff
        \tinet6 2606:4700:110:1111::5 prefixlen 128
        """
        XCTAssertNil(WG.tunnelInterface(ifconfigOutput: officialWarp, addresses: addresses))
        XCTAssertEqual(WG.tunnelInterface(ifconfigOutput: ifconfigOutput, addresses: addresses), "utun8")
        // Yalnızca IPv4 içeren profil: ortak adrese geri düşülür
        XCTAssertEqual(WG.tunnelInterface(ifconfigOutput: officialWarp, addresses: ["172.16.0.2"]), "utun3")
    }

    // MARK: - Endpoint sabitleme

    func testParseEndpoint() {
        let endpoint = WG.parseEndpoint(config: profile)
        XCTAssertEqual(endpoint?.host, "engage.cloudflareclient.com")
        XCTAssertEqual(endpoint?.port, "2408")
        XCTAssertNil(WG.parseEndpoint(config: "[Interface]\nEndpoint = a.b:1\n"))
        let v6 = WG.splitHostPort("[2606:4700:d0::a29f:c001]:2408")
        XCTAssertEqual(v6?.host, "2606:4700:d0::a29f:c001")
        XCTAssertEqual(v6?.port, "2408")
        XCTAssertNil(WG.splitHostPort("engage.cloudflareclient.com"))
        XCTAssertNil(WG.splitHostPort("2606:4700::1:2408"))
    }

    func testPinEndpoint() {
        let pinned = WG.pinEndpoint(config: profile, ip: "162.159.192.1")
        XCTAssertTrue(pinned.contains("\nEndpoint = 162.159.192.1:2408"), pinned)
        XCTAssertFalse(pinned.contains("engage.cloudflareclient.com"))
        // Diğer satırlar korunur
        XCTAssertEqual(WG.parseInterfaceAddresses(config: pinned), WG.parseInterfaceAddresses(config: profile))
        XCTAssertTrue(pinned.contains("AllowedIPs = 0.0.0.0/0, ::/0"))
        XCTAssertEqual(pinned.components(separatedBy: "\n").count, profile.components(separatedBy: "\n").count)

        // IPv6 köşeli parantezle
        XCTAssertTrue(WG.pinEndpoint(config: profile, ip: "2606:4700:d0::a29f:c001")
            .contains("Endpoint = [2606:4700:d0::a29f:c001]:2408"))

        // Zaten IP ise değişmez; geçersiz "IP" (enjeksiyon) yok sayılır
        XCTAssertEqual(WG.pinEndpoint(config: pinned, ip: "1.2.3.4"), pinned)
        XCTAssertEqual(WG.pinEndpoint(config: profile, ip: "1.2.3.4\nPostUp = id"), profile)
        XCTAssertEqual(WG.pinEndpoint(config: profile, ip: "example.com"), profile)

        // [Interface] içindeki aynı adlı anahtar değişmez
        let odd = "[Interface]\nEndpoint = x.y:1\n[Peer]\nEndpoint = a.b:2\n"
        XCTAssertEqual(WG.pinEndpoint(config: odd, ip: "9.9.9.9"), "[Interface]\nEndpoint = x.y:1\n[Peer]\nEndpoint = 9.9.9.9:2\n")
    }

    func testNormalizeIP() {
        XCTAssertEqual(WG.normalizeIP("2606:4700:110:8A36:0:0:0:1"), "2606:4700:110:8a36::1")
        XCTAssertEqual(WG.normalizeIP("fe80::1%utun3"), "fe80::1")
        XCTAssertEqual(WG.normalizeIP("172.16.0.2"), "172.16.0.2")
    }

    // MARK: - LaunchDaemon / komutlar

    func testToolPathAndPrefix() {
        XCTAssertEqual(WG.toolPATH(forWgQuick: "/opt/homebrew/bin/wg-quick"), "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin")
        XCTAssertEqual(WG.toolPATH(forWgQuick: "/usr/local/bin/wg-quick"), "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")
        XCTAssertEqual(WG.brewPrefix(forWgQuick: "/opt/homebrew/bin/wg-quick"), "/opt/homebrew")
        XCTAssertEqual(WG.requiredCompanionTools(forWgQuick: "/usr/local/bin/wg-quick"),
                       ["/usr/local/bin/bash", "/usr/local/bin/wg", "/usr/local/bin/wireguard-go"])
    }

    func testLaunchDaemonPlist() throws {
        let data = try WG.launchDaemonPlist(wgQuickPath: "/opt/homebrew/bin/wg-quick")
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["Label"] as? String, "com.splitwire.wireguard")
        XCTAssertEqual(plist["ProgramArguments"] as? [String], ["/opt/homebrew/bin/wg-quick", "up", "/etc/wireguard/wgcf.conf"])
        XCTAssertEqual((plist["EnvironmentVariables"] as? [String: String])?["PATH"],
                       "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin")
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertNil(plist["KeepAlive"])
    }

    func testInstallCommand() {
        let cmd = WG.installCommand(
            wgQuickPath: "/opt/homebrew/bin/wg-quick",
            sourceConfigPath: "/Users/o'neil/.config/wireguard/wgcf.conf",
            sourcePlistPath: "/var/folders/xy/T/splitwire-wg-1/com.splitwire.wireguard.plist"
        )
        XCTAssertFalse(cmd.contains("sudo"))
        XCTAssertFalse(cmd.contains("AllowedApps"))
        XCTAssertTrue(cmd.contains("/bin/mkdir -p '/etc/wireguard'"))
        XCTAssertTrue(cmd.contains("/bin/chmod 700 '/etc/wireguard'"))
        // Kesme işareti içeren yol doğru kaçırılır
        XCTAssertTrue(cmd.contains("/usr/bin/install -m 600 -o root -g wheel '/Users/o'\\''neil/.config/wireguard/wgcf.conf' '/etc/wireguard/wgcf.conf'"))
        XCTAssertTrue(cmd.contains("/usr/bin/install -m 644 -o root -g wheel '/var/folders/xy/T/splitwire-wg-1/com.splitwire.wireguard.plist' '/Library/LaunchDaemons/com.splitwire.wireguard.plist'"))
        XCTAssertTrue(cmd.contains("/bin/launchctl bootout system/com.splitwire.wireguard"))
        XCTAssertTrue(cmd.contains("/bin/launchctl bootstrap system '/Library/LaunchDaemons/com.splitwire.wireguard.plist'"))
        XCTAssertTrue(cmd.contains("/usr/bin/env PATH='/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin' '/opt/homebrew/bin/wg-quick' up '/etc/wireguard/wgcf.conf'"))
        XCTAssertTrue(cmd.contains("already exists"))
        // Tünel bootstrap'tan önce açılır (hata çıktısı yakalanabilsin)
        let up = cmd.range(of: "' up '")!.lowerBound
        let bootstrap = cmd.range(of: "launchctl bootstrap")!.lowerBound
        XCTAssertLessThan(up, bootstrap)
        XCTAssertFalse(cmd.contains("/bin/rm -f '/Library/LaunchDaemons"))
    }

    /// Eski tünelin izleyicisi bitmeden yeni tünel açılmaz: down → pgrep bekleme → up.
    func testInstallCommandWaitsForOldTunnelBetweenDownAndUp() throws {
        let cmd = WG.installCommand(wgQuickPath: "/opt/homebrew/bin/wg-quick",
                                    sourceConfigPath: "/tmp/wgcf.conf", sourcePlistPath: nil)
        let down = try XCTUnwrap(cmd.range(of: "' down '")).lowerBound
        let wait = try XCTUnwrap(cmd.range(of: "/usr/bin/pgrep -qf 'wg-quick up /etc/wireguard/wgcf[.]conf'")).lowerBound
        let up = try XCTUnwrap(cmd.range(of: "' up '")).lowerBound
        XCTAssertLessThan(down, wait)
        XCTAssertLessThan(wait, up)
        XCTAssertTrue(cmd.contains("[ $i -lt 100 ]"))

        // Desen bu betiğin kendi komut satırıyla eşleşmemeli ("[.]" düz metinle eşleşmez)
        XCTAssertNil(cmd.range(of: "wg-quick up /etc/wireguard/wgcf[.]conf", options: .regularExpression))
        // ...ama launchd/wg-quick'in gerçek süreç satırıyla eşleşir
        XCTAssertNotNil("/bin/bash /opt/homebrew/bin/wg-quick up /etc/wireguard/wgcf.conf"
            .range(of: "wg-quick up /etc/wireguard/wgcf[.]conf", options: .regularExpression))
    }

    /// Açılışta başlatma seçilmezse daemon kurulmaz ve eski daemon kaldırılır (root'ta kullanıcı-yazılabilir kod yok).
    func testInstallCommandWithoutStartAtBoot() {
        let cmd = WG.installCommand(wgQuickPath: "/opt/homebrew/bin/wg-quick",
                                    sourceConfigPath: "/tmp/wgcf.conf", sourcePlistPath: nil)
        XCTAssertFalse(cmd.contains("launchctl bootstrap"))
        XCTAssertFalse(cmd.contains("-m 644"))
        XCTAssertTrue(cmd.contains("/bin/launchctl bootout system/com.splitwire.wireguard"))
        XCTAssertTrue(cmd.contains("/bin/rm -f '/Library/LaunchDaemons/com.splitwire.wireguard.plist'"))
        XCTAssertTrue(cmd.contains("/usr/bin/install -m 600 -o root -g wheel '/tmp/wgcf.conf' '/etc/wireguard/wgcf.conf'"))
        XCTAssertTrue(cmd.contains("' up '/etc/wireguard/wgcf.conf'"))
    }

    func testUpDownUninstallCommands() {
        let up = WG.upCommand(wgQuickPath: "/usr/local/bin/wg-quick")
        XCTAssertTrue(up.contains("PATH='/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' '/usr/local/bin/wg-quick' up '/etc/wireguard/wgcf.conf'"))
        XCTAssertTrue(up.contains(">&2; exit $rc"))

        let down = WG.downCommand(wgQuickPath: "/usr/local/bin/wg-quick")
        XCTAssertTrue(down.contains("'/usr/local/bin/wg-quick' down '/etc/wireguard/wgcf.conf'"))
        XCTAssertTrue(down.contains("is not a WireGuard interface"))

        let uninstall = WG.uninstallCommand(wgQuickPath: "/opt/homebrew/bin/wg-quick")
        XCTAssertTrue(uninstall.contains("'/opt/homebrew/bin/wg-quick' down"))
        XCTAssertTrue(uninstall.contains("/bin/launchctl bootout system/com.splitwire.wireguard"))
        XCTAssertTrue(uninstall.contains("/bin/rm -f '/Library/LaunchDaemons/com.splitwire.wireguard.plist' '/etc/wireguard/wgcf.conf'"))
        XCTAssertTrue(uninstall.hasSuffix("true"))

        let withoutTools = WG.uninstallCommand(wgQuickPath: nil)
        XCTAssertFalse(withoutTools.contains("wg-quick"))
        XCTAssertTrue(withoutTools.contains("/var/run/wireguard/wgcf.name"))
    }

    /// Üretilen komutlar sözdizimsel olarak geçerli POSIX sh olmalı (`sh -n`, hiçbir şey çalıştırmaz).
    func testCommandsAreValidShellSyntax() throws {
        let commands = [
            WG.installCommand(wgQuickPath: "/opt/homebrew/bin/wg-quick",
                              sourceConfigPath: "/Users/a b/.config/wireguard/wgcf.conf",
                              sourcePlistPath: "/tmp/x'y/p.plist"),
            WG.installCommand(wgQuickPath: "/opt/homebrew/bin/wg-quick",
                              sourceConfigPath: "/Users/a b/.config/wireguard/wgcf.conf",
                              sourcePlistPath: nil),
            WG.waitForOldTunnelCommand(),
            WG.upCommand(wgQuickPath: "/opt/homebrew/bin/wg-quick"),
            WG.downCommand(wgQuickPath: "/opt/homebrew/bin/wg-quick"),
            WG.uninstallCommand(wgQuickPath: "/opt/homebrew/bin/wg-quick"),
            WG.uninstallCommand(wgQuickPath: nil),
        ]
        for command in commands {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-n", "-c", command]
            let errPipe = Pipe()
            process.standardError = errPipe
            try process.run()
            process.waitUntilExit()
            let err = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            XCTAssertEqual(process.terminationStatus, 0, "sh -n failed: \(err)\n\(command)")
        }
    }

    // MARK: - Hata metni

    func testTrimmedOutputKeepsTail() {
        let long = String(repeating: "[#] satır\n", count: 200) + "wg-quick: `wgcf' already exists as `utun5'"
        let trimmed = WG.trimmedOutput(long, limit: 100)
        XCTAssertTrue(trimmed.hasPrefix("…"))
        XCTAssertTrue(trimmed.hasSuffix("already exists as `utun5'"))
        XCTAssertLessThanOrEqual(trimmed.count, 101)
        XCTAssertEqual(WG.trimmedOutput("  kısa\r\n"), "kısa")
    }

    func testCommandFailedErrorContainsOutput() {
        let error = WireGuardError.commandFailed(step: "wgcf register", output: "2026/10/01 Using config file\n2026/10/01 failed to register: 429 Too Many Requests\n")
        XCTAssertTrue(error.localizedDescription.contains("429 Too Many Requests"))
        withAppLanguage(.turkish) {
            XCTAssertTrue(error.localizedDescription.hasPrefix("wgcf register başarısız oldu"))
        }
        withAppLanguage(.english) {
            XCTAssertTrue(error.localizedDescription.hasPrefix("wgcf register failed"))
        }
    }

    func testConnectionStateTitles() {
        withAppLanguage(.turkish) {
            XCTAssertEqual(WireGuardConnectionState.connected(interface: "utun8").title, "Bağlı")
            XCTAssertEqual(WireGuardConnectionState.configured.title, "Yapılandırıldı (bağlı değil)")
            XCTAssertEqual(WireGuardConnectionState.notConfigured.title, "Yapılandırılmadı")
        }
        withAppLanguage(.english) {
            XCTAssertEqual(WireGuardConnectionState.connected(interface: "utun8").title, "Connected")
        }
    }
}
