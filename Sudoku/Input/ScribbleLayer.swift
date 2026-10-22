import SwiftUI
import UIKit.UIGestureRecognizerSubclass

/// Transparent layer laid exactly over the grid. The pencil writes straight into any non-given cell:
/// Scribble (Apple's handwriting recognition) turns the ink into text, which the cell's own hidden text field
/// hands back here as a `CellInput`. One field per cell, so writing on in the next cell never redirects or drops
/// the text Scribble is still recognizing for the last one. The pencil's strokes are recorded alongside, so a written digit keeps its handwriting.
///
/// It takes every touch over the grid, so taps (select, two-finger undo) are handled here, not by the cell buttons.
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
        context.coordinator.view = view

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.select))
        tap.allowedTouchTypes = [UITouch.TouchType.direct, .pencil, .indirectPointer].map { $0.rawValue as NSNumber }
        let twoFingerTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.undo))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(twoFingerTap)
        view.addGestureRecognizer(InkRecorder { [weak coordinator = context.coordinator] in coordinator?.record($0) })
        return view
    }

    /// Runs every second (timer tick): only refresh the values the coordinator reads.
    func updateUIView(_ view: LayerView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ view: LayerView, coordinator: Coordinator) {
        coordinator.fields.values.forEach { $0.resignFirstResponder() }
    }

    /// Keeps every touch on the layer itself, so fingers reach its tap recognizers and never the hidden field.
    final class LayerView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            self.point(inside: point, with: event) ? self : nil
        }
    }

    /// No caret or selection: a clear tint does not hide the caret on the device.
    final class HiddenField: UITextField {
        var cell = 0

        override func caretRect(for position: UITextPosition) -> CGRect { .zero }
        override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { [] }
    }

    /// Watches the pencil without ever recognizing, so Scribble and the tap still get every touch; reports each finished stroke.
    final class InkRecorder: UIGestureRecognizer, UIGestureRecognizerDelegate {
        private let onStroke: ([CGPoint]) -> Void
        private var stroke: [CGPoint] = []

        init(onStroke: @escaping ([CGPoint]) -> Void) {
            self.onStroke = onStroke
            super.init(target: nil, action: nil)
            allowedTouchTypes = [UITouch.TouchType.pencil.rawValue as NSNumber]
            cancelsTouchesInView = false
            delaysTouchesEnded = false
            delegate = self
        }

        override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            stroke = touches.first.map { [$0.preciseLocation(in: view)] } ?? []
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let touch = touches.first else { return }
            stroke += (event.coalescedTouches(for: touch) ?? [touch]).map { $0.preciseLocation(in: view) }
        }

        /// Scribble may cancel the touch once it takes over the writing; what was recorded up to then still counts.
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { finish() }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { finish() }

        private func finish() {
            if stroke.count > 1 { onStroke(stroke) } // a single point is a tap, not writing
            stroke = []
            state = .failed
        }

        override func reset() { stroke = [] }
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ScribbleLayer
        weak var view: UIView?
        /// Receive Scribble's text, one per cell that was written into, created on first use.
        private(set) var fields: [Int: HiddenField] = [:]
        private(set) var focused: Int?
        /// Strokes not yet matched to a recognized digit, in layer coordinates.
        private var pending: [(points: [CGPoint], time: Date)] = []

        init(_ parent: ScribbleLayer) {
            self.parent = parent
            super.init()
        }

        /// `cell`'s field: invisible, no keyboard; the digit bias helps recognition.
        func field(for cell: Int) -> HiddenField {
            if let field = fields[cell] { return field }
            let field = HiddenField()
            field.cell = cell
            field.delegate = self
            field.keyboardType = .numberPad
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.textAlignment = .center
            field.textColor = .clear
            field.inputView = UIView() // no on-screen keyboard; a hardware keyboard still types digits
            field.inputAssistantItem.leadingBarButtonGroups = []
            field.inputAssistantItem.trailingBarButtonGroups = []
            view?.addSubview(field)
            fields[cell] = field
            return field
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

        /// Keeps a finished stroke until Scribble's text for it arrives; strokes that never turned into a digit expire.
        func record(_ stroke: [CGPoint], at time: Date = .now) {
            pending.removeAll { time.timeIntervalSince($0.time) > 5 }
            pending.append((stroke, time))
        }

        /// Takes the pending strokes centered in `cell` as the handwriting of `digit`.
        private func takeInk(_ digit: Int, in cell: Int) -> Ink? {
            guard let geometry else { return nil }
            let isInCell = { (points: [CGPoint]) -> Bool in
                let xs = points.map(\.x), ys = points.map(\.y)
                guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return false }
                return geometry.cell(at: CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)) == cell
            }
            let strokes = pending.map(\.points).filter(isInCell)
            pending.removeAll { isInCell($0.points) }
            return Ink(digit: digit, strokes: strokes, in: geometry.frame(of: cell))
        }

        /// Puts `cell`'s hidden, always empty field over it and focuses it. Any text in it would sit under the pencil, and Scribble
        /// reads strokes over existing text as gestures (select, delete) instead of writing.
        func focus(_ cell: Int) -> UITextField? {
            guard let geometry, !parent.givens.contains(cell) else { return nil }
            focused = cell
            let input = field(for: cell)
            input.frame = geometry.frame(of: cell) // again on every focus: the board may have been resized
            return input.isFirstResponder || input.becomeFirstResponder() ? input : nil
        }

        /// The field never takes the text, so it stays empty: each recognized digit becomes a `CellInput` for the
        /// field's own cell, even when the pencil has already moved on to another one.
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard let cell = (textField as? HiddenField)?.cell, !parent.givens.contains(cell) else { return false }
            if let digit = mapRecognized(string) {
                let ink = takeInk(digit, in: cell) // taken in note mode too, so a note's strokes never end up on a digit
                parent.onInput(parent.noteMode ? .note(digit, cell: cell) : .digit(digit, cell: cell, ink: ink))
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
        focused == elementIdentifier && fields[elementIdentifier]?.isFirstResponder == true
    }

    func indirectScribbleInteraction(_ interaction: any UIInteraction, frameForElement elementIdentifier: Int) -> CGRect {
        geometry?.frame(of: elementIdentifier) ?? .null
    }

    func indirectScribbleInteraction(_ interaction: any UIInteraction, focusElementIfNeeded elementIdentifier: Int,
                                     referencePoint focusReferencePoint: CGPoint,
                                     completion: @escaping ((any UIResponder & UITextInput)?) -> Void) {
        if focused == elementIdentifier, let field = fields[elementIdentifier], field.isFirstResponder { return completion(field) }
        completion(focus(elementIdentifier))
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
