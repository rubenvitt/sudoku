import XCTest
@testable import Sudoku

final class StrokeRouterTests: XCTestCase {
    /// 450 pt board: cells are 50 pt squares.
    private let router = StrokeRouter(gridFrame: CGRect(x: 0, y: 0, width: 450, height: 450), givens: [2])

    func testStrokeAssignedToCellOfBoundingBoxCenter() {
        // Spans cells 0 and 1, center x = 60 lies in cell 1.
        XCTAssertEqual(router.cell(for: CGRect(x: 30, y: 10, width: 60, height: 30)), 1)
        XCTAssertEqual(router.cell(for: CGRect(x: 410, y: 410, width: 30, height: 30)), 80)
        XCTAssertNil(router.cell(for: CGRect(x: 440, y: 10, width: 30, height: 30))) // center off the board
    }

    func testStrokeOnGivenIsDiscarded() {
        XCTAssertNil(router.cell(for: CGRect(x: 110, y: 10, width: 30, height: 30)))
    }

    func testSmallStrokeIsNote() {
        XCTAssertTrue(router.isNote(CGRect(x: 5, y: 5, width: 10, height: 15)))  // 0.3 × cell
        XCTAssertFalse(router.isNote(CGRect(x: 5, y: 5, width: 20, height: 35))) // 0.7 × cell
    }

    func testZigZagIsScratchOut() {
        let zigZag = (0...8).map { CGPoint(x: $0.isMultiple(of: 2) ? 5 : 45, y: 10 + CGFloat($0) * 3) }
        XCTAssertTrue(router.isScratchOut(zigZag))

        let seven = [CGPoint(x: 10, y: 8), CGPoint(x: 40, y: 8), CGPoint(x: 22, y: 45)]
        XCTAssertFalse(router.isScratchOut(seven))
        let wobblyOne = (0...40).map { CGPoint(x: 25 + ($0.isMultiple(of: 2) ? 0.8 : -0.8), y: 5 + CGFloat($0)) }
        XCTAssertFalse(router.isScratchOut(wobblyOne))
        let eight = (0...64).map { step -> CGPoint in
            let t = CGFloat(step) / 64 * 2 * .pi
            return CGPoint(x: 25 + 12 * sin(2 * t), y: 25 - 20 * cos(t))
        }
        XCTAssertFalse(router.isScratchOut(eight))
    }
}
