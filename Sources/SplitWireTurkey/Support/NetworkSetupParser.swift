import Foundation

/// `networksetup -listnetworkserviceorder` içindeki bir servis.
struct NetworkServiceInfo: Equatable {
    /// Servis adı (networksetup'ın beklediği ad, ör. "Wi-Fi", "USB 10/100 LAN").
    let name: String
    /// Donanım portu (ör. "Wi-Fi").
    let hardwarePort: String?
    /// BSD aygıt adı (ör. "en0"); yoksa nil.
    let device: String?
    let isEnabled: Bool
}

/// `networksetup -listallnetworkservices` içindeki bir satır.
struct NetworkServiceEntry: Equatable {
    let name: String
    let isEnabled: Bool
}

/// `networksetup -getsocksfirewallproxy <servis>` çıktısı.
struct SocksProxySettings: Equatable {
    let enabled: Bool
    let server: String
    let port: Int?

    /// Bu ayar bizim ByeDPI proxy'mizi mi gösteriyor (açık + 127.0.0.1:1080)?
    func pointsTo(host: String = ByeDPIArguments.defaultHost, port: Int = ByeDPIArguments.defaultPort) -> Bool {
        enabled && server == host && self.port == port
    }
}

/// `route`/`networksetup` çıktıları için saf ayrıştırıcılar (birim testli).
enum NetworkSetupParser {
    /// `route -n get default` çıktısından arayüz adı ("interface: en0" -> "en0").
    static func parseDefaultRouteInterface(_ output: String) -> String? {
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("interface:") {
                let value = line.dropFirst("interface:".count).trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    /// `networksetup -listnetworkserviceorder` çıktısını ayrıştırır.
    ///
    ///     An asterisk (*) denotes that a network service is disabled.
    ///     (1) Wi-Fi
    ///     (Hardware Port: Wi-Fi, Device: en0)
    ///
    ///     (*) USB LAN
    ///     (Hardware Port: USB 10/100/1000 LAN, Device: en7)
    static func parseServiceOrder(_ output: String) -> [NetworkServiceInfo] {
        var result: [NetworkServiceInfo] = []
        var pendingName: String?
        var pendingEnabled = true

        func flushPending(port: String?, device: String?) {
            if let name = pendingName {
                result.append(NetworkServiceInfo(name: name, hardwarePort: port, device: device, isEnabled: pendingEnabled))
            }
            pendingName = nil
        }

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("(") else { continue }

            if line.hasPrefix("(Hardware Port:") {
                guard pendingName != nil else { continue }
                var body = String(line.dropFirst("(Hardware Port:".count))
                if body.hasSuffix(")") { body.removeLast() }
                var port: String = body
                var device: String?
                if let range = body.range(of: ", Device:", options: .backwards) {
                    port = String(body[..<range.lowerBound])
                    let dev = body[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    device = dev.isEmpty ? nil : dev
                }
                let trimmedPort = port.trimmingCharacters(in: .whitespaces)
                flushPending(port: trimmedPort.isEmpty ? nil : trimmedPort, device: device)
                continue
            }

            // "(1) Wi-Fi" veya "(*) Disabled Service"
            guard let close = line.firstIndex(of: ")") else { continue }
            let marker = line[line.index(after: line.startIndex)..<close]
            guard marker == "*" || (!marker.isEmpty && marker.allSatisfy(\.isNumber)) else { continue }
            let name = line[line.index(after: close)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            // Donanım satırı gelmeden yeni servis başladıysa öncekini aygıtsız ekle
            flushPending(port: nil, device: nil)
            pendingName = name
            pendingEnabled = marker != "*"
        }
        flushPending(port: nil, device: nil)
        return result
    }

    /// Aygıt adına (en0) karşılık gelen servis adını bulur; etkin servisler önceliklidir.
    static func serviceName(forDevice device: String, in services: [NetworkServiceInfo]) -> String? {
        let matches = services.filter { $0.device == device }
        return (matches.first { $0.isEnabled } ?? matches.first)?.name
    }

    /// `networksetup -listallnetworkservices` çıktısı. İlk açıklama satırı atlanır,
    /// başındaki "*" (devre dışı servis) ayıklanır.
    static func parseAllNetworkServices(_ output: String) -> [NetworkServiceEntry] {
        var entries: [NetworkServiceEntry] = []
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("An asterisk") { continue }
            if line.hasPrefix("*") {
                let name = line.dropFirst().trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { entries.append(NetworkServiceEntry(name: name, isEnabled: false)) }
            } else {
                entries.append(NetworkServiceEntry(name: line, isEnabled: true))
            }
        }
        return entries
    }

    /// `networksetup -getsocksfirewallproxy <servis>` çıktısı:
    ///
    ///     Enabled: Yes
    ///     Server: 127.0.0.1
    ///     Port: 1080
    ///     Authenticated Proxy Enabled: 0
    static func parseSocksProxy(_ output: String) -> SocksProxySettings {
        var enabled = false
        var server = ""
        var port: Int?
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "Enabled": enabled = value.caseInsensitiveCompare("Yes") == .orderedSame
            case "Server": server = value
            case "Port": port = Int(value)
            default: break
            }
        }
        return SocksProxySettings(enabled: enabled, server: server, port: port)
    }
}

/// `lsof -nP +c 0 -iTCP:<port> -sTCP:LISTEN -F pcun` çıktısındaki bir dinleyici süreç.
struct PortListener: Equatable {
    let pid: Int32
    let command: String
    let uid: UInt32?
    /// Dinlenen yerel adresler (ör. "127.0.0.1:1080", "*:1080", "[::1]:1080").
    var addresses: [String] = []

    var isCiadpi: Bool { command == "ciadpi" }

    /// Yalnızca loopback (127.x / ::1) üzerinde mi dinliyor? Adres bilinmiyorsa false.
    /// v1.0.0 ciadpi'yi `-i` olmadan (0.0.0.0, LAN'a açık) başlatıyordu.
    var isLoopbackOnly: Bool {
        guard !addresses.isEmpty else { return false }
        return addresses.allSatisfy { address in
            guard let colon = address.lastIndex(of: ":") else { return false }
            let host = address[..<colon]
            return host.hasPrefix("127.") || host == "[::1]"
        }
    }
}

enum LsofParser {
    /// `-F pcun` alan çıktısını ayrıştırır: "p<pid>", "c<komut>", "u<uid>", "f<fd>", "n<adres>" satırları.
    /// Aynı PID birden çok kez görünürse adres listeleri birleştirilir.
    static func parseListeners(_ output: String) -> [PortListener] {
        var result: [PortListener] = []
        var pid: Int32?
        var command = ""
        var uid: UInt32?
        var addresses: [String] = []

        func flush() {
            guard let pid else { return }
            if let index = result.firstIndex(where: { $0.pid == pid }) {
                for address in addresses where !result[index].addresses.contains(address) {
                    result[index].addresses.append(address)
                }
            } else {
                result.append(PortListener(pid: pid, command: command, uid: uid, addresses: addresses))
            }
        }

        for rawLine in output.split(whereSeparator: \.isNewline) {
            guard let tag = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())
            switch tag {
            case "p":
                flush()
                pid = Int32(value)
                command = ""
                uid = nil
                addresses = []
            case "c":
                command = value
            case "u":
                uid = UInt32(value)
            case "n":
                if !value.isEmpty, !addresses.contains(value) { addresses.append(value) }
            default:
                break
            }
        }
        flush()
        return result
    }
}
