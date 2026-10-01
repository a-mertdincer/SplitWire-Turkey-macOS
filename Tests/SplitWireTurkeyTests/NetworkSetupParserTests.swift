import XCTest
@testable import SplitWireTurkey

final class NetworkSetupParserTests: XCTestCase {
    let serviceOrder = """
    An asterisk (*) denotes that a network service is disabled.
    (1) USB 10/100 LAN
    (Hardware Port: USB 10/100 LAN, Device: en8)

    (2) Thunderbolt Bridge
    (Hardware Port: Thunderbolt Bridge, Device: bridge0)

    (3) Wi-Fi
    (Hardware Port: Wi-Fi, Device: en0)

    (*) Ev Ağı (Eski)
    (Hardware Port: Wi-Fi, Device: en0)

    (4) Tailscale
    (Hardware Port: io.tailscale.ipn.macos, Device: )

    """

    func testParseServiceOrder() {
        let services = NetworkSetupParser.parseServiceOrder(serviceOrder)
        XCTAssertEqual(services.count, 5)
        XCTAssertEqual(services[0], NetworkServiceInfo(name: "USB 10/100 LAN", hardwarePort: "USB 10/100 LAN", device: "en8", isEnabled: true))
        XCTAssertEqual(services[2].name, "Wi-Fi")
        XCTAssertEqual(services[2].device, "en0")
        XCTAssertEqual(services[3], NetworkServiceInfo(name: "Ev Ağı (Eski)", hardwarePort: "Wi-Fi", device: "en0", isEnabled: false))
        XCTAssertEqual(services[4].name, "Tailscale")
        XCTAssertNil(services[4].device)
    }

    func testServiceNameForDevice() {
        let services = NetworkSetupParser.parseServiceOrder(serviceOrder)
        XCTAssertEqual(NetworkSetupParser.serviceName(forDevice: "en0", in: services), "Wi-Fi")
        XCTAssertEqual(NetworkSetupParser.serviceName(forDevice: "en8", in: services), "USB 10/100 LAN")
        XCTAssertEqual(NetworkSetupParser.serviceName(forDevice: "bridge0", in: services), "Thunderbolt Bridge")
        XCTAssertNil(NetworkSetupParser.serviceName(forDevice: "utun3", in: services))
    }

    func testServiceNameDiffersFromHardwarePort() {
        let output = """
        An asterisk (*) denotes that a network service is disabled.
        (1) Ofis Ethernet
        (Hardware Port: USB 10/100/1000 LAN, Device: en7)
        """
        let services = NetworkSetupParser.parseServiceOrder(output)
        XCTAssertEqual(NetworkSetupParser.serviceName(forDevice: "en7", in: services), "Ofis Ethernet")
        XCTAssertEqual(services.first?.hardwarePort, "USB 10/100/1000 LAN")
    }

    func testParseDefaultRouteInterface() {
        let output = """
           route to: default
        destination: default
               mask: default
            gateway: 192.168.1.1
          interface: en0
              flags: <UP,GATEWAY,DONE,STATIC,PRCLONING,GLOBAL>
        """
        XCTAssertEqual(NetworkSetupParser.parseDefaultRouteInterface(output), "en0")
        XCTAssertNil(NetworkSetupParser.parseDefaultRouteInterface("route: writing to routing socket: not in table"))
    }

    func testParseAllNetworkServices() {
        let output = """
        An asterisk (*) denotes that a network service is disabled.
        USB 10/100 LAN
        Thunderbolt Bridge
        Wi-Fi
        *iPhone USB
        VPN (L2TP)

        """
        let entries = NetworkSetupParser.parseAllNetworkServices(output)
        XCTAssertEqual(entries, [
            NetworkServiceEntry(name: "USB 10/100 LAN", isEnabled: true),
            NetworkServiceEntry(name: "Thunderbolt Bridge", isEnabled: true),
            NetworkServiceEntry(name: "Wi-Fi", isEnabled: true),
            NetworkServiceEntry(name: "iPhone USB", isEnabled: false),
            NetworkServiceEntry(name: "VPN (L2TP)", isEnabled: true),
        ])
    }

    func testParseSocksProxy() {
        let on = NetworkSetupParser.parseSocksProxy("""
        Enabled: Yes
        Server: 127.0.0.1
        Port: 1080
        Authenticated Proxy Enabled: 0
        """)
        XCTAssertEqual(on, SocksProxySettings(enabled: true, server: "127.0.0.1", port: 1080))
        XCTAssertTrue(on.pointsTo())

        let off = NetworkSetupParser.parseSocksProxy("""
        Enabled: No
        Server: 127.0.0.1
        Port: 1080
        Authenticated Proxy Enabled: 0
        """)
        XCTAssertFalse(off.enabled)
        XCTAssertFalse(off.pointsTo())

        let other = NetworkSetupParser.parseSocksProxy("""
        Enabled: Yes
        Server: proxy.example.com
        Port: 1080
        """)
        XCTAssertFalse(other.pointsTo())

        let otherPort = NetworkSetupParser.parseSocksProxy("Enabled: Yes\nServer: 127.0.0.1\nPort: 9050\n")
        XCTAssertFalse(otherPort.pointsTo())

        let empty = NetworkSetupParser.parseSocksProxy("Enabled: No\nServer: \nPort: 0\n")
        XCTAssertEqual(empty, SocksProxySettings(enabled: false, server: "", port: 0))
    }

