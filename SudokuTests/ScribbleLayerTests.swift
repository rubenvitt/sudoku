import XCTest
@testable import Sudoku

/// Scribble itself needs a real pencil; these tests cover what happens around it: elements, focus, and the text it delivers.
@MainActor
final class ScribbleLayerTests: XCTestCase {
    private var inputs: [CellInput] = []
    private var view: UIView!
    private var coordinator: ScribbleLayer.Coordinator!

    /// 450 pt board: cells are 50 pt squares.
    private func makeLayer(givens: Set<Int> = [2], noteMode: Bool = false) {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 450, height: 450))
        coordinator = ScribbleLayer(givens: givens, noteMode: noteMode, onInput: { [weak self] in
            self?.inputs.append($0)
        }).makeCoordinator()
        coordinator.view = view
    }

    /// Scribble inserting `text` into `cell`'s empty field; with `settle`, the cell then counts as done.
    private func scribble(_ text: String, into cell: Int = 40, settle: Bool = true) -> Bool {
        let accepted = coordinator.textField(coordinator.field(for: cell), shouldChangeCharactersIn: NSRange(location: 0, length: 0),
                                             replacementString: text)
        if settle { coordinator.commit(cell) }
        return accepted
    }

    /// The pencil writing `stroke`, as the ink recorder reports it.
    private func write(_ stroke: [CGPoint]) {
        coordinator.strokeBegan(at: stroke[0])
        coordinator.strokeEnded(stroke)
    }

    func testGeometry() {
        let geometry = GridGeometry(gridFrame: CGRect(x: 0, y: 0, width: 450, height: 450))
        XCTAssertEqual(geometry.cell(at: CGPoint(x: 60, y: 25)), 1)
        XCTAssertEqual(geometry.cell(at: CGPoint(x: 449, y: 449)), 80)
        XCTAssertNil(geometry.cell(at: CGPoint(x: 460, y: 10)))
        XCTAssertEqual(geometry.frame(of: 10), CGRect(x: 50, y: 50, width: 50, height: 50))
    }

    func testElementsAreTheNonGivenCellsUnderThePencil() {
        makeLayer()
        var elements: [Int] = []
        coordinator.indirectScribbleInteraction(UIIndirectScribbleInteraction(delegate: coordinator),
                                                requestElementsIn: CGRect(x: 60, y: 10, width: 80, height: 20)) { elements = $0 }
        XCTAssertEqual(elements, [1]) // cell 2 is a given
    }

    /// Scribble only writes into a field that really is first responder.
    func testFocusMakesHiddenFieldFirstResponder() throws {
        makeLayer()
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = try XCTUnwrap(scene?.keyWindow, "the test host app has no key window")
        window.addSubview(view)
        defer { coordinator.fields.values.forEach { $0.resignFirstResponder() }; view.removeFromSuperview() }
        XCTAssertNotNil(coordinator.focus(40))
        XCTAssertTrue(coordinator.field(for: 40).isFirstResponder)
    }

    func testWrittenDigitEntersIntoFocusedCell() {
        makeLayer()
        _ = coordinator.focus(40) // no window: focus fails, but the field already sits over the cell
        XCTAssertEqual(coordinator.field(for: 40).frame, CGRect(x: 200, y: 200, width: 50, height: 50))
        XCTAssertFalse(scribble("7"))
        XCTAssertFalse(scribble(" l")) // Scribble's leading space, look-alike for 1
        XCTAssertFalse(scribble("x"))
        XCTAssertEqual(inputs, [.digit(7, cell: 40), .digit(1, cell: 40)])
        XCTAssertEqual(coordinator.field(for: 40).text, "") // the field never takes the text
    }

    /// Writing quickly across cells: text Scribble delivers late still lands in the cell it was written in.
    func testLateTextLandsInItsOwnCell() {
        makeLayer()
        coordinator.record([CGPoint(x: 210, y: 205), CGPoint(x: 240, y: 245)])
        _ = coordinator.focus(40)
        coordinator.record([CGPoint(x: 260, y: 205), CGPoint(x: 290, y: 245)])
        _ = coordinator.focus(41) // the pencil has moved on before 40 was recognized
        _ = scribble("6", into: 40)
        _ = scribble("8", into: 41)
        guard case let .digit(6, cell: 40, ink: first?) = inputs.first, case let .digit(8, cell: 41, ink: second?) = inputs.last else {
            return XCTFail("\(inputs)")
        }
        XCTAssertEqual(first.strokes.count, 1)
        XCTAssertEqual(second.strokes.count, 1)
    }

    /// The strokes written into the cell travel with the digit, in cell units; strokes elsewhere stay out.
    func testWrittenDigitKeepsItsStrokes() throws {
        makeLayer()
        coordinator.record([CGPoint(x: 210, y: 205), CGPoint(x: 240, y: 205), CGPoint(x: 220, y: 245)])
        coordinator.record([CGPoint(x: 10, y: 10), CGPoint(x: 40, y: 40)]) // cell 0
        _ = coordinator.focus(40)
        _ = scribble("7")
        guard case let .digit(7, cell: 40, ink: ink?) = inputs.first else { return XCTFail("no ink: \(inputs)") }
        XCTAssertEqual(ink.digit, 7)
        XCTAssertEqual(ink.strokes, [[.init(x: 0.2, y: 0.1), .init(x: 0.8, y: 0.1), .init(x: 0.4, y: 0.9)]])
        // The strokes are used up: the next digit in the cell has no ink of its own.
        _ = scribble("4")
        XCTAssertEqual(inputs.last, .digit(4, cell: 40))
    }

    /// A 4 in two strokes: Scribble's text for the first stroke waits for the second, and the digit keeps both.
    func testDigitInTwoStrokesIsOneDigit() {
        makeLayer()
        _ = coordinator.focus(40)
        write([CGPoint(x: 215, y: 205), CGPoint(x: 210, y: 230), CGPoint(x: 240, y: 230)])
        _ = scribble("L", settle: false)
        write([CGPoint(x: 232, y: 210), CGPoint(x: 232, y: 245)])
        _ = scribble("1", settle: false)
        XCTAssertEqual(inputs, [])
        coordinator.flush()
        guard case let .digit(4, cell: 40, ink: ink?) = inputs.first, inputs.count == 1 else { return XCTFail("\(inputs)") }
        XCTAssertEqual(ink.strokes.count, 2)
    }

    /// The text only counts once the pencil has been away from the cell for a moment.
    func testTextWaitsWhileThePencilIsInTheCell() async throws {
        makeLayer()
        coordinator.settle = .milliseconds(50)
        _ = coordinator.focus(40)
        coordinator.strokeBegan(at: CGPoint(x: 220, y: 210))
        _ = scribble("7", settle: false) // arrives while the pencil writes the 7's bar
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(inputs, [])
        coordinator.strokeEnded([CGPoint(x: 220, y: 210), CGPoint(x: 230, y: 240)])
        try await Task.sleep(for: .milliseconds(300))
        guard case .digit(7, cell: 40, _) = inputs.first, inputs.count == 1 else { return XCTFail("\(inputs)") }
    }

    /// Writing on in the next cell doesn't hold up the last one.
    func testOtherCellsSettleOnTheirOwn() async throws {
        makeLayer()
        coordinator.settle = .milliseconds(50)
        _ = coordinator.focus(40)
        _ = scribble("6", settle: false)
        coordinator.strokeBegan(at: CGPoint(x: 270, y: 210)) // cell 41
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(inputs, [.digit(6, cell: 40)])
    }

    func testPiecesResolveToOneDigit() {
        XCTAssertEqual(resolveRecognized(["4"]), 4)
        XCTAssertEqual(resolveRecognized(["4", "1"]), 4)
        XCTAssertEqual(resolveRecognized(["1", "4"]), 4)
        XCTAssertEqual(resolveRecognized(["L", "1"]), 4)
        XCTAssertEqual(resolveRecognized(["L", "|"]), 4)
        XCTAssertEqual(resolveRecognized(["7", "-"]), 7)
        XCTAssertEqual(resolveRecognized(["S", "-"]), 5)
        XCTAssertEqual(resolveRecognized(["4", "4"]), 4) // never toggles the digit off again
        XCTAssertEqual(resolveRecognized(["l"]), 1)
        XCTAssertNil(resolveRecognized(["x", "-"]))
    }

    func testStrokesInNoteModeNeverBecomeInk() {
        makeLayer(noteMode: true)
        coordinator.record([CGPoint(x: 210, y: 205), CGPoint(x: 240, y: 245)])
        _ = coordinator.focus(40)
        _ = scribble("3")
        coordinator.parent = ScribbleLayer(givens: [2], noteMode: false, onInput: { [weak self] in self?.inputs.append($0) })
        _ = scribble("3")
        XCTAssertEqual(inputs, [.note(3, cell: 40), .digit(3, cell: 40)])
    }

    func testOldStrokesExpire() {
        makeLayer()
        coordinator.record([CGPoint(x: 210, y: 205), CGPoint(x: 240, y: 245)], at: .now - 10)
        coordinator.record([CGPoint(x: 10, y: 10), CGPoint(x: 40, y: 40)]) // drops the old one
        _ = coordinator.focus(40)
        _ = scribble("1")
        XCTAssertEqual(inputs, [.digit(1, cell: 40)])
    }

    func testInkReachingOverTheEdgeIsFittedIntoTheCell() throws {
        let inside = try XCTUnwrap(Ink(digit: 1, strokes: [[CGPoint(x: 25, y: 10), CGPoint(x: 25, y: 40)]],
                                       in: CGRect(x: 0, y: 0, width: 50, height: 50)))
        let written = inside.path(side: 100).boundingRect // as written: not moved, not scaled
        XCTAssertEqual(written.minY, 20, accuracy: 0.001)
        XCTAssertEqual(written.maxY, 80, accuracy: 0.001)
        XCTAssertEqual(written.midX, 50, accuracy: 0.001)
        let tall = try XCTUnwrap(Ink(digit: 1, strokes: [[CGPoint(x: 25, y: -25), CGPoint(x: 25, y: 75)]],
                                     in: CGRect(x: 0, y: 0, width: 50, height: 50)))
        let rect = tall.path(side: 100).boundingRect
        XCTAssertEqual(rect.minY, 10, accuracy: 0.001)
        XCTAssertEqual(rect.maxY, 90, accuracy: 0.001)
        XCTAssertEqual(rect.midX, 50, accuracy: 0.001)
    }

    func testNoteModeWritesNotes() {
        makeLayer(noteMode: true)
        _ = coordinator.focus(40)
        _ = scribble("3")
        XCTAssertEqual(inputs, [.note(3, cell: 40)])
    }

    func testGivenCannotBeFocused() {
        makeLayer()
        XCTAssertNil(coordinator.focus(2))
        XCTAssertFalse(scribble("4", into: 2))
        XCTAssertEqual(inputs, [])
    }

    /// Keypad, erase or undo on the cell while its writing is still being recognized wins over the late result.
    func testOtherEditWhileRecognizingDropsTheWriting() {
        makeLayer()
        _ = coordinator.focus(40)
        write([CGPoint(x: 210, y: 205), CGPoint(x: 240, y: 245)])
        _ = scribble("5", settle: false)
        coordinator.parent.revisions = [40: 1] // the keypad entered a digit there
        coordinator.flush()
        XCTAssertEqual(inputs, [])
        write([CGPoint(x: 210, y: 205), CGPoint(x: 240, y: 245)]) // writing there again counts
        _ = scribble("6")
        guard case let .digit(6, cell: 40, ink: ink?) = inputs.first, inputs.count == 1 else { return XCTFail("\(inputs)") }
        XCTAssertEqual(ink.strokes.count, 1) // the dropped writing's strokes went with it
    }

    /// Edits elsewhere leave the cell's writing alone.
    func testOtherCellsEditDoesNotDropTheWriting() {
        makeLayer()
        _ = coordinator.focus(40)
        write([CGPoint(x: 210, y: 205), CGPoint(x: 240, y: 245)])
        _ = scribble("5", settle: false)
        coordinator.parent.revisions = [41: 1]
        coordinator.flush()
        guard case .digit(5, cell: 40, _) = inputs.first, inputs.count == 1 else { return XCTFail("\(inputs)") }
    }

    /// A dot or a short stray stroke while the cell waits neither drops the digit nor its ink.
    func testStrayDotKeepsTheWaitingDigit() {
        makeLayer()
        _ = coordinator.focus(40)
        write([CGPoint(x: 210, y: 205), CGPoint(x: 240, y: 245)])
        _ = scribble("5", settle: false)
        write([CGPoint(x: 230, y: 230)])
        _ = scribble(".", settle: false)
        coordinator.flush()
        guard case let .digit(5, cell: 40, ink: ink?) = inputs.first, inputs.count == 1 else { return XCTFail("\(inputs)") }
        XCTAssertEqual(ink.strokes.count, 1)
    }

    /// Several notes written into one cell in one go each toggle.
    func testSeveralNotesInOneCell() {
        makeLayer(noteMode: true)
        _ = coordinator.focus(40)
        write([CGPoint(x: 205, y: 205), CGPoint(x: 206, y: 220)])
        write([CGPoint(x: 220, y: 205), CGPoint(x: 228, y: 220)])
        write([CGPoint(x: 235, y: 205), CGPoint(x: 245, y: 220)])
        _ = scribble("1", settle: false)
        _ = scribble("2", settle: false)
        _ = scribble("4", settle: false)
        coordinator.flush()
        XCTAssertEqual(inputs, [.note(1, cell: 40), .note(2, cell: 40), .note(4, cell: 40)])
    }

    func testPiecesResolveToNotes() {
        XCTAssertEqual(resolveNotes(["124"], columns: 0), [1, 2, 4]) // Scribble read them as one text
        XCTAssertEqual(resolveNotes(["1 2 4"], columns: 1), [1, 2, 4])
        XCTAssertEqual(resolveNotes(["1", "2", "4"], columns: 3), [1, 2, 4])
        XCTAssertEqual(resolveNotes(["3", "3"], columns: 2), [3]) // toggles once
        XCTAssertEqual(resolveNotes(["4", "1"], columns: 1), [4]) // one 4 in two strokes
        XCTAssertEqual(resolveNotes(["L", "1"], columns: 2), [4])
        XCTAssertEqual(resolveNotes(["7", "-"], columns: 1), [7])
        XCTAssertEqual(resolveNotes(["x"], columns: 1), [])
    }

    func testColumnCount() {
        XCTAssertEqual(columnCount([]), 0)
        // A 4: the bar crosses the upright, so both strokes overlap.
        XCTAssertEqual(columnCount([[CGPoint(x: 10, y: 0), CGPoint(x: 0, y: 20), CGPoint(x: 20, y: 20)],
                                    [CGPoint(x: 15, y: 0), CGPoint(x: 15, y: 30)]]), 1)
        XCTAssertEqual(columnCount([[CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 20)],
                                    [CGPoint(x: 30, y: 0), CGPoint(x: 40, y: 20)],
                                    [CGPoint(x: 10, y: 0), CGPoint(x: 20, y: 20)]]), 3)
    }

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
}
