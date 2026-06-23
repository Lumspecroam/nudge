import Foundation

struct Hotkey: Equatable {
    let modifiers: UInt32
    let keyCode: UInt32
}

enum HotkeyAssignment: Equatable {
    case defaultValue
    case custom(Hotkey)
    case disabled
}

final class UserPreferences {
    static let shared = UserPreferences()
    private let defaults: UserDefaults
    private let shortcutLock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    var dragSnapEnabled: Bool {
        get { defaults.object(forKey: "dragSnapEnabled") == nil ? true : defaults.bool(forKey: "dragSnapEnabled") }
        set { defaults.set(newValue, forKey: "dragSnapEnabled") }
    }

    var analyticsEnabled: Bool {
        get { defaults.object(forKey: "analyticsEnabled") == nil ? false : defaults.bool(forKey: "analyticsEnabled") }
        set { defaults.set(newValue, forKey: "analyticsEnabled") }
    }

    func hotkeyAssignment(for action: SnapAction) -> HotkeyAssignment {
        shortcutLock.lock()
        defer { shortcutLock.unlock() }
        guard let entry = shortcutDictionary[action.rawValue] else { return .defaultValue }
        if entry["disabled"] == 1 {
            return .disabled
        }
        guard let modifiers = entry["modifiers"],
              let keyCode = entry["keyCode"] else { return .defaultValue }
        return .custom(Hotkey(modifiers: modifiers, keyCode: keyCode))
    }

    func setCustomHotkey(for action: SnapAction, modifiers: UInt32, keyCode: UInt32) {
        shortcutLock.lock()
        defer { shortcutLock.unlock() }
        var dict = shortcutDictionary
        dict[action.rawValue] = ["modifiers": modifiers, "keyCode": keyCode]
        defaults.set(dict, forKey: "customShortcuts")
    }

    func disableHotkey(for action: SnapAction) {
        shortcutLock.lock()
        defer { shortcutLock.unlock() }
        var dict = shortcutDictionary
        dict[action.rawValue] = ["disabled": 1]
        defaults.set(dict, forKey: "customShortcuts")
    }

    func resetHotkey(for action: SnapAction) {
        shortcutLock.lock()
        defer { shortcutLock.unlock() }
        var dict = shortcutDictionary
        dict.removeValue(forKey: action.rawValue)
        defaults.set(dict, forKey: "customShortcuts")
    }

    func hotkey(for action: SnapAction) -> Hotkey? {
        switch hotkeyAssignment(for: action) {
        case .defaultValue:
            return action.defaultHotkey
        case .custom(let hotkey):
            return hotkey
        case .disabled:
            return nil
        }
    }

    func conflictingAction(for hotkey: Hotkey, excluding excludedAction: SnapAction? = nil) -> SnapAction? {
        SnapAction.allCases.first { action in
            action != excludedAction && self.hotkey(for: action) == hotkey
        }
    }

    // MARK: - Ignored Apps

    var ignoredApps: [String] {
        get { defaults.stringArray(forKey: "ignoredApps") ?? [] }
        set { defaults.set(newValue, forKey: "ignoredApps") }
    }

    func isAppIgnored(_ bundleID: String) -> Bool {
        return ignoredApps.contains(bundleID)
    }

    func addIgnoredApp(_ bundleID: String) {
        var list = ignoredApps
        if !list.contains(bundleID) {
            list.append(bundleID)
            ignoredApps = list
        }
    }

    func removeIgnoredApp(_ bundleID: String) {
        var list = ignoredApps
        list.removeAll { $0 == bundleID }
        ignoredApps = list
    }

    private var shortcutDictionary: [String: [String: UInt32]] {
        defaults.dictionary(forKey: "customShortcuts") as? [String: [String: UInt32]] ?? [:]
    }
}
