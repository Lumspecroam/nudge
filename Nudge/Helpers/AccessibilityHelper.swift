import Cocoa
import ApplicationServices

final class AccessibilityHelper {
    static let shared = AccessibilityHelper()
    private var pollTimer: Timer?
    private var pollStartTime: Date?
    private let pollTimeout: TimeInterval = 120 // 2 minutes

    var isAccessibilityGranted: Bool {
        return AXIsProcessTrusted()
    }

    /// Request accessibility using the system prompt (no custom alert needed)
    func requestAccessAndPoll(completion: @escaping (Bool) -> Void) {
        if isAccessibilityGranted {
            completion(true)
            return
        }

        // This triggers the macOS system accessibility prompt automatically
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            completion(true)
        } else {
            // Poll until user grants permission or timeout
            startPolling(completion: completion)
        }
    }

    private func startPolling(completion: @escaping (Bool) -> Void) {
        pollStartTime = Date()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.pollTimer = nil
                self.pollStartTime = nil
                completion(true)
            } else if let start = self.pollStartTime, Date().timeIntervalSince(start) > self.pollTimeout {
                timer.invalidate()
                self.pollTimer = nil
                self.pollStartTime = nil
                FileLog.write("AccessibilityHelper: polling timed out after \(self.pollTimeout)s")
                completion(false)
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        pollStartTime = nil
    }
}
