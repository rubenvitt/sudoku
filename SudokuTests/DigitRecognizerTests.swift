import XCTest
import PencilKit
@testable import Sudoku

final class DigitRecognizerTests: XCTestCase {
    func testRecognizerMapsLookalikes() {
        XCTAssertEqual(mapRecognized("7"), 7)
        XCTAssertEqual(mapRecognized(" 3\n"), 3)
        XCTAssertEqual(mapRecognized("4."), 4)
        for one in ["l", "I", "|", "!"] { XCTAssertEqual(mapRecognized(one), 1, one) }
        for five in ["S", "s"] { XCTAssertEqual(mapRecognized(five), 5, five) }
        for two in ["Z", "z"] { XCTAssertEqual(mapRecognized(two), 2, two) }
        for nine in ["g", "q"] { XCTAssertEqual(mapRecognized(nine), 9, nine) }
        XCTAssertEqual(mapRecognized("B"), 8)
        for none in ["O", "o", "0", "A", "12", "", " "] { XCTAssertNil(mapRecognized(none), none) }
    }

    @MainActor
    func testVisionRecognizesRenderedDigit() async throws {
        let drawing = PKDrawing(strokes: syntheticSeven(at: CGPoint(x: 200, y: 200), size: 40))
        let recognized = await VisionDigitRecognizer().recognize(drawing)
        let result = try XCTUnwrap(recognized)
        XCTAssertEqual(result.digit, 7)
        XCTAssertGreaterThanOrEqual(result.confidence, PencilCanvas.minimumConfidence)
    }
}
