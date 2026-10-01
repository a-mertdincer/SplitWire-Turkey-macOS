import Foundation

/// Bir alt sürecin (subprocess) sonucu.
struct ShellResult: Sendable, Equatable {
    let status: Int32
    let stdout: String
    let stderr: String

    var succeeded: Bool { status == 0 }

    /// stdout + stderr (ikisi de doluysa aralarında satır sonu ile).
    var combinedOutput: String {
        switch (stdout.isEmpty, stderr.isEmpty) {
        case (true, true): return ""
        case (false, true): return stdout
        case (true, false): return stderr
        case (false, false):
            return stdout.hasSuffix("\n") ? stdout + stderr : stdout + "\n" + stderr
        }
    }

    /// Çıkış kodu 0 değilse `ShellError.nonZeroExit` fırlatır.
    @discardableResult
    func checked() throws -> ShellResult {
        guard succeeded else {
            throw ShellError.nonZeroExit(status: status, output: combinedOutput)
        }
        return self
    }
}

enum ShellError: LocalizedError, Equatable {
    case executableNotFound(String)
    case launchFailed(String)
    case timedOut(TimeInterval)
    case nonZeroExit(status: Int32, output: String)
    /// Kullanıcı yönetici parolası penceresini iptal etti (osascript hata -128).
    case userCancelled
    case privilegedCommandFailed(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let name):
            return L("Komut bulunamadı: \(name)", "Command not found: \(name)")
        case .launchFailed(let message):
            return L("Komut başlatılamadı: \(message)", "Could not start the command: \(message)")
        case .timedOut(let seconds):
            let s = Int(seconds)
            return L("Komut zaman aşımına uğradı (\(s) sn)", "The command timed out (\(s) s)")
        case .nonZeroExit(let status, let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? L("Komut başarısız oldu (çıkış kodu \(status))", "The command failed (exit code \(status))")
                : trimmed
        case .userCancelled:
            return L("Yönetici izni verilmedi (iptal edildi)", "Administrator permission was not given (cancelled)")
        case .privilegedCommandFailed(let message):
            return message
        }
    }
}

/// Uygulama genelinde kullanılan süreç çalıştırma yardımcıları.
///
/// - Tüm çağrılar ana iş parçacığı (MainActor) dışında çalışır; UI donmaz.
/// - stdout ve stderr eşzamanlı okunur (64KB pipe tamponu kilitlenmesi olmaz).
/// - Yol veya kullanıcı girdisi içeren komutlar için `run(_:_:)` (kabuksuz, argüman dizisi) tercih edilmeli.
enum Shell {
    /// GUI uygulamaları minimal bir PATH ile başlar; çıplak komut adları bu dizinlerde aranır.
    static let searchPaths = [
        "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        "/opt/homebrew/bin", "/opt/homebrew/sbin",
        "/usr/local/bin", "/usr/local/sbin",
    ]