    func testParseLsofListeners() {
        let output = """
        p79990
        cciadpi
        u501
        f3
        p123
        cnode
        u501
        f20
        f21
        """
        let listeners = LsofParser.parseListeners(output)
        XCTAssertEqual(listeners, [
            PortListener(pid: 79990, command: "ciadpi", uid: 501),
            PortListener(pid: 123, command: "node", uid: 501),
        ])
        XCTAssertTrue(listeners[0].isCiadpi)
        XCTAssertFalse(listeners[1].isCiadpi)
        XCTAssertEqual(LsofParser.parseListeners(""), [])
        // n satırı yok: adres bilinmiyor, loopback sayılmaz
        XCTAssertFalse(listeners[0].isLoopbackOnly)
    }

    func testLsofListenerAddressesAndLoopback() {
        // v1.0.0: -i olmadan başlatılan ciadpi tüm arayüzlerde dinler (LAN'a açık)
        let wildcard = LsofParser.parseListeners("p1\ncciadpi\nu501\nf3\nn*:1080")
        XCTAssertEqual(wildcard.first?.addresses, ["*:1080"])
        XCTAssertEqual(wildcard.first?.isLoopbackOnly, false)

        XCTAssertEqual(LsofParser.parseListeners("p1\ncciadpi\nu501\nf3\nn127.0.0.1:1080").first?.isLoopbackOnly, true)
        XCTAssertEqual(LsofParser.parseListeners("p1\ncciadpi\nu501\nf3\nn[::1]:1080").first?.isLoopbackOnly, true)

        // Aynı PID hem loopback hem joker adreste: açık sayılır, adresler birleşir
        let mixed = LsofParser.parseListeners("p1\ncciadpi\nu501\nf3\nn127.0.0.1:1080\nf4\nn*:1080")
        XCTAssertEqual(mixed.count, 1)
        XCTAssertEqual(mixed[0].addresses, ["127.0.0.1:1080", "*:1080"])
        XCTAssertFalse(mixed[0].isLoopbackOnly)

        // Başka bir arayüz adresi de açık sayılır
        XCTAssertEqual(LsofParser.parseListeners("p1\ncciadpi\nn192.168.1.5:1080").first?.isLoopbackOnly, false)

        // Adres yok: bilinmiyor
        XCTAssertEqual(LsofParser.parseListeners("p1\ncciadpi\nu501\nf3").first?.isLoopbackOnly, false)
    }

    func testProxyCommandsQuoteServiceNames() {
        let disable = SystemProxyService.disableCommand(services: ["Wi-Fi", "USB 10/100 LAN", "Ali's (Ev)"])
        XCTAssertEqual(
            disable,
            "/usr/sbin/networksetup -setsocksfirewallproxystate 'Wi-Fi' off ; "
            + "/usr/sbin/networksetup -setsocksfirewallproxystate 'USB 10/100 LAN' off ; "
            + "/usr/sbin/networksetup -setsocksfirewallproxystate 'Ali'\\''s (Ev)' off"
        )
        let enable = SystemProxyService.enableCommand(service: "Wi-Fi")
        XCTAssertEqual(
            enable,
            "/usr/sbin/lsof -a -nP -iTCP:1080 -sTCP:LISTEN -c ciadpi -t >/dev/null 2>&1"
            + " || { echo SPLITWIRE_NO_LISTENER >&2; exit 3; } ; "
            + "/usr/sbin/networksetup -setsocksfirewallproxy 'Wi-Fi' '127.0.0.1' 1080 && "
            + "/usr/sbin/networksetup -setsocksfirewallproxystate 'Wi-Fi' on"
        )
        XCTAssertTrue(SystemProxyService.enableCommand(service: "Wi-Fi", port: 41_873).contains("-iTCP:41873 "))
    }

    /// Proxy, ciadpi dinlemiyorsa açılmaz: denetim yalnızca lsof çalıştırır (networksetup'a ulaşılmaz).
    func testEnableCommandRefusesWithoutListener() throws {
        let command = SystemProxyService.enableCommand(service: "Wi-Fi", port: 1)
        // networksetup yerine zararsız bir işaretçi: denetim geçilseydi "REACHED" yazılırdı
        let probe = command.components(separatedBy: " ; ").first! + " ; echo REACHED"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", probe]
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 3)
        XCTAssertEqual(String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), "")
        XCTAssertTrue(String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .contains(SystemProxyError.noListenerMarker))
    }
}

