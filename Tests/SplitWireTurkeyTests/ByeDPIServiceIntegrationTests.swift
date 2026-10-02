import XCTest
@testable import SplitWireTurkey

/// Gerçek ciadpi ile yaşam döngüsü testi (127.0.0.1 üzerinde özel yüksek port).
/// ciadpi ikili dosyası yoksa atlanır. Sistem ayarlarına dokunmaz: SystemProxyService test
/// portuna yönelir, böylece gerçek 127.0.0.1:1080 proxy'si hiçbir zaman eşleşmez (parola penceresi açılmaz).
@MainActor
final class ByeDPIServiceIntegrationTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private let testPort = 41_873

    private var ciadpiPath: String? {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let candidates = [
            repo.appendingPathComponent("Sources/SplitWireTurkey/Resources/bin/ciadpi").path,
            repo.appendingPathComponent("byedpi/ciadpi").path,
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    override func setUp() async throws {
        suiteName = "SplitWireTurkeyIntegration-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        // Güvenlik: test portunda kalan ciadpi'yi öldür
        for listener in await ByeDPIService.listeners(port: testPort) where listener.isCiadpi {
            kill(listener.pid, SIGKILL)
        }
    }

    private func makeService() throws -> ByeDPIService {
        guard let path = ciadpiPath else { throw XCTSkip("ciadpi bulunamadı") }
        return ByeDPIService(defaults: defaults, systemProxy: SystemProxyService(port: testPort),
                             port: testPort, ciadpiPath: path)
    }

    func testNonDefaultPortNeverTargetsRealSystemProxy() {
        let service = ByeDPIService(defaults: defaults, port: testPort, ciadpiPath: "/nonexistent")
        XCTAssertEqual(service.systemProxy.port, testPort)
        XCTAssertFalse(service.systemProxy === SystemProxyService.shared)
    }

    /// "Özel Parametreleri Düzenle" kullanıcının kaydettiği özel parametreleri ezmez.
    func testEditAsCustomKeepsUserCustomArgs() {
        defaults.set("-d 1 -s 1+s --tlsrec 3+s", forKey: ByeDPIService.customArgsDefaultsKey)
        let service = ByeDPIService(defaults: defaults, port: testPort, ciadpiPath: "/nonexistent")
        service.selectPreset("Standart")
        service.editAsCustom()
        XCTAssertEqual(service.currentPreset, ByeDPIPresets.customID)
        XCTAssertEqual(service.customArgs, "-d 1 -s 1+s --tlsrec 3+s")
        XCTAssertEqual(defaults.string(forKey: ByeDPIService.customArgsDefaultsKey), "-d 1 -s 1+s --tlsrec 3+s")
    }

    /// Özel parametreler boş ya da bir hazır presetle aynıysa mevcut yöntemle doldurulur.
    func testEditAsCustomPrefillsUntouchedArgs() {
        let service = ByeDPIService(defaults: defaults, port: testPort, ciadpiPath: "/nonexistent")
        XCTAssertEqual(service.customArgs, ByeDPIService.defaultCustomArgs)
        service.selectPreset("Split 1")
        service.editAsCustom()
        XCTAssertEqual(service.customArgs, "-s 1 --tlsrec 1+s")

        // Başka bir hazır presetten tekrar: yine doldurulur
        service.selectPreset("OOB")
        service.editAsCustom()
        XCTAssertEqual(service.customArgs, "-o 1 --auto=torst")

        service.customArgs = "   "
        service.selectPreset("Disorder")
        service.editAsCustom()
        XCTAssertEqual(service.customArgs, "--disorder 1 --auto=torst --tlsrec 1+s")
    }

    /// Boş Custom seçilince çalışan ciadpi öldürülmez (yeniden başlatma başarısız olur ve
    /// sistem proxy ölü bir porta işaret ederdi, #14).
    func testSelectingEmptyCustomKeepsRunningProcess() async throws {
        let service = try makeService()
        service.selectPreset("Split 1")
        let started = await service.start()
        XCTAssertTrue(started, service.statusMessage)
        let pid = await ByeDPIService.listeners(port: testPort).first(where: \.isCiadpi)?.pid

        service.customArgs = ""
        service.selectPreset(ByeDPIPresets.customID)
        XCTAssertEqual(service.currentPreset, ByeDPIPresets.customID)
        XCTAssertFalse(service.isProcessing)
        XCTAssertEqual(service.statusKind, .warning)
        XCTAssertTrue(service.isRunning)
        XCTAssertEqual(service.runningPreset, "Split 1")
        try await Task.sleep(nanoseconds: 300_000_000)
        let after = await ByeDPIService.listeners(port: testPort).filter(\.isCiadpi)
        XCTAssertEqual(after.map(\.pid), pid.map { [$0] } ?? [])
        // Bizim süreç yalnızca loopback'te dinler
        XCTAssertEqual(after.first?.isLoopbackOnly, true)
        XCTAssertFalse(service.isExposedToNetwork)

        await service.stop()
        XCTAssertFalse(service.isRunning)
    }

    func testStartRestartStopLifecycle() async throws {
        let service = try makeService()
        let initial = await ByeDPIService.listeners(port: testPort)
        XCTAssertTrue(initial.isEmpty, "test portu boş olmalı")

        service.selectPreset("Split 1")
        let started = await service.start()
        XCTAssertTrue(started, service.statusMessage)
        XCTAssertTrue(service.isRunning)
        XCTAssertFalse(service.isExternallyStarted)
        XCTAssertEqual(service.runningPreset, "Split 1")
        XCTAssertEqual(service.runningArgs, "-i 127.0.0.1 -p \(testPort) -G -s 1 --tlsrec 1+s")
        XCTAssertEqual(service.statusKind, .success)

        let listeners = await ByeDPIService.listeners(port: testPort)
        XCTAssertEqual(listeners.filter(\.isCiadpi).count, 1)

        // Preset değişimi çalışırken yeniden başlatır
        service.selectPreset("OOB")
        try await waitUntil { service.runningPreset == "OOB" && !service.isProcessing }
        XCTAssertEqual(service.runningArgs, "-i 127.0.0.1 -p \(testPort) -G -o 1 --auto=torst")
        let afterRestart = await ByeDPIService.listeners(port: testPort)
        XCTAssertEqual(afterRestart.filter(\.isCiadpi).count, 1)

        // Durdur: SIGTERM yok sayılır, SIGKILL ile kapanmalı
        await service.stop()
        XCTAssertFalse(service.isRunning)
        XCTAssertNil(service.runningArgs)
        let afterStop = await ByeDPIService.listeners(port: testPort)
        XCTAssertTrue(afterStop.isEmpty)
    }

    func testUnexpectedExitIsDetected() async throws {
        let service = try makeService()
        let started = await service.start()
        XCTAssertTrue(started, service.statusMessage)
        guard let pid = await ByeDPIService.listeners(port: testPort).first(where: \.isCiadpi)?.pid else {
            return XCTFail("ciadpi dinlemiyor")
        }
        kill(pid, SIGKILL)
        try await waitUntil { !service.isRunning }
        XCTAssertEqual(service.statusKind, .error)
        XCTAssertNil(service.runningArgs)
    }

    func testOrphanCiadpiIsAdoptedAndStopped() async throws {
        let service = try makeService()
        let orphan = Process()
        orphan.executableURL = URL(fileURLWithPath: ciadpiPath!)
        orphan.arguments = ["-i", "127.0.0.1", "-p", String(testPort), "-r", "1+s"]
        orphan.standardOutput = FileHandle.nullDevice
        orphan.standardError = FileHandle.nullDevice
        try orphan.run()
        defer { if orphan.isRunning { kill(orphan.processIdentifier, SIGKILL) } }
        try await Task.sleep(nanoseconds: 400_000_000)

        await service.refreshStatus()
        XCTAssertTrue(service.isRunning)
        XCTAssertTrue(service.isExternallyStarted)
        XCTAssertNotNil(service.runningArgs)
        XCTAssertFalse(service.isExposedToNetwork)

        await service.stop()
        XCTAssertFalse(service.isRunning)
        try await waitUntil { !orphan.isRunning }
    }

    /// Her hazır presetin son argv'si (-i 127.0.0.1 -p <port> -G eklenmiş) gerçek ciadpi tarafından kabul edilir,
    /// süreç yalnızca 127.0.0.1 üzerinde dinler (LAN'a açık SOCKS proxy olmaz) ve aynı port hem SOCKS5
    /// hem HTTP CONNECT el sıkışmasını kabul eder (sistem HTTPS proxy'si için, #13).
    func testEveryPresetStartsAndListensOnLoopbackOnly() async throws {
        guard let path = ciadpiPath else { throw XCTSkip("ciadpi bulunamadı") }
        for (index, preset) in ByeDPIPresets.builtIn.enumerated() {
            let port = 18_600 + index
            let tokens = ByeDPIArguments.build(from: preset.args, port: port)
            XCTAssertEqual(Array(tokens.prefix(5)), ["-i", "127.0.0.1", "-p", String(port), "-G"], preset.id)

            let errorPipe = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = tokens
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errorPipe
            try process.run()
            defer {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit()
            }

            try await Task.sleep(nanoseconds: 500_000_000)
            guard process.isRunning else {
                let stderr = String(decoding: errorPipe.fileHandleForReading.availableData, as: UTF8.self)
                XCTFail("\(preset.id): ciadpi hemen kapandı: \(stderr)")
                continue
            }

            let result = try await Shell.run(
                "/usr/sbin/lsof",
                ["-nP", "-a", "-p", String(process.processIdentifier), "-iTCP", "-sTCP:LISTEN", "-F", "n"],
                timeout: 10
            )
            let addresses = result.stdout
                .split(separator: "\n")
                .filter { $0.hasPrefix("n") }
                .map { String($0.dropFirst()) }
            XCTAssertEqual(addresses, ["127.0.0.1:\(port)"], preset.id)

            // SOCKS5 selamlaşması: [ver 5, 1 yöntem, kimlik doğrulamasız] -> [5, 0]
            let socksReply = Self.exchange(port: port, request: [0x05, 0x01, 0x00], maxBytes: 2)
            XCTAssertEqual(socksReply, [0x05, 0x00], "\(preset.id): SOCKS5")

            // HTTP CONNECT: ciadpi bağlantıyı kapatmak yerine bir HTTP durum satırıyla yanıt vermeli
            // (hedefe ulaşılırsa 200, ulaşılamazsa 503). -G olmadan yanıt boş gelir.
            let connect = "CONNECT 127.0.0.1:9 HTTP/1.1\r\nHost: 127.0.0.1:9\r\n\r\n"
            let httpReply = String(decoding: Self.exchange(port: port, request: Array(connect.utf8), maxBytes: 64),
                                   as: UTF8.self)
            XCTAssertTrue(httpReply.hasPrefix("HTTP/1.1 "), "\(preset.id): HTTP CONNECT yanıtı: \(httpReply.debugDescription)")
        }
    }

    /// 127.0.0.1:<port>'a bağlanır, isteği gönderir ve en fazla `maxBytes` bayt yanıt okur (2 sn zaman aşımı).
    nonisolated private static func exchange(port: Int, request: [UInt8], maxBytes: Int) -> [UInt8] {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return [] }
        defer { close(fd) }
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(port).bigEndian)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else { return [] }
        guard request.withUnsafeBytes({ send(fd, $0.baseAddress, $0.count, 0) }) == request.count else { return [] }

        var reply: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: maxBytes)
        while reply.count < maxBytes {
            let n = buffer.withUnsafeMutableBytes { recv(fd, $0.baseAddress, maxBytes - reply.count, 0) }
            guard n > 0 else { break }
            reply.append(contentsOf: buffer[0..<n])
            if reply.count >= 2, reply.starts(with: [0x05]) { break }
            if reply.contains(0x0A) { break }  // HTTP durum satırı tamamlandı
        }
        return reply
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("koşul zaman aşımına uğradı")
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
