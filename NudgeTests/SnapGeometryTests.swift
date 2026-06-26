import XCTest
@testable import Nudge

/// Tests for pure helpers extracted from WindowManager.
final class SnapGeometryTests: XCTestCase {

    // MARK: - mirrorAction

    func testMirrorActionSwapsLeftRightHalves() {
        XCTAssertEqual(SnapGeometry.mirrorAction(.leftHalf), .rightHalf)
        XCTAssertEqual(SnapGeometry.mirrorAction(.rightHalf), .leftHalf)
    }

    func testMirrorActionSwapsQuarters() {
        XCTAssertEqual(SnapGeometry.mirrorAction(.topLeft), .topRight)
        XCTAssertEqual(SnapGeometry.mirrorAction(.topRight), .topLeft)
        XCTAssertEqual(SnapGeometry.mirrorAction(.bottomLeft), .bottomRight)
        XCTAssertEqual(SnapGeometry.mirrorAction(.bottomRight), .bottomLeft)
    }

    func testMirrorActionSwapsThirds() {
        XCTAssertEqual(SnapGeometry.mirrorAction(.leftThird), .rightThird)
        XCTAssertEqual(SnapGeometry.mirrorAction(.rightThird), .leftThird)
        XCTAssertEqual(SnapGeometry.mirrorAction(.leftTwoThirds), .rightTwoThirds)
        XCTAssertEqual(SnapGeometry.mirrorAction(.rightTwoThirds), .leftTwoThirds)
    }

    func testMirrorActionFlipsTopBottomHalves() {
        // topHalf mirrored across monitor stack becomes bottomHalf (and vice versa)
        XCTAssertEqual(SnapGeometry.mirrorAction(.topHalf), .bottomHalf)
        XCTAssertEqual(SnapGeometry.mirrorAction(.bottomHalf), .topHalf)
    }

    func testMirrorActionLeavesCenterAndDisplayUnchanged() {
        XCTAssertEqual(SnapGeometry.mirrorAction(.center), .center)
        XCTAssertEqual(SnapGeometry.mirrorAction(.centerThird), .centerThird)
        XCTAssertEqual(SnapGeometry.mirrorAction(.centerTwoThirds), .centerTwoThirds)
        XCTAssertEqual(SnapGeometry.mirrorAction(.maximize), .maximize)
        XCTAssertEqual(SnapGeometry.mirrorAction(.restore), .restore)
        XCTAssertEqual(SnapGeometry.mirrorAction(.nextDisplay), .nextDisplay)
        XCTAssertEqual(SnapGeometry.mirrorAction(.previousDisplay), .previousDisplay)
    }

    func testMirrorActionIsInvolution() {
        // Mirroring twice returns the original
        for action in SnapAction.allCases {
            XCTAssertEqual(
                SnapGeometry.mirrorAction(SnapGeometry.mirrorAction(action)),
                action,
                "Mirror must be an involution for \(action)"
            )
        }
    }

    // MARK: - cycleDirection

    func testCycleDirectionRightSideIsPositive() {
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .rightHalf), 1)
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .topRight), 1)
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .bottomRight), 1)
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .rightThird), 1)
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .rightTwoThirds), 1)
    }

    func testCycleDirectionLeftSideIsNegative() {
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .leftHalf), -1)
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .topLeft), -1)
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .bottomLeft), -1)
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .leftThird), -1)
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .leftTwoThirds), -1)
    }

    func testCycleDirectionVerticalHalves() {
        // Top half cycles left (like leftHalf), bottom cycles right (like rightHalf)
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .topHalf), -1)
        XCTAssertEqual(SnapGeometry.cycleDirection(for: .bottomHalf), 1)
    }

    // MARK: - isFrameMatch

    func testFrameMatchExact() {
        let a = CGRect(x: 100, y: 200, width: 800, height: 600)
        XCTAssertTrue(SnapGeometry.isFrameMatch(a, a))
    }

    func testFrameMatchWithinTolerance() {
        let a = CGRect(x: 100, y: 200, width: 800, height: 600)
        let b = CGRect(x: 105, y: 207, width: 798, height: 605) // all within 15px
        XCTAssertTrue(SnapGeometry.isFrameMatch(a, b))
    }

    func testFrameMatchOutsideTolerance() {
        let a = CGRect(x: 100, y: 200, width: 800, height: 600)
        let b = CGRect(x: 100, y: 200, width: 100, height: 100) // wildly different
        XCTAssertFalse(SnapGeometry.isFrameMatch(a, b))
    }

    func testFrameMatchAtToleranceBoundary() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 15, y: 0, width: 100, height: 100) // exactly at default 15px tolerance
        XCTAssertFalse(SnapGeometry.isFrameMatch(a, b)) // strict <, not <=
    }

    func testFrameMatchCustomTolerance() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 50, y: 0, width: 100, height: 100)
        XCTAssertFalse(SnapGeometry.isFrameMatch(a, b, tolerance: 15))
        XCTAssertTrue(SnapGeometry.isFrameMatch(a, b, tolerance: 100))
    }
}
