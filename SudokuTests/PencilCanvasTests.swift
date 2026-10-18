import XCTest
import PencilKit
@testable import Sudoku

/// Runs synthetic strokes through the same canvas pipeline a stylus would (debounce, routing, Vision).
@MainActor
final class PencilCanvasTests: XCTestCase {
    private var inputs: [String] = []
    private var canvas: PKCanvasView!
    private var coordinator: PencilCanvas.Coordinator!

    private func makeCanvas(givens: Set<Int> = [], noteMode: Bool = false, expecting expectation: XCTestExpectation? = nil) {
        canvas = PKCanvasView(frame: CGRect(x: 0, y: 0, width: 450, height: 450))
        coordinator = PencilCanvas(givens: givens, noteMode: noteMode, onInput: { [weak self] input in
            self?.inputs.append("\(input)")
            expectation?.fulfill()
        }).makeCoordinator()
        coordinator.canvas = canvas
        canvas.delegate = coordinator
    }

    func testWrittenSevenBecomesDigitAndInkDisappears() async {
        let entered = expectation(description: "input")
        makeCanvas(expecting: entered)
        canvas.drawing = PKDrawing(strokes: syntheticSeven(at: CGPoint(x: 205, y: 205), size: 40)) // cell 40
        await fulfillment(of: [entered], timeout: 5)
        XCTAssertEqual(inputs, ["digit(7, cell: 40)"])
        XCTAssertTrue(canvas.drawing.strokes.isEmpty)
    }

    func testSmallSevenBecomesNote() async {
        let entered = expectation(description: "input")
        makeCanvas(expecting: entered)
        canvas.drawing = PKDrawing(strokes: syntheticSeven(at: CGPoint(x: 55, y: 5), size: 18)) // cell 1
        await fulfillment(of: [entered], timeout: 5)
        XCTAssertEqual(inputs, ["note(7, cell: 1)"])
    }

    func testNoteModeForcesNote() async {
        let entered = expectation(description: "input")
        makeCanvas(noteMode: true, expecting: entered)
        canvas.drawing = PKDrawing(strokes: syntheticSeven(at: CGPoint(x: 205, y: 205), size: 40))
        await fulfillment(of: [entered], timeout: 5)
        XCTAssertEqual(inputs, ["note(7, cell: 40)"])
    }

    func testScratchOutClearsCell() async {
        let entered = expectation(description: "input")
        makeCanvas(expecting: entered)
        let zigZag = (0...8).map { CGPoint(x: $0.isMultiple(of: 2) ? 105 : 145, y: 110 + CGFloat($0) * 3) }
        canvas.drawing = PKDrawing(strokes: [syntheticStroke(zigZag)]) // cell 20
        await fulfillment(of: [entered], timeout: 5)
        XCTAssertEqual(inputs, ["clear(cell: 20)"])
    }

    func testStrokeOnGivenIsDroppedWithoutInput() async throws {
        makeCanvas(givens: [40])
        canvas.drawing = PKDrawing(strokes: syntheticSeven(at: CGPoint(x: 205, y: 205), size: 40))
        XCTAssertTrue(canvas.drawing.strokes.isEmpty)
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(inputs, [])
    }
}
