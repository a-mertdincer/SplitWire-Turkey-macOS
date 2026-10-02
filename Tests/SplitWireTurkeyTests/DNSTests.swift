import XCTest
@testable import SplitWireTurkey

final class DNSHealthEvaluatorTests: XCTestCase {
    let realDiscord = ["162.159.136.232", "162.159.137.232", "162.159.138.232", "162.159.128.233", "162.159.135.232"]

    func testKnownBlockIPIsPoisonedEvenWithoutDoH() {
        let state = DNSHealthEvaluator.evaluate(systemIPs: ["195.175.254.2"], dohIPs: nil)
        XCTAssertEqual(state, .poisoned(systemIPs: ["195.175.254.2"], expectedIPs: []))
    }

    func testKnownBlockIPIsPoisonedWithDoH() {
        let state = DNSHealthEvaluator.evaluate(systemIPs: ["195.175.254.2"], dohIPs: realDiscord)
        XCTAssertEqual(state, .poisoned(systemIPs: ["195.175.254.2"], expectedIPs: realDiscord))
    }

    func testDisjointAddressesArePoisoned() {
        let state = DNSHealthEvaluator.evaluate(systemIPs: ["10.0.0.1", "10.0.0.1"], dohIPs: realDiscord)
        XCTAssertEqual(state, .poisoned(systemIPs: ["10.0.0.1"], expectedIPs: realDiscord))
    }

    func testExactMatchIsOK() {
        XCTAssertEqual(DNSHealthEvaluator.evaluate(systemIPs: realDiscord, dohIPs: realDiscord), .ok)
    }

    func testDifferentSubsetSameNetworkIsOK() {
        // gateway.discord.gg TTL=5 ile her sorguda farklı alt küme döner; yanlış alarm olmamalı.
        let state = DNSHealthEvaluator.evaluate(
            systemIPs: ["162.159.130.234", "162.159.133.234"],
            dohIPs: ["162.159.136.234", "162.159.134.234"])
        XCTAssertEqual(state, .ok)
    }

    func testDoHUnreachableIsUnknown() {
        XCTAssertEqual(DNSHealthEvaluator.evaluate(systemIPs: ["10.0.0.1"], dohIPs: nil), .unknown)
        XCTAssertEqual(DNSHealthEvaluator.evaluate(systemIPs: ["10.0.0.1"], dohIPs: []), .unknown)
    }

    func testSystemFailureIsUnknown() {
        XCTAssertEqual(DNSHealthEvaluator.evaluate(systemIPs: [], dohIPs: realDiscord), .unknown)
    }

    func testCombine() {
        let poisoned = DNSHealthState.poisoned(systemIPs: ["195.175.254.2"], expectedIPs: [])
        XCTAssertEqual(DNSHealthEvaluator.combine([.ok, poisoned]), poisoned)
        XCTAssertEqual(DNSHealthEvaluator.combine([.unknown, poisoned]), poisoned)
        XCTAssertEqual(DNSHealthEvaluator.combine([.ok, .ok]), .ok)
        XCTAssertEqual(DNSHealthEvaluator.combine([.ok, .unknown]), .unknown)
        XCTAssertEqual(DNSHealthEvaluator.combine([]), .unknown)
    }

    /// Birden çok zehirlenmiş sonuç: adresler birleştirilir (tekrarsız).
    func testCombineMergesPoisonedAddresses() {
        let discord = DNSHealthState.poisoned(systemIPs: ["195.175.254.2"], expectedIPs: realDiscord)
        let roblox = DNSHealthState.poisoned(systemIPs: ["195.175.254.2", "10.0.0.1"], expectedIPs: [])
        XCTAssertEqual(DNSHealthEvaluator.combine([discord, .ok, roblox]),
                       .poisoned(systemIPs: ["195.175.254.2", "10.0.0.1"], expectedIPs: realDiscord))
    }

