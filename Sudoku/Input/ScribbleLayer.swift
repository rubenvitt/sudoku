import SwiftUI
import UIKit.UIGestureRecognizerSubclass

/// Transparent layer laid exactly over the grid. The pencil writes straight into any non-given cell:
/// Scribble (Apple's handwriting recognition) turns the ink into text, which the cell's own hidden text field
/// hands back here as a `CellInput`. One field per cell, so writing on in the next cell never redirects or drops
/// the text Scribble is still recognizing for the last one. The pencil's strokes are recorded alongside, so a written digit keeps its handwriting.
/// A cell's text only counts once the pencil has left that cell for a moment, so a digit written in two strokes (a 4, a 5) stays one digit.
///
/// It takes every touch over the grid, so taps (select, two-finger undo) are handled here, not by the cell buttons.
struct ScribbleLayer: UIViewRepresentable {
    let givens: Set<Int>
    let noteMode: Bool
    let onInput: (CellInput) -> Void
    /// Colour of the strokes shown while a cell waits for its last stroke.
    var inkColor: Color = .accentColor
    var onSelect: (Int) -> Void = { _ in }
    var onUndo: () -> Void = {}
    /// Counts, per cell, the edits that did not come from the pencil (keypad, erase, undo). Text still being recognized for a
    /// cell is dropped once its count moves, so a late result never overwrites what was entered there in the meantime.
    var revisions: [Int: Int] = [:]

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
        view.addGestureRecognizer(InkRecorder(
            onBegin: { [weak coordinator = context.coordinator] in coordinator?.strokeBegan(at: $0) },
            onEnd: { [weak coordinator = context.coordinator] in coordinator?.strokeEnded($0) }))
        return view
    }

    /// Runs every second (timer tick): only refresh the values the coordinator reads.
    func updateUIView(_ view: LayerView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ view: LayerView, coordinator: Coordinator) {
        coordinator.flush() // leaving the game mid-digit still enters what was written
        coordinator.fields.values.forEach { $0.resignFirstResponder() }
    }

    /// Keeps every touch on the layer itself, so fingers reach its tap recognizers and never the hidden field.
    final class LayerView: UIView {
        /// Strokes of cells still waiting for a further stroke, so the handwriting never vanishes while it waits.
        let preview = CAShapeLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            preview.fillColor = nil
            preview.lineCap = .round
            preview.lineJoin = .round
            layer.addSublayer(preview)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

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

    /// Watches the pencil without ever recognizing, so Scribble and the tap still get every touch; reports where each stroke
    /// starts and, once the pencil lifts, the whole stroke (a single point for a tap).
    final class InkRecorder: UIGestureRecognizer, UIGestureRecognizerDelegate {
        private let onBegin: (CGPoint) -> Void
        private let onEnd: ([CGPoint]) -> Void
        private var stroke: [CGPoint] = []

        init(onBegin: @escaping (CGPoint) -> Void, onEnd: @escaping ([CGPoint]) -> Void) {
            self.onBegin = onBegin
            self.onEnd = onEnd
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
            if let start = stroke.first { onBegin(start) }
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let touch = touches.first else { return }
            stroke += (event.coalescedTouches(for: touch) ?? [touch]).map { $0.preciseLocation(in: view) }
        }

        /// Scribble may cancel the touch once it takes over the writing; what was recorded up to then still counts.
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { finish() }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { finish() }

        private func finish() {
            if !stroke.isEmpty { onEnd(stroke) }
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
        /// How long a cell waits after its last stroke before its text counts.
        var settle: Duration = .milliseconds(450)
        /// Scribble's text per cell, possibly in pieces (a 4 can arrive as "L" and "1"), until the cell has settled.
        private var recognized: [Int: [String]] = [:]
        private var commits: [Int: Task<Void, Never>] = [:]
        /// The cell the pencil is writing in right now; its text waits until the stroke ends.
        private var writing: Int?
        /// Each waiting cell's revision when the pencil started writing there.
        private var baselines: [Int: Int] = [:]

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

        /// The pencil is down again: the cell it writes in is not done yet.
        func strokeBegan(at point: CGPoint) {
            writing = geometry?.cell(at: point)
            if let writing {
                commits.removeValue(forKey: writing)?.cancel()
                // A further stroke (or a stray dot) while the cell waits keeps the cell's first baseline.
                if recognized[writing] == nil { baselines[writing] = parent.revisions[writing, default: 0] }
            }
        }

        /// The pencil lifted: keep the stroke (a single point is a tap, not writing) and let waiting cells settle from now.
        func strokeEnded(_ stroke: [CGPoint]) {
            writing = nil
            if stroke.count > 1 { record(stroke) }
            for cell in recognized.keys where commits[cell] == nil { schedule(cell) }
            updatePreview()
        }

        private func schedule(_ cell: Int) {
            commits[cell]?.cancel()
            commits[cell] = Task { [weak self, settle] in
                try? await Task.sleep(for: settle)
                guard !Task.isCancelled else { return }
                self?.commit(cell)
            }
        }

        /// Enters what was written into `cell` as one digit with all of its strokes, or as notes.
        /// Nothing is entered when the cell was edited another way since the pencil started writing there.
        func commit(_ cell: Int) {
            commits.removeValue(forKey: cell)?.cancel()
            defer { updatePreview() }
            let baseline = baselines.removeValue(forKey: cell)
            guard let pieces = recognized.removeValue(forKey: cell), !parent.givens.contains(cell) else { return }
            guard baseline == nil || baseline == parent.revisions[cell, default: 0] else {
                pending.removeAll { isCentered($0.points, in: cell) } // the overridden handwriting goes with its text
                return
            }
            if parent.noteMode {
                // Strokes are taken in note mode too, so a note's strokes never end up on a digit.
                let strokes = takeStrokes(in: cell)
                for digit in resolveNotes(pieces, columns: columnCount(strokes)) { parent.onInput(.note(digit, cell: cell)) }
                return
            }
            guard let digit = resolveRecognized(pieces) else { return }
            parent.onInput(.digit(digit, cell: cell, ink: takeInk(digit, in: cell)))
        }

        /// Commits every waiting cell now.
        func flush() {
            for cell in Array(recognized.keys) { commit(cell) }
        }

        /// Draws the strokes of the cells that wait, as the board will draw them once they are entered.
        private func updatePreview() {
            guard let view = view as? LayerView, let geometry else { return }
            let path = CGMutablePath()
            for cell in recognized.keys {
                let frame = geometry.frame(of: cell)
                let strokes = pending.map(\.points).filter { isCentered($0, in: cell) }
                guard let ink = Ink(digit: 0, strokes: strokes, in: frame) else { continue }
                path.addPath(ink.path(side: frame.width).cgPath, transform: CGAffineTransform(translationX: frame.minX, y: frame.minY))
            }
            let side = view.bounds.width / 9
            view.preview.frame = view.bounds
            view.preview.lineWidth = max(1.5, side * 0.05)
            view.preview.strokeColor = UIColor(parent.inkColor).resolvedColor(with: view.traitCollection).cgColor
            view.preview.path = path
        }

        private func isCentered(_ points: [CGPoint], in cell: Int) -> Bool {
            let xs = points.map(\.x), ys = points.map(\.y)
            guard let geometry, let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return false }
            return geometry.cell(at: CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)) == cell
        }

        /// Takes the pending strokes centered in `cell` as the handwriting of `digit`.
        private func takeInk(_ digit: Int, in cell: Int) -> Ink? {
            guard let geometry else { return nil }
            return Ink(digit: digit, strokes: takeStrokes(in: cell), in: geometry.frame(of: cell))
        }

        private func takeStrokes(in cell: Int) -> [[CGPoint]] {
            let strokes = pending.map(\.points).filter { isCentered($0, in: cell) }
            pending.removeAll { isCentered($0.points, in: cell) }
            return strokes
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

        /// The field never takes the text, so it stays empty: the text waits for the field's own cell to settle, then becomes
        /// a `CellInput` for that cell, even when the pencil has already moved on to another one.
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard let cell = (textField as? HiddenField)?.cell, !parent.givens.contains(cell) else { return false }
            if recognized[cell] == nil, baselines[cell] == nil { baselines[cell] = parent.revisions[cell, default: 0] }
            recognized[cell, default: []].append(string)
            if writing != cell { schedule(cell) } // otherwise the end of the stroke schedules it
            updatePreview()
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

/// Turns everything Scribble delivered for one cell into a digit. A digit written in two strokes can arrive in pieces:
/// a 4 as "L" and "1", a 7 as "7" and "-". A lone straight stroke (a 1) only counts when no other piece is a digit.
func resolveRecognized(_ pieces: [String]) -> Int? {
    if let digit = mapRecognized(pieces.joined()) { return digit }
    let characters = pieces.joined().filter { !$0.isWhitespace && !".,".contains($0) }
    if characters.count == 2, characters.contains(where: { "L+".contains($0) }),
       characters.contains(where: { "1lI|!".contains($0) }) { return 4 }
    let digits = pieces.compactMap(mapRecognized)
    return digits.last { $0 != 1 } ?? digits.last
}

/// Turns everything Scribble delivered for one cell in note mode into notes. Several notes can be written into a cell in
/// one go ("1 2 4"): they count when Scribble read them as one text, or when the strokes stand side by side in separate
/// `columns`. Otherwise the pieces are one character in several strokes (a 4 as "4" and "1") and give one note.
func resolveNotes(_ pieces: [String], columns: Int) -> [Int] {
    let characters = pieces.joined().filter { !$0.isWhitespace && !".,".contains($0) }
    let digits = characters.compactMap { mapRecognized(String($0)) }
    let readAsSeveral = pieces.contains { piece in piece.filter { !$0.isWhitespace && !".,".contains($0) }.count > 1 }
    if digits.count > 1, digits.count == characters.count, readAsSeveral || columns > 1 {
        var seen = Set<Int>()
        return digits.filter { seen.insert($0).inserted } // a note written twice still toggles once
    }
    return resolveRecognized(pieces).map { [$0] } ?? []
}

/// How many side-by-side groups the strokes form: strokes whose horizontal extents overlap belong to one character.
func columnCount(_ strokes: [[CGPoint]]) -> Int {
    let spans = strokes.compactMap { stroke -> ClosedRange<CGFloat>? in
        let xs = stroke.map(\.x)
        guard let low = xs.min(), let high = xs.max() else { return nil }
        return low...high
    }.sorted { $0.lowerBound < $1.lowerBound }
    var count = 0
    var right = -CGFloat.infinity
    for span in spans {
        if span.lowerBound > right { count += 1 }
        right = max(right, span.upperBound)
    }
    return count
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
