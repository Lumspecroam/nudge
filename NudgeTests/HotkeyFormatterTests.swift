import XCTest
@testable import Nudge
import Carbon

/// Tests for shared HotkeyFormatter utility (replaces duplicated code in
/// StatusBarController and KeyRecorderView).
final class HotkeyFormatterTests: XCTestCase {

    // MARK: - keyName

    func testKeyNameLetters() {
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_ANSI_A)), "A")
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_ANSI_Z)), "Z")
    }

    func testKeyNameDigits() {
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_ANSI_0)), "0")
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_ANSI_9)), "9")
    }

    func testKeyNameArrows() {
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_LeftArrow)), "←")
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_RightArrow)), "→")
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_UpArrow)), "↑")
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_DownArrow)), "↓")
    }

    func testKeyNameSpecialKeys() {
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_Return)), "Return")
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_Escape)), "Esc")
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_Space)), "Space")
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_Tab)), "Tab")
    }

    func testKeyNameFunctionKeys() {
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_F1)), "F1")
        XCTAssertEqual(HotkeyFormatter.keyName(for: UInt32(kVK_F12)), "F12")
    }

    func testKeyNameUnknownKeyFallback() {
        // Unknown keycodes get "Key<N>" instead of "?"
        XCTAssertEqual(HotkeyFormatter.keyName(for: 200), "Key200")
    }

    // MARK: - string(modifiers:keyCode:)

    func testStringWithNoModifiers() {
        let result = HotkeyFormatter.string(modifiers: 0, keyCode: UInt32(kVK_ANSI_D))
        XCTAssertEqual(result, "D")
    }

    func testStringWithCommandOnly() {
        let result = HotkeyFormatter.string(modifiers: UInt32(cmdKey), keyCode: UInt32(kVK_ANSI_D))
        XCTAssertEqual(result, "⌘ D")
    }

    func testStringWithAllModifiers() {
        let all = UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey) | UInt32(shiftKey)
        let result = HotkeyFormatter.string(modifiers: all, keyCode: UInt32(kVK_ANSI_D))
        XCTAssertEqual(result, "⌃ ⌥ ⌘ ⇧ D")
    }

    // MARK: - carbonModifiers

    func testCarbonModifiersAllFlags() {
        let flags: NSEvent.ModifierFlags = [.control, .option, .command, .shift]
        let result = HotkeyFormatter.carbonModifiers(from: flags)
        let expected = UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey) | UInt32(shiftKey)
        XCTAssertEqual(result, expected)
    }

    func testCarbonModifiersNone() {
        let result = HotkeyFormatter.carbonModifiers(from: [])
        XCTAssertEqual(result, 0)
    }

    func testCarbonModifiersCapsLockIgnored() {
        // Caps lock should not contribute
        let flags: NSEvent.ModifierFlags = [.command, .capsLock]
        let result = HotkeyFormatter.carbonModifiers(from: flags)
        XCTAssertEqual(result, UInt32(cmdKey))
    }
}