    /// #13: Roblox yalnızca bilinen engelleme adresiyle "zehirli" sayılır (CDN adresleri konuma göre değişir).
    func testRobloxKnownBlockIPOnly() {
        let roblox = DNSCheckTarget(host: "www.roblox.com", service: "Roblox", rule: .knownBlockIPOnly)
        XCTAssertEqual(DNSHealthEvaluator.evaluate(roblox, systemIPs: ["195.175.254.2"], dohIPs: nil),
                       .poisoned(systemIPs: ["195.175.254.2"], expectedIPs: []))
        // DoH farklı bir CDN adresi döndürse bile yanlış alarm yok
        XCTAssertEqual(DNSHealthEvaluator.evaluate(roblox, systemIPs: ["23.48.136.233"], dohIPs: ["128.116.31.3"]), .ok)
        XCTAssertEqual(DNSHealthEvaluator.evaluate(roblox, systemIPs: ["128.116.21.3"], dohIPs: nil), .ok)
        // Sistem çözemedi: bilinmiyor
        XCTAssertEqual(DNSHealthEvaluator.evaluate(roblox, systemIPs: [], dohIPs: ["128.116.31.3"]), .unknown)
    }

    /// Roblox, Discord için zehirli bulunan adresle (bilinmeyen bir engelleme sayfası) eşleşirse zehirli sayılır.
    func testRobloxUsesAddressDiscordWasPoisonedWith() {
        let t = DNSHealthChecker.targets
        let results = DNSHealthEvaluator.evaluateAll([
            (t[0], ["10.0.0.1"], realDiscord),
            (t[1], ["10.0.0.1"], realDiscord),
            (t[2], ["10.0.0.1"], nil),
        ])
        XCTAssertEqual(results.map(\.0), t)
        XCTAssertEqual(results[2].1, .poisoned(systemIPs: ["10.0.0.1"], expectedIPs: []))
        XCTAssertEqual(DNSHealthEvaluator.affectedServices(results), ["Discord", "Roblox"])

        // Discord aynı şekilde zehirli, Roblox gerçek bir CDN adresi: yanlış alarm yok
        let cdn = DNSHealthEvaluator.evaluateAll([
            (t[0], ["10.0.0.1"], realDiscord),
            (t[2], ["23.48.136.233"], nil),
        ])
        XCTAssertEqual(cdn[1].1, .ok)
        XCTAssertEqual(DNSHealthEvaluator.affectedServices(cdn), ["Discord"])
    }

    func testRobloxNonRoutableIsPoisoned() {
        let t = DNSHealthChecker.targets
        for ip in ["0.0.0.0", "127.0.0.1"] {
            let results = DNSHealthEvaluator.evaluateAll([(t[0], realDiscord, realDiscord), (t[2], [ip], nil)])
            XCTAssertEqual(results[0].1, .ok)
            XCTAssertEqual(results[1].1, .poisoned(systemIPs: [ip], expectedIPs: []), ip)
        }
        // Discord doğru, Roblox gerçek adres: mevcut davranış korunur
        let ok = DNSHealthEvaluator.evaluateAll([(t[0], realDiscord, realDiscord), (t[2], ["128.116.21.3"], nil)])
        XCTAssertEqual(ok[1].1, .ok)
        // Fake-IP / iç ağ adresleri engelleme sayılmaz
        XCTAssertTrue(DNSHealthEvaluator.isNonRoutable("0.0.0.0"))
        XCTAssertTrue(DNSHealthEvaluator.isNonRoutable("127.0.0.1"))
        XCTAssertFalse(DNSHealthEvaluator.isNonRoutable("198.18.0.5"))
        XCTAssertFalse(DNSHealthEvaluator.isNonRoutable("10.0.0.1"))
        XCTAssertFalse(DNSHealthEvaluator.isNonRoutable("128.116.21.3"))
        XCTAssertFalse(DNSHealthEvaluator.isNonRoutable("::1"))
    }

