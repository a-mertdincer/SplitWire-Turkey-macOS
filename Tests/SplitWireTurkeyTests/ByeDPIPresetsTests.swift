import XCTest
@testable import SplitWireTurkey

final class ByeDPIPresetsTests: XCTestCase {
    func testPresetOrderAndArgs() {
        let expected: [(String, String)] = [
            ("Standart", "-r 1+s"),
            ("Split 1", "-s 1 --tlsrec 1+s"),
            ("Split 2", "-s 2 --tlsrec 1+s"),
            ("Disorder", "--disorder 1 --auto=torst --tlsrec 1+s"),
            ("Disorder SNI", "-d 1+s --tlsrec 1+s"),
            ("OOB", "-o 1 --auto=torst"),
            ("OOB SNI", "-o 1+s --tlsrec 1+s"),
            ("Split + Disorder", "-s 1+s -d 3+s --tlsrec 1+s"),
        ]
        XCTAssertEqual(ByeDPIPresets.builtIn.map(\.id), expected.map(\.0))
        XCTAssertEqual(ByeDPIPresets.builtIn.map(\.args), expected.map(\.1))
        XCTAssertEqual(ByeDPIPresets.all.map(\.id), expected.map(\.0) + ["Custom"])
        XCTAssertEqual(ByeDPIPresets.all.last?.isCustom, true)
    }

    func testNoFakePresets() {
        for preset in ByeDPIPresets.all {
            XCTAssertFalse(preset.id.lowercased().contains("fake"), preset.id)
            let tokens = ByeDPIArguments.tokenize(preset.args)
            XCTAssertFalse(tokens.contains("--fake"), preset.id)
            XCTAssertFalse(tokens.contains("-f"), preset.id)
        }
    }

    func testCustomUsesCustomArgs() {
        XCTAssertEqual(ByeDPIPresets.args(for: "Custom", customArgs: "-s 3 -r 2"), "-s 3 -r 2")
        XCTAssertEqual(ByeDPIPresets.args(for: "Custom", customArgs: ""), "")
        XCTAssertEqual(ByeDPIPresets.args(for: "OOB", customArgs: "-s 3"), "-o 1 --auto=torst")
        // Bilinmeyen preset -> Standart
        XCTAssertEqual(ByeDPIPresets.args(for: "Fake -1", customArgs: "-s 3"), "-r 1+s")
    }

    func testMigration() {
        XCTAssertEqual(ByeDPIPresets.migrate(stored: nil, legacy: nil), "Standart")
        XCTAssertEqual(ByeDPIPresets.migrate(stored: "OOB", legacy: "Split 1"), "OOB")
        XCTAssertEqual(ByeDPIPresets.migrate(stored: nil, legacy: "Split 2"), "Split 2")
        XCTAssertEqual(ByeDPIPresets.migrate(stored: nil, legacy: "Fake -1"), "Standart")
        XCTAssertEqual(ByeDPIPresets.migrate(stored: "Fake 1", legacy: nil), "Standart")
        XCTAssertEqual(ByeDPIPresets.migrate(stored: "Custom", legacy: nil), "Custom")
        XCTAssertEqual(ByeDPIPresets.migrate(stored: "Bogus", legacy: "Disorder"), "Standart")
    }

    @MainActor
    func testServiceLoadsMigratedPresetAndCustomArgs() {
        let suite = "SplitWireTurkeyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("Split 1", forKey: "menuBarPreset")
        defaults.set("-s 5\n--tlsrec 1+s", forKey: "byedpiCustomArgs")
        let service = ByeDPIService(defaults: defaults, systemProxy: SystemProxyService())
        XCTAssertEqual(service.currentPreset, "Split 1")
        XCTAssertEqual(defaults.string(forKey: "byedpiPreset"), "Split 1")
        XCTAssertEqual(service.customArgs, "-s 5\n--tlsrec 1+s")

        service.selectPreset("Custom")
        XCTAssertEqual(defaults.string(forKey: "byedpiPreset"), "Custom")
        XCTAssertEqual(service.args(for: service.currentPreset), "-s 5\n--tlsrec 1+s")

        service.customArgs = "-r 2"
        XCTAssertEqual(defaults.string(forKey: "byedpiCustomArgs"), "-r 2")

        // Bilinmeyen preset seçimi yok sayılır
        service.selectPreset("Fake -1")
        XCTAssertEqual(service.currentPreset, "Custom")
    }