    /// Bir programı argüman dizisi ile (kabuk OLMADAN) çalıştırır.
    /// - Parameters:
    ///   - executable: Mutlak yol ya da `searchPaths` içinde aranacak komut adı (ör. "lsof").
    ///   - arguments: Argümanlar (kaçış gerekmez).
    ///   - environment: Verilirse sürecin ortamı bununla DEĞİŞTİRİLİR (birleştirme yapılmaz).
    ///   - timeout: Süre aşılırsa süreç öldürülür ve `ShellError.timedOut` fırlatılır.
    /// - Returns: Çıkış kodu sıfır olmasa bile sonuç döner; hata için `checked()` kullanın.
    static func run(
        _ executable: String,
        _ arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> ShellResult {
        let path = try resolveExecutable(executable)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try runBlocking(path, arguments, environment: environment, timeout: timeout)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Sabit (kullanıcı girdisi İÇERMEYEN) kabuk boru hatları için `/bin/bash -c`.
    /// Değişken parçalar varsa `shellQuote` ile kaçırın veya `run` kullanın.
    static func bash(_ script: String, timeout: TimeInterval? = nil) async throws -> ShellResult {
        try await run("/bin/bash", ["-c", script], timeout: timeout)
    }

    /// POSIX tek tırnak kaçışı: `it's` -> `'it'\''s'`.
    static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// AppleScript string literali: çift tırnak içine alır, `\` ve `"` karakterlerini kaçırır.
    static func appleScriptStringLiteral(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }

    /// Bir kabuk komutunu yönetici yetkisiyle çalıştırır
    /// (`osascript -e 'do shell script ... with administrator privileges'`).
    ///
    /// Her çağrı bir parola penceresi gösterir; birden çok komutu tek çağrıda `&&` / `;` ile birleştirin.
    /// Komut içindeki değişken parçalar `shellQuote` ile kaçırılmış olmalıdır.
    /// - Throws: Kullanıcı iptal ederse `ShellError.userCancelled`, diğer hatalarda
    ///   `ShellError.privilegedCommandFailed`.
    /// - Returns: Komutun stdout çıktısı (sondaki satır sonu kırpılmış).
    /// - Parameter prompt: Parola penceresinde gösterilecek açıklama (yoksa macOS
    ///   "osascript değişiklik yapmak istiyor" gibi anlamsız bir metin gösterir).
    @discardableResult
    static func runPrivileged(_ shellCommand: String, prompt: String? = nil,
                              timeout: TimeInterval? = nil) async throws -> String {
        let script = privilegedScript(shellCommand, prompt: prompt)
        let result = try await run("/usr/bin/osascript", ["-e", script], timeout: timeout)
        if result.succeeded {
            // do shell script satır sonlarını \r'ye çevirir
            return result.stdout
                .replacingOccurrences(of: "\r", with: "\n")
                .trimmingCharacters(in: .newlines)
        }
        if isUserCancelled(result.stderr) {
            throw ShellError.userCancelled
        }
        throw ShellError.privilegedCommandFailed(cleanOsascriptError(result.stderr, status: result.status))
    }

    // MARK: - Internal

    /// `do shell script "…" [with prompt "…"] with administrator privileges`
    static func privilegedScript(_ shellCommand: String, prompt: String?) -> String {
        var script = "do shell script \(appleScriptStringLiteral(shellCommand))"
        if let prompt, !prompt.isEmpty {
            script += " with prompt \(appleScriptStringLiteral(prompt))"
        }
        return script + " with administrator privileges"
    }

    static func isUserCancelled(_ osascriptStderr: String) -> Bool {
        osascriptStderr.contains("(-128)")
    }

    /// "0:120: execution error: Hata metni (1)" -> "Hata metni (1)"
    static func cleanOsascriptError(_ stderr: String, status: Int32) -> String {
        // do shell script satırları \r ile birleştirir
        var message = stderr
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = message.range(of: "execution error: ") {
            message = String(message[range.upperBound...])
        }
        return message.isEmpty
            ? L("Yönetici komutu başarısız oldu (çıkış kodu \(status))",
                "The administrator command failed (exit code \(status))")
            : message
    }

    static func resolveExecutable(_ executable: String) throws -> String {
        if executable.contains("/") {
            guard FileManager.default.isExecutableFile(atPath: executable) else {
                throw ShellError.executableNotFound(executable)
            }
            return executable
        }
        for dir in searchPaths {
            let candidate = (dir as NSString).appendingPathComponent(executable)
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        throw ShellError.executableNotFound(executable)
    }

    /// Engelleyici çalıştırma — yalnızca arka plan kuyruğundan çağrılır.
    private static func runBlocking(
        _ path: String,
        _ arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval?
    ) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        if let environment {
            process.environment = environment
        }
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        // Sürecin bitişi pipe'ların kapanmasından bağımsız beklenir: alt süreç
        // stdout/stderr'i erken kapatıp asılı kalırsa da zaman aşımı uygulanır.
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(error.localizedDescription)
        }

        // İki boruyu eşzamanlı boşalt: biri dolarsa süreç kilitlenmesin.
        let group = DispatchGroup()
        let collector = OutputCollector()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            collector.setStdout(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            collector.setStderr(stderrPipe.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }

        var didTimeOut = false
        let deadline: DispatchTime = timeout.map { .now() + $0 } ?? .distantFuture
        if exited.wait(timeout: deadline) == .timedOut {
            didTimeOut = true
            let pid = process.processIdentifier
            process.terminate()
            if exited.wait(timeout: .now() + 1) == .timedOut {
                kill(pid, SIGKILL)
                _ = exited.wait(timeout: .now() + 2)
            }
        }

        // Süreç bitti; kalan çıktıyı topla. Torun süreçler boruyu açık tutuyorsa
        // sonsuza kadar bekleme (okuyucular arka planda kendiliğinden biter).
        _ = group.wait(timeout: .now() + (didTimeOut ? 2 : 10))

        if didTimeOut, let timeout {
            throw ShellError.timedOut(timeout)
        }

        return ShellResult(
            status: process.terminationStatus,
            stdout: String(decoding: collector.stdout, as: UTF8.self),
            stderr: String(decoding: collector.stderr, as: UTF8.self)
        )
    }
}

/// İki okuma kuyruğundan gelen veriyi güvenli şekilde toplar.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _stdout = Data()
    private var _stderr = Data()

    func setStdout(_ data: Data) { lock.lock(); _stdout = data; lock.unlock() }
    func setStderr(_ data: Data) { lock.lock(); _stderr = data; lock.unlock() }
    var stdout: Data { lock.lock(); defer { lock.unlock() }; return _stdout }
    var stderr: Data { lock.lock(); defer { lock.unlock() }; return _stderr }
}