    func testDiscordTargetComparesWithDoH() {
        let discord = DNSCheckTarget(host: "discord.com", service: "Discord", rule: .compareWithDoH)
        XCTAssertEqual(DNSHealthEvaluator.evaluate(discord, systemIPs: ["10.0.0.1"], dohIPs: realDiscord),
                       .poisoned(systemIPs: ["10.0.0.1"], expectedIPs: realDiscord))
        XCTAssertEqual(DNSHealthEvaluator.evaluate(discord, systemIPs: ["10.0.0.1"], dohIPs: nil), .unknown)
    }

    func testCheckedTargets() {
        XCTAssertEqual(DNSHealthChecker.hosts, ["discord.com", "gateway.discord.gg", "www.roblox.com"])
        XCTAssertEqual(DNSHealthChecker.services, ["Discord", "Roblox"])
        XCTAssertEqual(DNSHealthChecker.targets.last?.rule, .knownBlockIPOnly)
        XCTAssertTrue(DNSHealthEvaluator.knownBlockIPs.contains("195.175.254.2"))
    }

    func testAffectedServicesAndHosts() {
        let targets = DNSHealthChecker.targets
        let block = DNSHealthState.poisoned(systemIPs: ["195.175.254.2"], expectedIPs: [])
        let all = [(targets[0], block), (targets[1], block), (targets[2], block)]
        XCTAssertEqual(DNSHealthEvaluator.affectedServices(all), ["Discord", "Roblox"])
        XCTAssertEqual(DNSHealthEvaluator.affectedHosts(all), ["discord.com", "gateway.discord.gg", "www.roblox.com"])

        let robloxOnly = [(targets[0], DNSHealthState.ok), (targets[1], .unknown), (targets[2], block)]
        XCTAssertEqual(DNSHealthEvaluator.affectedServices(robloxOnly), ["Roblox"])
        XCTAssertEqual(DNSHealthEvaluator.affectedHosts(robloxOnly), ["www.roblox.com"])

        let none = [(targets[0], DNSHealthState.ok), (targets[2], .ok)]
        XCTAssertEqual(DNSHealthEvaluator.affectedServices(none), [])
    }

    func testBannerMessagesNameAffectedServices() {
        withAppLanguage(.turkish) {
            let both = DNSHealthBanner.blockedMessage(services: ["Discord", "Roblox"],
                                                      hosts: ["discord.com", "www.roblox.com"],
                                                      systemIPs: ["195.175.254.2"]).resolved
            XCTAssertTrue(both.hasPrefix("Discord ve Roblox için DNS sunucunuz"), both)
            XCTAssertTrue(both.contains("(195.175.254.2)"), both)
            XCTAssertTrue(both.contains("discord.com, www.roblox.com"), both)
            let roblox = DNSHealthBanner.blockedMessage(services: ["Roblox"], hosts: ["www.roblox.com"],
                                                        systemIPs: ["195.175.254.2"]).resolved
            XCTAssertTrue(roblox.hasPrefix("Roblox için"), roblox)
            XCTAssertFalse(roblox.contains("Discord"), roblox)
            XCTAssertEqual(DNSHealthBanner.okMessage(services: ["Discord", "Roblox"]).resolved,
                           "DNS doğru çözümlüyor (Discord doğrulandı; Roblox engelleme adresine gitmiyor)")
        }
        withAppLanguage(.english) {
            let both = DNSHealthBanner.blockedMessage(services: ["Discord", "Roblox"], hosts: [],
                                                      systemIPs: ["195.175.254.2"]).resolved
            XCTAssertTrue(both.hasPrefix("For Discord and Roblox, your DNS server"), both)
            XCTAssertTrue(both.hasSuffix("ByeDPI can't connect to Discord and Roblox."), both)
            // Servis bilgisi yoksa Discord varsayılır
            XCTAssertTrue(DNSHealthBanner.blockedMessage(services: [], hosts: [], systemIPs: ["195.175.254.2"])
                .resolved.hasPrefix("For Discord,"))
            XCTAssertEqual(DNSHealthBanner.okMessage(services: ["Discord", "Roblox"]).resolved,
                           "DNS resolves correctly (Discord verified; Roblox doesn't point to a block page)")
        }
    }

