import Foundation

enum FileLog {
    private static let maxFileSize: UInt64 = 1_048_576 // 1 MB
    private static let logURL: URL = {
        let home = NSHomeDirectory()
        return URL(fileURLWithPath: "\(home)/nudge-debug.log")
    }()
    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    /// Cached last-known size; avoids a FileManager stat on every write in the
    /// common (no-rotation-needed) case. Refreshed lazily on overflow.
    private static var cachedSize: UInt64 = 0
    private static let sizeLock = NSLock()

    static func write(_ message: String) {
        #if DEBUG
        let ts = dateFormatter.string(from: Date())
        let line = "[\(ts)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        rotateIfNeeded(appendingBytes: UInt64(data.count))
        if let fh = try? FileHandle(forWritingTo: logURL) {
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        } else {
            try? data.write(to: logURL)
        }
        #endif
    }

    /// Check rotation using a cached size counter. Only hits the filesystem
    /// once when the counter overflows the threshold, instead of on every write.
    private static func rotateIfNeeded(appendingBytes: UInt64) {
        sizeLock.lock()
        let projected = cachedSize + appendingBytes
        if projected <= maxFileSize {
            cachedSize = projected
            sizeLock.unlock()
            return
        }
        // Overflow: refresh from disk in case the file was rotated externally,
        // then re-check.
        let actualSize: UInt64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
           let size = attrs[.size] as? UInt64 {
            actualSize = size
        } else {
            actualSize = 0
        }
        if actualSize > maxFileSize {
            let archiveURL = logURL.deletingPathExtension().appendingPathExtension("log.old")
            try? FileManager.default.removeItem(at: archiveURL)
            try? FileManager.default.moveItem(at: logURL, to: archiveURL)
            cachedSize = 0
        } else {
            cachedSize = actualSize + appendingBytes
        }
        sizeLock.unlock()
    }
}
