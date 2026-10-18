import SwiftUI
import PencilKit

/// Transparent ink layer laid exactly over the grid. Each cell's pencil strokes become one
/// `CellInput` 0.4 s after the last stroke there; the ink is then removed.
///
/// It takes every touch over the grid: UIKit hit-tests before a touch's type is known, so fingers
/// cannot fall through to the cell buttons. Finger taps (select, two-finger undo) are handled here instead.
struct PencilCanvas: UIViewRepresentable {
    static let minimumConfidence: Float = 0.3

    let givens: Set<Int>
    let noteMode: Bool
    let onInput: (CellInput) -> Void
    var onSelect: (Int) -> Void = { _ in }
    var onUndo: () -> Void = {}
    var recognizer: any DigitRecognizer = VisionDigitRecognizer()

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .pencilOnly
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3) // PencilKit shows black ink white in dark mode
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.accessibilityElementsHidden = true // VoiceOver keeps reaching the cell buttons below
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.select))
        tap.allowedTouchTypes = [UITouch.TouchType.direct, .indirectPointer].map { $0.rawValue as NSNumber }
        let twoFingerTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.undo))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        canvas.addGestureRecognizer(tap)
        canvas.addGestureRecognizer(twoFingerTap)
        return canvas
    }

    /// Runs every second (timer tick): only refresh the values the coordinator reads, never the drawing.
    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvas
        weak var canvas: PKCanvasView?
        private var knownStrokes: Set<Date> = []
        private var pending: [Int: [PKStroke]] = [:]
        private var debounces: [Int: Task<Void, Never>] = [:]
        private var isUsingTool = false
        private var deferredEdits: [() -> Void] = []
        private var isStopped = false

        init(_ parent: PencilCanvas) { self.parent = parent }

        private var router: StrokeRouter? {
            canvas.map { StrokeRouter(gridFrame: $0.bounds, givens: parent.givens) }
        }

        @objc func select(_ tap: UITapGestureRecognizer) {
            guard let canvas else { return }
            // Givens stay selectable: selecting one highlights its digit across the board.
            let cell = StrokeRouter(gridFrame: canvas.bounds, givens: []).cell(for: CGRect(origin: tap.location(in: canvas), size: .zero))
            if let cell { parent.onSelect(cell) }
        }

        @objc func undo() { parent.onUndo() }

        /// The game view is going away: no late recognition may still enter (and save) a digit.
        func stop() {
            isStopped = true
            debounces.values.forEach { $0.cancel() }
            debounces = [:]
            pending = [:]
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) { isUsingTool = true }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isUsingTool = false
            let edits = deferredEdits
            deferredEdits = []
            edits.forEach { $0() }
        }

        /// Replacing the drawing mid-stroke would cut the stroke being written, e.g. in the neighbouring cell.
        private func editDrawing(_ edit: @escaping () -> Void) {
            if isUsingTool { deferredEdits.append(edit) } else { edit() }
        }

        /// Also fires for our own removals and re-inks, which keep stroke identity and so add nothing.
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let strokes = canvasView.drawing.strokes
            let added = strokes.filter { !knownStrokes.contains($0.path.creationDate) }
            knownStrokes = Set(strokes.map(\.path.creationDate))
            guard !added.isEmpty, let router else { return }
            var discarded: [PKStroke] = []
            for stroke in added {
                guard let cell = router.cell(for: stroke.points.boundingBox) else { discarded.append(stroke); continue }
                pending[cell, default: []].append(stroke)
                debounces[cell]?.cancel()
                debounces[cell] = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(0.4)) } catch { return }
                    await self?.finish(cell)
                }
            }
            if !discarded.isEmpty { remove(discarded) }
        }

        private func finish(_ cell: Int) async {
            debounces[cell] = nil
            guard let strokes = pending.removeValue(forKey: cell), let router else { return }
            let paths = strokes.map(\.points)
            let bounds = paths.joined().boundingBox
            guard let target = router.cell(for: bounds) else { return remove(strokes) }
            if paths.contains(where: router.isScratchOut) {
                parent.onInput(.clear(cell: target))
                return remove(strokes)
            }
            guard !router.isSpeck(bounds) else { return fade(strokes) }
            let asNote = parent.noteMode || router.isNote(bounds)
            let result = await parent.recognizer.recognize(PKDrawing(strokes: strokes))
            guard !isStopped else { return }
            guard let result, result.confidence >= PencilCanvas.minimumConfidence else { return fade(strokes) }
            parent.onInput(asNote ? .note(result.digit, cell: target) : .digit(result.digit, cell: target))
            remove(strokes)
        }

        /// Unrecognized ink stays visible in grey for a second, so the player sees it was not taken.
        private func fade(_ strokes: [PKStroke]) {
            let ids = Set(strokes.map(\.path.creationDate))
            editDrawing { [weak self] in
                guard let canvas = self?.canvas else { return }
                canvas.drawing.strokes = canvas.drawing.strokes.map { stroke in
                    guard ids.contains(stroke.path.creationDate) else { return stroke }
                    var grey = stroke
                    grey.ink = PKInk(.pen, color: .systemGray)
                    return grey
                }
            }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                self?.remove(strokes)
            }
        }

        /// By identity, never "everything in the cell": the player may already be writing there again.
        private func remove(_ strokes: [PKStroke]) {
            let ids = Set(strokes.map(\.path.creationDate))
            editDrawing { [weak self] in self?.canvas?.drawing.strokes.removeAll { ids.contains($0.path.creationDate) } }
        }
    }
}

private extension PKStroke {
    /// Control points in canvas coordinates; unlike `renderBounds` they exclude the ink width.
    var points: [CGPoint] { path.map { $0.location.applying(transform) } }
}

private extension Sequence<CGPoint> {
    var boundingBox: CGRect {
        reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
    }
}
