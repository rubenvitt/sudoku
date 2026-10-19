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

    /// Scribble inserting `text` into the focused, empty field.
    private func scribble(_ text: String) -> Bool {
        coordinator.textField(coordinator.field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: text)
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
        view.addSubview(coordinator.field)
        defer { coordinator.field.resignFirstResponder(); view.removeFromSuperview() }
        XCTAssertNotNil(coordinator.focus(40))
        XCTAssertTrue(coordinator.field.isFirstResponder)
    }

    func testWrittenDigitEntersIntoFocusedCell() {
        makeLayer()
        _ = coordinator.focus(40) // no window: focus fails, but the field already sits over the cell
        XCTAssertEqual(coordinator.field.frame, CGRect(x: 200, y: 200, width: 50, height: 50))
        XCTAssertFalse(scribble("7"))
        XCTAssertFalse(scribble(" l")) // Scribble's leading space, look-alike for 1
        XCTAssertFalse(scribble("x"))
        XCTAssertEqual(inputs, [.digit(7, cell: 40), .digit(1, cell: 40)])
        XCTAssertEqual(coordinator.field.text, "") // the field never takes the text
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
        XCTAssertFalse(scribble("4"))
        XCTAssertEqual(inputs, [])
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
