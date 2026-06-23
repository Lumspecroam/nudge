import XCTest
@testable import Nudge

final class DragGestureClassifierTests: XCTestCase {
    private let windowFrame = CGRect(x: 100, y: 100, width: 600, height: 400)

    func testNonTitleBarDragIsIgnoredForEntireGesture() {
        var classifier = DragGestureClassifier()
        classifier.begin(
            cursor: CGPoint(x: 200, y: 250),
            windowFrame: windowFrame,
            titleBarHeight: 40
        )

        XCTAssertEqual(classifier.phase, .ignored)
        XCTAssertFalse(classifier.update(
            cursor: CGPoint(x: 350, y: 250),
            windowPosition: CGPoint(x: 200, y: 100)
        ))
        XCTAssertEqual(classifier.phase, .ignored)
    }

    func testTitleBarDragWithoutWindowMovementRemainsPending() {
        var classifier = DragGestureClassifier()
        classifier.begin(
            cursor: CGPoint(x: 200, y: 120),
            windowFrame: windowFrame,
            titleBarHeight: 40
        )

        XCTAssertFalse(classifier.update(
            cursor: CGPoint(x: 400, y: 120),
            windowPosition: windowFrame.origin
        ))
        XCTAssertEqual(classifier.phase, .pending)
    }

    func testTitleBarDragActivatesAfterWindowMoves() {
        var classifier = DragGestureClassifier()
        classifier.begin(
            cursor: CGPoint(x: 200, y: 120),
            windowFrame: windowFrame,
            titleBarHeight: 40
        )

        XCTAssertTrue(classifier.update(
            cursor: CGPoint(x: 210, y: 130),
            windowPosition: CGPoint(x: 110, y: 110)
        ))
        XCTAssertEqual(classifier.phase, .active)
    }

    func testResetAllowsNextGesture() {
        var classifier = DragGestureClassifier()
        classifier.begin(
            cursor: CGPoint(x: 200, y: 250),
            windowFrame: windowFrame,
            titleBarHeight: 40
        )
        classifier.reset()

        XCTAssertEqual(classifier.phase, .idle)
        classifier.begin(
            cursor: CGPoint(x: 200, y: 120),
            windowFrame: windowFrame,
            titleBarHeight: 40
        )
        XCTAssertEqual(classifier.phase, .pending)
    }
}
