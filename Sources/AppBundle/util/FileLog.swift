import Common
import Foundation

/// Minimal, file-backed runtime log for AeroSpace.app.
///
/// Purpose: give a way to capture what the app was doing on a target machine (e.g. an
/// old macOS 12 host) without a debugger. The log is written to
/// `~/Library/Logs/AeroSpace/aerospace.log`, which can be exported and inspected remotely.
///
/// All writes are synchronized (thread-safe). The log is bounded: when it exceeds
/// `maxFileSize` bytes it is truncated to `trimmedSize` bytes. Log lines are not persisted
/// to disk when the agent is not the app (CLI) to avoid littering.
public enum FileLog {
    private static let maxFileSize = 4 * 1024 * 1024
    private static let trimmedSize = 1024 * 1024
    private static let lock = NSLock()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    /// Collapse multi-line text into a single log line.
    static func singleLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "⏎")
    }

    public static var logFileUrl: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AeroSpace")
            .appendingPathComponent("aerospace.log")
    }

    /// Append a message to the log. Uses `autoclosure` so string interpolation cost is
    /// only paid when the message actually gets written.
    public static func log(_ message: @autoclosure () -> String) {
        guard !isUnitTest else { return }
        let line = "[\(dateFormatter.string(from: Date()))] \(message())\n"
        lock.withLock {
            do {
                let url = logFileUrl
                let parent = url.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: parent.path) {
                    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                }
                if !FileManager.default.fileExists(atPath: url.path) {
                    FileManager.default.createFile(atPath: url.path, contents: nil)
                }
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                if fileSize > maxFileSize {
                    try handle.truncate(atOffset: UInt64(trimmedSize))
                }
            } catch {
                // Logging must never crash or interfere with the app.
            }
        }
    }

    /// Tail of the log, for embedding into crash reports / diagnostics.
    public static func tail(maxLines: Int = 200) -> String {
        let url = logFileUrl
        guard let data = try? Data(contentsOf: url) else { return "" }
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(whereSeparator: \.isNewline)
        return lines.suffix(maxLines).joined(separator: "\n")
    }

    /// CPU architecture of this machine (e.g. "arm64", "x86_64"), via uname.
    public static func machineArch() -> String {
        var sysinfo = utsname()
        unsafe uname(&sysinfo)
        var result = ""
        for case (_, let value)? in Mirror(reflecting: sysinfo.machine).children {
            guard let c = value as? CChar, c != 0 else { break }
            result.append(Character(UnicodeScalar(UInt8(bitPattern: c))))
        }
        return result.isEmpty ? "unknown" : result
    }
}

private extension NSLock {
    func withLock(_ body: () -> Void) {
        lock()
        defer { unlock() }
        body()
    }
}