    func testLocalizedList() {
        XCTAssertEqual(LList([]), LT("", ""))
        XCTAssertEqual(LList(["Discord"]), LT("Discord", "Discord"))
        XCTAssertEqual(LList(["Discord", "Roblox"]), LT("Discord ve Roblox", "Discord and Roblox"))
        XCTAssertEqual(LList(["A", "B", "C"]), LT("A, B ve C", "A, B and C"))
    }

    func testNetworkKey() {
        XCTAssertEqual(DNSHealthEvaluator.networkKey("162.159.1.2"), "162.159")
        XCTAssertNil(DNSHealthEvaluator.networkKey("2606:4700::1111"))
        XCTAssertNil(DNSHealthEvaluator.networkKey("256.1.1.1"))
        XCTAssertNil(DNSHealthEvaluator.networkKey("1.2.3"))
    }

    func testParseDoHJSON() {
        let json = """
        {"Status":0,"TC":false,"Answer":[
          {"name":"discord.com","type":5,"TTL":1,"data":"alias.example."},
          {"name":"discord.com","type":1,"TTL":262,"data":"162.159.136.232"},
          {"name":"discord.com","type":1,"TTL":262,"data":"162.159.137.232"},
          {"name":"discord.com","type":1,"TTL":262,"data":"162.159.137.232"}]}
        """
        XCTAssertEqual(DNSHealthEvaluator.parseDoHJSON(Data(json.utf8)), ["162.159.136.232", "162.159.137.232"])
        XCTAssertNil(DNSHealthEvaluator.parseDoHJSON(Data(#"{"Status":2}"#.utf8)))
        XCTAssertNil(DNSHealthEvaluator.parseDoHJSON(Data("Not Found".utf8)))
        XCTAssertEqual(DNSHealthEvaluator.parseDoHJSON(Data(#"{"Status":0}"#.utf8)), [])
    }
}

final class DNSConfigTests: XCTestCase {
    func testParseGetDNSServers() {
        XCTAssertEqual(DNSConfigParser.parseGetDNSServers("There aren't any DNS Servers set on Wi-Fi.\n"), [])
        XCTAssertEqual(DNSConfigParser.parseGetDNSServers("1.1.1.1\n1.0.0.1\n"), ["1.1.1.1", "1.0.0.1"])
        XCTAssertNil(DNSConfigParser.parseGetDNSServers("en0 is not a recognized network service.\n** Error: The parameters were not valid.\n"))
    }

    func testParseEffectiveNameserversSkipsSupplementalAndDomainResolvers() {
        let output = """
        DNS configuration

        resolver #1
          search domain[0] : tailfc566b.ts.net
          nameserver[0] : 100.100.100.100
          if_index : 28 (utun2)
          flags    : Supplemental, Request A records, Request AAAA records
          order    : 100800

        resolver #2
          nameserver[0] : 192.168.1.1
          nameserver[1] : fe80::1%en0
          if_index : 14 (en0)
          flags    : Request A records

        resolver #3
          domain   : local
          options  : mdns

        DNS configuration (for scoped queries)

        resolver #1
          nameserver[0] : 10.9.9.9
          if_index : 14 (en0)
        """
        XCTAssertEqual(DNSConfigParser.parseEffectiveNameservers(output), ["192.168.1.1", "fe80::1%en0"])
        XCTAssertEqual(DNSConfigParser.parseEffectiveNameservers(""), [])
    }

    func testSetDNSCommandQuotesServiceAndFlushesCache() {
        let cmd = NetworkConfigService.setDNSCommand(service: "Ev'in Wi-Fi", servers: DNSPreset.cloudflare.servers)
        XCTAssertTrue(cmd.hasPrefix("'/usr/sbin/networksetup' '-setdnsservers' 'Ev'\\''in Wi-Fi' '1.1.1.1' '1.0.0.1' && "), cmd)
        XCTAssertTrue(cmd.contains("dscacheutil -flushcache"))
        XCTAssertTrue(cmd.contains("killall -HUP mDNSResponder"))
        // Önbellek temizleme gruplanır: networksetup başarısızsa betik onun çıkış koduyla biter
        XCTAssertTrue(cmd.contains(" && { /usr/bin/dscacheutil -flushcache; "), cmd)
        XCTAssertTrue(cmd.hasSuffix("; }"), cmd)
    }

    /// networksetup başarısız olunca (ör. servis yeniden adlandırıldı) hata yutulmamalı.
    func testSetDNSCommandPropagatesFailure() throws {
        let cmd = NetworkConfigService.setDNSCommand(service: "Wi-Fi", servers: ["1.1.1.1"])
        // Yan etkisiz deneme: networksetup yerine `false`, önbellek komutları yerine `true`
        let probe = cmd
            .replacingOccurrences(of: "'/usr/sbin/networksetup' '-setdnsservers' 'Wi-Fi' '1.1.1.1'", with: "(exit 4)")
            .replacingOccurrences(of: NetworkConfigService.flushCommand, with: "true")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", probe]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 4, probe)
    }

    func testSetDNSCommandResetUsesEmpty() {
        let cmd = NetworkConfigService.setDNSCommand(service: "Wi-Fi", servers: [])
        XCTAssertTrue(cmd.hasPrefix("'/usr/sbin/networksetup' '-setdnsservers' 'Wi-Fi' 'empty' && "), cmd)
    }

    func testPresets() {
        XCTAssertEqual(DNSPreset.cloudflare.servers, ["1.1.1.1", "1.0.0.1"])
        XCTAssertEqual(DNSPreset.google.servers, ["8.8.8.8", "8.8.4.4"])
        XCTAssertEqual(DNSPreset.quad9.servers, ["9.9.9.9", "149.112.112.112"])
        XCTAssertEqual(DNSPreset.matching(["9.9.9.9", "149.112.112.112"]), .quad9)
        XCTAssertNil(DNSPreset.matching(["192.168.1.1"]))
        XCTAssertEqual(DNSPreset.cloudflare.title, "Cloudflare (1.1.1.1, 1.0.0.1)")
    }
}

final class DoHProfileTests: XCTestCase {
    func testProfileStructure() throws {
        let data = try DoHProfile.makeData()
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["PayloadType"] as? String, "Configuration")
        XCTAssertEqual(plist["PayloadIdentifier"] as? String, "com.splitwire.doh.cloudflare")
        XCTAssertEqual(plist["PayloadDisplayName"] as? String, "SplitWire – Cloudflare DNS over HTTPS")
        XCTAssertEqual(plist["PayloadScope"] as? String, "System")
        XCTAssertNotNil(UUID(uuidString: plist["PayloadUUID"] as? String ?? ""))

        let content = try XCTUnwrap(plist["PayloadContent"] as? [[String: Any]])
        XCTAssertEqual(content.count, 1)
        let dns = content[0]
        XCTAssertEqual(dns["PayloadType"] as? String, "com.apple.dnsSettings.managed")
        XCTAssertNotNil(UUID(uuidString: dns["PayloadUUID"] as? String ?? ""))
        let settings = try XCTUnwrap(dns["DNSSettings"] as? [String: Any])
        XCTAssertEqual(settings["DNSProtocol"] as? String, "HTTPS")
        XCTAssertEqual(settings["ServerURL"] as? String, "https://cloudflare-dns.com/dns-query")
        XCTAssertEqual(settings["ServerAddresses"] as? [String],
                       ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001"])
    }

    func testFreshUUIDsEachTime() throws {
        let a = DoHProfile.makePayload()
        let b = DoHProfile.makePayload()
        XCTAssertNotEqual(a["PayloadUUID"] as? String, b["PayloadUUID"] as? String)
    }

    func testPlutilLint() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("splitwire-doh-\(UUID().uuidString).mobileconfig")
        defer { try? FileManager.default.removeItem(at: url) }
        try DoHProfile.write(to: url)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        process.arguments = ["-lint", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("<?xml"))
    }
}