    @MainActor
    func testRemovedLegacyPresetFallsBackToStandart() {
        let suite = "SplitWireTurkeyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("Fake -1", forKey: "menuBarPreset")
        let service = ByeDPIService(defaults: defaults, systemProxy: SystemProxyService())
        XCTAssertEqual(service.currentPreset, "Standart")
        XCTAssertEqual(service.customArgs, "-r 1+s")
    }

    @MainActor
    func testEditAsCustomPrefillsArgs() {
        let suite = "SplitWireTurkeyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = ByeDPIService(defaults: defaults, systemProxy: SystemProxyService())
        service.selectPreset("OOB SNI")
        service.editAsCustom()
        XCTAssertEqual(service.currentPreset, "Custom")
        XCTAssertEqual(service.customArgs, "-o 1+s --tlsrec 1+s")
    }
}

final class ByeDPIArgumentsTests: XCTestCase {
    func testTokenizeWhitespaceAndNewlines() {
        XCTAssertEqual(ByeDPIArguments.tokenize("  -s 1\n--tlsrec\t1+s \r\n "), ["-s", "1", "--tlsrec", "1+s"])
        XCTAssertEqual(ByeDPIArguments.tokenize(""), [])
        XCTAssertEqual(ByeDPIArguments.tokenize(" \n\t "), [])
    }

    func testTokenizeQuotedTokens() {
        XCTAssertEqual(
            ByeDPIArguments.tokenize(#"--proxy-server="socks5://127.0.0.1:1080" --user-data-dir="/tmp/a b""#),
            ["--proxy-server=socks5://127.0.0.1:1080", "--user-data-dir=/tmp/a b"]
        )
        XCTAssertEqual(ByeDPIArguments.tokenize(#""a b" c"#), ["a b", "c"])
        XCTAssertEqual(ByeDPIArguments.tokenize(#"x "" y"#), ["x", "", "y"])
        XCTAssertEqual(ByeDPIArguments.tokenize("'single quoted' z"), ["single quoted", "z"])
    }

    func testBuildInjectsIPAndPort() {
        XCTAssertEqual(
            ByeDPIArguments.build(from: "-r 1+s"),
            ["-i", "127.0.0.1", "-p", "1080", "-r", "1+s"]
        )
        XCTAssertEqual(ByeDPIArguments.build(from: ""), ["-i", "127.0.0.1", "-p", "1080"])
    }

    func testBuildRespectsExistingIPAndPort() {
        XCTAssertEqual(
            ByeDPIArguments.build(from: "-i 0.0.0.0 -s 1"),
            ["-i", "0.0.0.0", "-p", "1080", "-s", "1"]
        )
        XCTAssertEqual(
            ByeDPIArguments.build(from: "--ip=127.0.0.1 --port 2080 -s 1"),
            ["--ip=127.0.0.1", "--port", "2080", "-s", "1"]
        )
        XCTAssertEqual(
            ByeDPIArguments.build(from: "-p 1081 -r 1+s"),
            ["-i", "127.0.0.1", "-p", "1081", "-r", "1+s"]
        )
        XCTAssertEqual(
            ByeDPIArguments.build(from: "--port=1090\n--ip 127.0.0.1"),
            ["--port=1090", "--ip", "127.0.0.1"]
        )
        XCTAssertTrue(ByeDPIArguments.containsPort(["-p1090"]))
        XCTAssertTrue(ByeDPIArguments.containsListenIP(["-i127.0.0.1"]))
        // Benzer ama farklı uzun seçenekler eşleşmemeli
        XCTAssertFalse(ByeDPIArguments.containsListenIP(["--ipset", "x"]))
        XCTAssertFalse(ByeDPIArguments.containsPort(["--pf", "443", "--proto", "tls"]))
    }

    func testCustomArgsMultilineBuild() {
        let args = ByeDPIPresets.args(for: "Custom", customArgs: "-s 1+s\n-d 3+s\n--tlsrec 1+s")
        XCTAssertEqual(
            ByeDPIArguments.build(from: args),
            ["-i", "127.0.0.1", "-p", "1080", "-s", "1+s", "-d", "3+s", "--tlsrec", "1+s"]
        )
    }

    func testDisplayString() {
        XCTAssertEqual(ByeDPIArguments.displayString(["-i", "127.0.0.1", "a b"]), #"-i 127.0.0.1 "a b""#)
    }
}
