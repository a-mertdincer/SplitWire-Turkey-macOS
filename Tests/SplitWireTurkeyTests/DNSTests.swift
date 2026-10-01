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
