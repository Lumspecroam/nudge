import XCTest
@testable import Nudge

/// Performance regression tests. These don't validate correctness — they record
/// baseline timings so future changes that regress performance will be flagged.
/// All operations are pure and have no AX/Cocoa dependencies, so they are stable.
final class PerformanceTests: XCTestCase {

    // MARK: - SnapGeometry

    func testMirrorActionThroughput() {
        measure {
            for _ in 0..<10_000 {
                for action in SnapAction.allCases {
                    _ = SnapGeometry.mirrorAction(action)
                }
            }
        }
    }

    func testCycleDirectionThroughput() {
        measure {
            for _ in 0..<10_000 {
                for action in SnapAction.allCases {
                    _ = SnapGeometry.cycleDirection(for: action)
                }
            }
        }
    }

    func testIsFrameMatchThroughput() {
        let a = CGRect(x: 100, y: 200, width: 800, height: 600)
        let b = CGRect(x: 102, y: 198, width: 799, height: 601)
        measure {
            for _ in 0..<100_000 {
                _ = SnapGeometry.isFrameMatch(a, b)
            }
        }
    }

    // MARK: - SnapZone

    func testSnapZoneFrameCalculationThroughput() {
        let frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        measure {
            for _ in 0..<5_000 {
                for action in SnapAction.allCases {
                    _ = SnapZone.frame(for: action, in: frame)
                }
            }
        }
    }

    // MARK: - SnapAction

    func testDisplayNameLookupThroughput() {
        measure {
            for _ in 0..<5_000 {
                for action in SnapAction.allCases {
                    _ = action.displayName
                }
            }
        }
    }

    func testCategoryLookupThroughput() {
        measure {
            for _ in 0..<5_000 {
                for action in SnapAction.allCases {
                    _ = action.category
                }
            }
        }
    }
}
