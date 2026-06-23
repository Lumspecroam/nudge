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

    static func write(_ message: String) {
        #if DEBUG
        let ts = dateFormatter.string(from: Date())
        let line = "[\(ts)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        rotateIfNeeded()
        if let fh = try? FileHandle(forWritingTo: logURL) {
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        } else {
            try? data.write(to: logURL)
        }
        #endif
    }

    private static func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
              let size = attrs[.size] as? UInt64, size > maxFileSize else { return }
        let archiveURL = logURL.deletingPathExtension().appendingPathExtension("log.old")
        try? FileManager.default.removeItem(at: archiveURL)
        try? FileManager.default.moveItem(at: logURL, to: archiveURL)
    }
}
