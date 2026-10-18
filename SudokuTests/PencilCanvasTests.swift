import XCTest
import PencilKit
@testable import Sudoku

/// Always "reads" the same digit, so these tests exercise the canvas pipeline, not Vision.
private struct StubRecognizer: DigitRecognizer {
    let result: RecognizedDigit?
    func recognize(_ drawing: PKDrawing) async -> RecognizedDigit? { result }
}

/// Runs synthetic strokes through the same canvas pipeline a stylus would (debounce, routing, recognizer).
@MainActor
final class PencilCanvasTests: XCTestCase {
    private var inputs: [CellInput] = []
    private var canvas: PKCanvasView!
    private var coordinator: PencilCanvas.Coordinator!

    private func makeCanvas(givens: Set<Int> = [], noteMode: Bool = false, reads digit: Int? = 7,
                            expecting expectation: XCTestExpectation? = nil) {
        canvas = PKCanvasView(frame: CGRect(x: 0, y: 0, width: 450, height: 450))
        let recognizer = StubRecognizer(result: digit.map { RecognizedDigit(digit: $0, confidence: 1) })
        coordinator = PencilCanvas(givens: givens, noteMode: noteMode, onInput: { [weak self] input in
            self?.inputs.append(input)
            expectation?.fulfill()
        }, recognizer: recognizer).makeCoordinator()
        coordinator.canvas = canvas
        canvas.delegate = coordinator
    }

    private func write(_ strokes: [PKStroke]) {
        canvas.drawing = PKDrawing(strokes: canvas.drawing.strokes + strokes)
    }

    func testWrittenSevenBecomesDigitAndInkDisappears() async {
        let entered = expectation(description: "input")
        makeCanvas(expecting: entered)
        write(syntheticSeven(at: CGPoint(x: 205, y: 205), size: 40)) // cell 40
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertEqual(inputs, [.digit(7, cell: 40)])
        XCTAssertTrue(canvas.drawing.strokes.isEmpty)
    }

    func testSmallSevenBecomesNote() async {
        let entered = expectation(description: "input")
        makeCanvas(expecting: entered)
        write(syntheticSeven(at: CGPoint(x: 55, y: 5), size: 18)) // cell 1
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertEqual(inputs, [.note(7, cell: 1)])
    }

    func testNoteModeForcesNote() async {
        let entered = expectation(description: "input")
        makeCanvas(noteMode: true, expecting: entered)
        write(syntheticSeven(at: CGPoint(x: 205, y: 205), size: 40))
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertEqual(inputs, [.note(7, cell: 40)])
    }

    func testScratchOutClearsCell() async {
        let entered = expectation(description: "input")
        makeCanvas(expecting: entered)
        let zigZag = (0...8).map { CGPoint(x: $0.isMultiple(of: 2) ? 105 : 145, y: 110 + CGFloat($0) * 3) }
        write([syntheticStroke(zigZag)]) // cell 20
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertEqual(inputs, [.clear(cell: 20)])
    }

    func testStrokeOnGivenIsDroppedWithoutInput() async throws {
        makeCanvas(givens: [40])
        write(syntheticSeven(at: CGPoint(x: 205, y: 205), size: 40))
        XCTAssertTrue(canvas.drawing.strokes.isEmpty)
        try await Task.sleep(for: .seconds(0.6))
        XCTAssertEqual(inputs, [])
    }

    func testDotAndTickAreNotRead() async throws {
        makeCanvas(reads: 1)
        write([syntheticStroke([CGPoint(x: 225, y: 225), CGPoint(x: 225.5, y: 225.5)]),     // dot, cell 40
               syntheticStroke([CGPoint(x: 70, y: 20), CGPoint(x: 73, y: 25)])])             // tick, cell 1
        try await Task.sleep(for: .seconds(0.6))
        XCTAssertEqual(inputs, [])
        XCTAssertEqual(canvas.drawing.strokes.count, 2) // shown grey for a second, then removed
        try await Task.sleep(for: .seconds(1.1))
        XCTAssertTrue(canvas.drawing.strokes.isEmpty)
    }

    func testUnreadInkFadesWithoutInput() async throws {
        makeCanvas(reads: nil)
        write(syntheticSeven(at: CGPoint(x: 205, y: 205), size: 40))
        try await Task.sleep(for: .seconds(0.6))
        XCTAssertEqual(inputs, [])
        XCTAssertEqual(canvas.drawing.strokes.count, 1)
        XCTAssertNotEqual(canvas.drawing.strokes.first?.ink.color, .black) // greyed
        try await Task.sleep(for: .seconds(1.1))
        XCTAssertTrue(canvas.drawing.strokes.isEmpty)
    }

    func testStoppedCanvasEntersNothing() async throws {
        makeCanvas()
        write(syntheticSeven(at: CGPoint(x: 205, y: 205), size: 40))
        coordinator.stop()
        try await Task.sleep(for: .seconds(0.6))
        XCTAssertEqual(inputs, [])
    }

    func testInkIsKeptWhileAStrokeIsInProgress() async {
        let entered = expectation(description: "input")
        makeCanvas(expecting: entered)
        write(syntheticSeven(at: CGPoint(x: 205, y: 205), size: 40))
        coordinator.canvasViewDidBeginUsingTool(canvas) // pencil already writing in the next cell
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertEqual(inputs, [.digit(7, cell: 40)])
        XCTAssertEqual(canvas.drawing.strokes.count, 1)
        coordinator.canvasViewDidEndUsingTool(canvas)
        XCTAssertTrue(canvas.drawing.strokes.isEmpty)
    }
}
