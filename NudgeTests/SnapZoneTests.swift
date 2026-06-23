import XCTest
@testable import Nudge

final class SnapZoneTests: XCTestCase {
    private let frame = CGRect(x: -100, y: 50, width: 1001, height: 799)

    func testLeftHalf() {
        let result = SnapZone.frame(for: .leftHalf, in: frame)!
        XCTAssertEqual(result.origin.x, frame.minX)
        XCTAssertEqual(result.origin.y, frame.minY)
        XCTAssertEqual(result.width, floor(frame.width / 2))
        XCTAssertEqual(result.height, frame.height)
    }

    func testRightHalf() {
        let result = SnapZone.frame(for: .rightHalf, in: frame)!
        let halfW = floor(frame.width / 2)
        XCTAssertEqual(result.origin.x, frame.minX + halfW)
        XCTAssertEqual(result.width, frame.width - halfW)
    }

    func testTopHalf() {
        let result = SnapZone.frame(for: .topHalf, in: frame)!
        let halfH = floor(frame.height / 2)
        XCTAssertEqual(result.origin.y, frame.minY + halfH)
        XCTAssertEqual(result.height, frame.height - halfH)
    }

    func testBottomHalf() {
        let result = SnapZone.frame(for: .bottomHalf, in: frame)!
        XCTAssertEqual(result.origin.y, frame.minY)
        XCTAssertEqual(result.height, floor(frame.height / 2))
    }

    func testMaximize() {
        XCTAssertEqual(SnapZone.frame(for: .maximize, in: frame), frame)
    }

    func testQuartersCoverScreen() {
        let tl = SnapZone.frame(for: .topLeft, in: frame)!
        let tr = SnapZone.frame(for: .topRight, in: frame)!
        let bl = SnapZone.frame(for: .bottomLeft, in: frame)!
        let br = SnapZone.frame(for: .bottomRight, in: frame)!
        XCTAssertEqual(tl.width + tr.width, frame.width, accuracy: 1)
        XCTAssertEqual(bl.width + br.width, frame.width, accuracy: 1)
        XCTAssertEqual(tl.height + bl.height, frame.height, accuracy: 1)
    }

    func testThirdsCoverScreen() {
        let l = SnapZone.frame(for: .leftThird, in: frame)!
        let c = SnapZone.frame(for: .centerThird, in: frame)!
        let r = SnapZone.frame(for: .rightThird, in: frame)!
        XCTAssertEqual(l.width + c.width + r.width, frame.width, accuracy: 1)
    }

    func testCenterTwoThirdsUsesSymmetricMarginsOnOddWidth() {
        let result = SnapZone.frame(for: .centerTwoThirds, in: frame)!
        let margin = floor(frame.width / 6)
        XCTAssertEqual(result.minX, frame.minX + margin)
        XCTAssertEqual(result.maxX, frame.maxX - margin)
    }

    func testRestoreReturnsNil() {
        XCTAssertNil(SnapZone.frame(for: .restore, in: frame))
    }

    func testCenterReturnsNil() {
        XCTAssertNil(SnapZone.frame(for: .center, in: frame))
    }

    func testDisplayActionsReturnNil() {
        XCTAssertNil(SnapZone.frame(for: .nextDisplay, in: frame))
        XCTAssertNil(SnapZone.frame(for: .previousDisplay, in: frame))
    }
}
