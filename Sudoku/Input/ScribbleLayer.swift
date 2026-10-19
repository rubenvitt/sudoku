import SwiftUI

/// Transparent layer laid exactly over the grid. The pencil writes straight into any non-given cell:
/// Scribble (Apple's handwriting recognition) turns the ink into text, which a hidden text field
/// hands back here as a `CellInput`.
///
/// It takes every touch over the grid, so finger taps (select, two-finger undo) are handled here, not by the cell buttons.
struct ScribbleLayer: UIViewRepresentable {
    let givens: Set<Int>
    let noteMode: Bool
    let onInput: (CellInput) -> Void
    var onSelect: (Int) -> Void = { _ in }
    var onUndo: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.backgroundColor = .clear
        view.accessibilityElementsHidden = true // VoiceOver keeps reaching the cell buttons below
        view.addInteraction(UIIndirectScribbleInteraction(delegate: context.coordinator))
        view.addSubview(context.coordinator.field)
        context.coordinator.view = view

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.select))
        tap.allowedTouchTypes = [UITouch.TouchType.direct, .indirectPointer].map { $0.rawValue as NSNumber }
        let twoFingerTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.undo))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(twoFingerTap)
        return view
    }

    /// Runs every second (timer tick): only refresh the values the coordinator reads.
    func updateUIView(_ view: LayerView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ view: LayerView, coordinator: Coordinator) {
        coordinator.field.resignFirstResponder()
    }

    /// Keeps every touch on the layer itself, so fingers reach its tap recognizers and never the hidden field.
    final class LayerView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            self.point(inside: point, with: event) ? self : nil
        }
    }

    /// No caret or selection: a clear tint does not hide the caret on the device.
    final class HiddenField: UITextField {
        override func caretRect(for position: UITextPosition) -> CGRect { .zero }
        override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { [] }
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ScribbleLayer
        weak var view: UIView?
        /// Receives Scribble's text for the focused cell. Invisible, no keyboard; the digit bias helps recognition.
        let field = HiddenField()
        private(set) var focused: Int?

        init(_ parent: ScribbleLayer) {
            self.parent = parent
            super.init()
            field.delegate = self
            field.keyboardType = .numberPad
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.textAlignment = .center
            field.textColor = .clear
            field.inputView = UIView() // no on-screen keyboard; a hardware keyboard still types digits
            field.inputAssistantItem.leadingBarButtonGroups = []
            field.inputAssistantItem.trailingBarButtonGroups = []
        }

        private var geometry: GridGeometry? {
            view.map { GridGeometry(gridFrame: $0.bounds) }
        }

        @objc func select(_ tap: UITapGestureRecognizer) {
            guard let view, let geometry else { return }
            // Givens stay selectable: selecting one highlights its digit across the board.
            if let cell = geometry.cell(at: tap.location(in: view)) { parent.onSelect(cell) }
        }

        @objc func undo() { parent.onUndo() }

        /// Puts the hidden, always empty field over `cell`. Any text in it would sit under the pencil, and Scribble
        /// reads strokes over existing text as gestures (select, delete) instead of writing.
        func focus(_ cell: Int) -> UITextField? {
            guard let geometry, !parent.givens.contains(cell) else { return nil }
            focused = cell
            field.frame = geometry.frame(of: cell)
            return field.isFirstResponder || field.becomeFirstResponder() ? field : nil
        }

        /// The field never takes the text, so it stays empty: each recognized digit becomes a `CellInput`.
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard let cell = focused else { return false }
            if let digit = mapRecognized(string) {
                parent.onInput(parent.noteMode ? .note(digit, cell: cell) : .digit(digit, cell: cell))
            }
            return false
        }
    }
}

extension ScribbleLayer.Coordinator: @preconcurrency UIIndirectScribbleInteractionDelegate {
    func indirectScribbleInteraction(_ interaction: any UIInteraction, requestElementsIn rect: CGRect,
                                     completion: @escaping ([Int]) -> Void) {
        guard let geometry else { return completion([]) }
        completion((0..<81).filter { !parent.givens.contains($0) && geometry.frame(of: $0).intersects(rect) })
    }

    func indirectScribbleInteraction(_ interaction: any UIInteraction, isElementFocused elementIdentifier: Int) -> Bool {
        focused == elementIdentifier && field.isFirstResponder
    }

    func indirectScribbleInteraction(_ interaction: any UIInteraction, frameForElement elementIdentifier: Int) -> CGRect {
        geometry?.frame(of: elementIdentifier) ?? .null
    }

    func indirectScribbleInteraction(_ interaction: any UIInteraction, focusElementIfNeeded elementIdentifier: Int,
                                     referencePoint focusReferencePoint: CGPoint,
                                     completion: @escaping ((any UIResponder & UITextInput)?) -> Void) {
        completion(focused == elementIdentifier && field.isFirstResponder ? field : focus(elementIdentifier))
    }
}

/// Maps Scribble's text for one handwritten character to a digit 1…9, folding common look-alikes.
func mapRecognized(_ text: String) -> Int? {
    let characters = text.filter { !$0.isWhitespace && !".,".contains($0) }
    guard characters.count == 1, let character = characters.first else { return nil }
    switch character {
    case "l", "I", "|", "!": return 1
    case "S", "s": return 5
    case "Z", "z": return 2
    case "g", "q": return 9
    case "B": return 8
    default:
        guard let digit = character.wholeNumberValue, (1...9).contains(digit) else { return nil }
        return digit
    }
}
