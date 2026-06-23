import XCTest
@testable import Nudge

final class KeyRecorderViewTests: XCTestCase {
    func testCancelRecordingRestoresExistingShortcutText() {
        let recorder = KeyRecorderView(frame: CGRect(x: 0, y: 0, width: 160, height: 24))
        recorder.setShortcut(SnapAction.leftHalf.defaultHotkey)
        let originalText = recorder.displayedText

        recorder.beginRecording()
        XCTAssertEqual(recorder.displayedText, "Type shortcut...")

        recorder.cancelRecording()
        XCTAssertEqual(recorder.displayedText, originalText)
    }

    func testClearDisplaysUnassignedAndNotifiesOwner() {
        let recorder = KeyRecorderView(frame: CGRect(x: 0, y: 0, width: 160, height: 24))
        recorder.setShortcut(SnapAction.leftHalf.defaultHotkey)
        var didClear = false
        recorder.onCleared = { didClear = true }

        recorder.clearShortcut()

        XCTAssertTrue(didClear)
        XCTAssertEqual(recorder.displayedText, "")
        XCTAssertEqual(recorder.currentModifiers, 0)
        XCTAssertEqual(recorder.currentKeyCode, 0)
    }
}