final class ShellTests: XCTestCase {
    func testShellQuote() {
        XCTAssertEqual(Shell.shellQuote("abc"), "'abc'")
        XCTAssertEqual(Shell.shellQuote(""), "''")
        XCTAssertEqual(Shell.shellQuote("it's"), "'it'\\''s'")
        XCTAssertEqual(Shell.shellQuote("a b $(rm -rf ~) `x` \"q\""), "'a b $(rm -rf ~) `x` \"q\"'")
    }

    func testAppleScriptStringLiteral() {
        XCTAssertEqual(Shell.appleScriptStringLiteral("abc"), "\"abc\"")
        XCTAssertEqual(Shell.appleScriptStringLiteral("say \"hi\""), "\"say \\\"hi\\\"\"")
        XCTAssertEqual(Shell.appleScriptStringLiteral("a\\b"), "\"a\\\\b\"")
        XCTAssertEqual(Shell.appleScriptStringLiteral("x' \\\" y"), "\"x' \\\\\\\" y\"")
    }

    func testPrivilegedScriptIncludesPrompt() {
        XCTAssertEqual(Shell.privilegedScript("echo 1", prompt: nil),
                       "do shell script \"echo 1\" with administrator privileges")
        XCTAssertEqual(Shell.privilegedScript("echo 1", prompt: "Neden \"x\""),
                       "do shell script \"echo 1\" with prompt \"Neden \\\"x\\\"\" with administrator privileges")
    }

    func testCleanOsascriptErrorJoinsCarriageReturns() {
        XCTAssertEqual(Shell.cleanOsascriptError("0:120: execution error: a\rb (4)\n", status: 1), "a\nb (4)")
    }

    func testRunCapturesOutputAndStatus() async throws {
        let result = try await Shell.run("/bin/sh", ["-c", "echo out; echo err 1>&2; exit 3"])
        XCTAssertEqual(result.status, 3)
        XCTAssertEqual(result.stdout, "out\n")
        XCTAssertEqual(result.stderr, "err\n")
        XCTAssertEqual(result.combinedOutput, "out\nerr\n")
        XCTAssertThrowsError(try result.checked())
    }

    func testRunResolvesBareCommandAndPassesArgsVerbatim() async throws {
        let result = try await Shell.run("echo", ["a b", "$HOME", "'q'"])
        XCTAssertEqual(result.stdout, "a b $HOME 'q'\n")
    }

    func testRunLargeOutputDoesNotDeadlock() async throws {
        // > 64KB on both pipes
        let result = try await Shell.bash("head -c 300000 /dev/zero | tr '\\\\0' a; head -c 300000 /dev/zero | tr '\\\\0' b 1>&2")
        XCTAssertEqual(result.stdout.count, 300000)
        XCTAssertEqual(result.stderr.count, 300000)
    }

    func testRunTimeout() async {
        do {
            _ = try await Shell.run("/bin/sleep", ["5"], timeout: 0.3)
            XCTFail("timeout bekleniyordu")
        } catch let error as ShellError {
            XCTAssertEqual(error, .timedOut(0.3))
        } catch {
            XCTFail("beklenmeyen hata \(error)")
        }
    }

    func testMissingExecutable() async {
        do {
            _ = try await Shell.run("definitely-not-a-command-xyz", [])
            XCTFail("hata bekleniyordu")
        } catch {
            XCTAssertEqual(error as? ShellError, .executableNotFound("definitely-not-a-command-xyz"))
        }
    }

    func testOsascriptErrorHelpers() {
        XCTAssertTrue(Shell.isUserCancelled("0:94: execution error: User canceled. (-128)"))
        XCTAssertFalse(Shell.isUserCancelled("0:94: execution error: boom (1)"))
        XCTAssertEqual(Shell.cleanOsascriptError("0:94: execution error: boom (1)\n", status: 1), "boom (1)")
        withAppLanguage(.turkish) {
            XCTAssertEqual(Shell.cleanOsascriptError("", status: 2), "Yönetici komutu başarısız oldu (çıkış kodu 2)")
        }
        withAppLanguage(.english) {
            XCTAssertEqual(Shell.cleanOsascriptError("", status: 2), "The administrator command failed (exit code 2)")
        }
    }

    func testLineRingBuffer() {
        let buffer = LineRingBuffer(capacity: 3)
        buffer.append("a\nb")
        XCTAssertEqual(buffer.snapshot, ["a", "b"])
        buffer.append("c\nd\ne\n")
        XCTAssertEqual(buffer.snapshot, ["bc", "d", "e"])
        buffer.append("partial")
        XCTAssertEqual(buffer.snapshot, ["d", "e", "partial"])
    }
}
