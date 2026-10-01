import Foundation

/// Son N satırı tutan, iş parçacığı güvenli küçük halka tampon.
/// ciadpi'nin stderr çıktısını (perror mesajları) toplamak için kullanılır.
final class LineRingBuffer: @unchecked Sendable {
    private let capacity: Int
    private let lock = NSLock()
    private var lines: [String] = []
    private var partial = ""

    init(capacity: Int = 50) {
        self.capacity = max(1, capacity)
    }

    func append(_ data: Data) {
        append(String(decoding: data, as: UTF8.self))
    }

    func append(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        var combined = partial + text
        partial = ""
        // Son parça satır sonuyla bitmiyorsa bir sonraki parçaya kadar beklet
        if let lastNewline = combined.lastIndex(where: { $0.isNewline }) {
            partial = String(combined[combined.index(after: lastNewline)...])
            combined = String(combined[...lastNewline])
        } else {
            // Satır sonu hiç gelmezse tampon sınırsız büyümesin
            if combined.count > 4096 {
                lines.append(String(combined.suffix(4096)))
                if lines.count > capacity { lines.removeFirst(lines.count - capacity) }
            } else {
                partial = combined
            }
            return
        }
        for line in combined.split(whereSeparator: \.isNewline) where !line.isEmpty {
            lines.append(String(line))
        }
        if lines.count > capacity {
            lines.removeFirst(lines.count - capacity)
        }
    }

    /// Tamamlanmış satırlar + (varsa) yarım kalan son satır.
    var snapshot: [String] {
        lock.lock()
        defer { lock.unlock() }
        var result = lines
        let rest = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty { result.append(rest) }
        return Array(result.suffix(capacity))
    }

    var text: String { snapshot.joined(separator: "\n") }

    func removeAll() {
        lock.lock()
        lines.removeAll()
        partial = ""
        lock.unlock()
    }
}
