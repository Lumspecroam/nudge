import XCTest
@testable import Nudge

final class UserPreferencesTests: XCTestCase {
    private let suiteName = "app.nudge.NudgeTests.UserPreferences"
    private var defaults: UserDefaults!
    private var preferences: UserPreferences!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        preferences = UserPreferences(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        preferences = nil
        super.tearDown()
    }

    func testMissingAssignmentUsesDefaultHotkey() {
        XCTAssertEqual(preferences.hotkeyAssignment(for: .leftHalf), .defaultValue)
        XCTAssertEqual(preferences.hotkey(for: .leftHalf), SnapAction.leftHalf.defaultHotkey)
    }

    func testLegacyCustomShortcutRemainsReadable() {
        let custom = Hotkey(modifiers: 123, keyCode: 45)
        let dictionary: [String: [String: UInt32]] = [
            SnapAction.leftHalf.rawValue: [
                "modifiers": custom.modifiers,
                "keyCode": custom.keyCode,
            ],
        ]
        defaults.set(dictionary, forKey: "customShortcuts")

        XCTAssertEqual(preferences.hotkeyAssignment(for: .leftHalf), .custom(custom))
        XCTAssertEqual(preferences.hotkey(for: .leftHalf), custom)
    }

    func testDisableAndResetShortcut() {
        preferences.disableHotkey(for: .leftHalf)

        XCTAssertEqual(preferences.hotkeyAssignment(for: .leftHalf), .disabled)
        XCTAssertNil(preferences.hotkey(for: .leftHalf))

        preferences.resetHotkey(for: .leftHalf)

        XCTAssertEqual(preferences.hotkeyAssignment(for: .leftHalf), .defaultValue)
        XCTAssertEqual(preferences.hotkey(for: .leftHalf), SnapAction.leftHalf.defaultHotkey)
    }

    func testConflictDetectionExcludesCurrentAndDisabledActions() {
        let hotkey = SnapAction.leftHalf.defaultHotkey
        XCTAssertEqual(preferences.conflictingAction(for: hotkey), .leftHalf)
        XCTAssertNil(preferences.conflictingAction(for: hotkey, excluding: .leftHalf))

        preferences.disableHotkey(for: .leftHalf)
        XCTAssertNil(preferences.conflictingAction(for: hotkey))
    }
}
