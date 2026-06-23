import XCTest
@testable import Nudge

final class DragSnapZoneDetectionTests: XCTestCase {
    let manager = DragSnapManager.shared

    func testLeftEdge() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.minX + 2, y: f.midY)), .leftHalf)
    }
    func testRightEdge() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.maxX - 2, y: f.midY)), .rightHalf)
    }
    func testTopEdge() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.midX, y: f.minY + 2)), .maximize)
    }
    func testTopLeftCorner() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.minX + 2, y: f.minY + 2)), .topLeft)
    }
    func testTopRightCorner() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.maxX - 2, y: f.minY + 2)), .topRight)
    }
    func testBottomLeftCorner() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.minX + 2, y: f.maxY - 2)), .bottomLeft)
    }
    func testBottomRightCorner() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.maxX - 2, y: f.maxY - 2)), .bottomRight)
    }
    func testCenterOfScreen() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let f = screen.frame
        XCTAssertNil(manager.detectSnapZone(cursor: CGPoint(x: f.midX, y: f.midY)))
    }
    func testBottomEdge() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.midX, y: f.maxY - 2)), .bottomHalf)
    }
}
