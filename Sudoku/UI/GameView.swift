import SwiftUI
import SudokuEngine

enum CellInput: Equatable {
    /// `ink` is the handwriting the digit was recognized from; keypad digits have none.
    case digit(Int, cell: Int, ink: Ink? = nil)
    case note(Int, cell: Int)
    case clear(cell: Int)
}

struct GameView: View {
    @State var game: Game
    @State var noteMode = false
    @State private var selection: Int?
    @State private var focus: Set<Int> = []
    /// Handwriting per cell; shown instead of the typeset digit while the cell holds the digit it was written as.
    @State private var ink: [Int: Ink]
    @State private var banner: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass

    let store: Store
    let onNewGame: (Difficulty) -> Void
    let onMenu: () -> Void
    let onLeave: () -> Void

    init(game: Game, store: Store, onNewGame: @escaping (Difficulty) -> Void, onMenu: @escaping () -> Void,
         onLeave: @escaping () -> Void = {}) {
        _game = State(initialValue: game)
        _ink = State(initialValue: store.loadInk())
        self.store = store
        self.onNewGame = onNewGame
        self.onMenu = onMenu
        self.onLeave = onLeave
    }

    var body: some View {
        GeometryReader { geo in
            if sizeClass == .compact {
                // iPhone and narrow iPad windows: one row of keys, the actions right above it within thumb reach.
                VStack(spacing: 14) {
                    board
                    controls(actionColumns: 6, digitColumns: 9, keyHeight: 58)
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 8)
            } else if geo.size.width > geo.size.height {
                HStack(alignment: .center, spacing: 32) {
                    board
                    controls(actionColumns: 3, digitColumns: 3, keyHeight: 76).frame(width: 320)
                }
                .padding(24)
            } else {
                VStack(spacing: 20) {
                    board
                    controls(actionColumns: 6, digitColumns: 9, keyHeight: 72)
                }
                .padding(24)
            }
        }
        // Taps that land beside the grid and the keys clear the selection, and with it the highlighted digit.
        .background {
            Color.clear
                .contentShape(.rect)
                .onTapGesture { selection = nil }
                .accessibilityHidden(true)
        }
        .disabled(game.isSolved)
        .accessibilityHidden(game.isSolved)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(game.isSolved)
        .toolbar {
            ToolbarItem(placement: .principal) { title }
        }
        .overlay {
            if game.isSolved {
                ResultView(game: game, onNewGame: { onNewGame(game.puzzle.difficulty) }, onMenu: onMenu)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(duration: 0.4), value: game.isSolved)
        .animation(.easeInOut(duration: 0.2), value: banner)
        .sensoryFeedback(.impact(weight: .light), trigger: game.entries)
        .sensoryFeedback(.selection, trigger: noteMode)
        .sensoryFeedback(.success, trigger: game.isSolved) { _, solved in solved }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !game.isSolved {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                if game.isSolved { return } // solved during the sleep: the result shows the final time
                game.elapsed += 1
            }
        }
        .onChange(of: scenePhase) { if scenePhase != .active && !game.isSolved { save() } }
        .onDisappear { save(); onLeave() }
    }

    private var title: some View {
        VStack(spacing: 0) {
            Text(game.puzzle.difficulty.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(game.elapsed.clock)
                .font(.system(.headline, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(game.puzzle.difficulty.title), Zeit \(game.elapsed.clock)")
    }

    private var board: some View {
        GridView(game: game, selection: $selection, focus: focus, ink: ink)
            .equatable()
            .aspectRatio(1, contentMode: .fit)
            // Before `.frame`, so the layer covers exactly the grid and shares its coordinates.
            .overlay {
                ScribbleLayer(givens: givens, noteMode: noteMode, onInput: apply,
                              onSelect: { selection = $0 }, onUndo: { mutate { $0.undo() } })
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var givens: Set<Int> {
        Set(game.puzzle.givens.cells.indices.filter { game.puzzle.givens.cells[$0] != 0 })
    }

    /// How often each digit 1…9 may still be placed; index 0 is unused.
    private var remaining: [Int] {
        var counts = [Int](repeating: 9, count: 10)
        for value in game.entries.cells where value != 0 { counts[Int(value)] -= 1 }
        return counts
    }

    private func controls(actionColumns: Int, digitColumns: Int, keyHeight: CGFloat) -> some View {
        VStack(spacing: 14) {
            // Zero-height anchor: the banner grows upward over free space, so the grid's size
            // (and the Scribble layer laid over it) never changes when it appears.
            Color.clear.frame(height: 0).overlay(alignment: .bottom) {
                if let banner {
                    Button { self.banner = nil } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: "lightbulb.max.fill")
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)
                            Text(banner)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.callout)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .background(.regularMaterial, in: .rect(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHint("Schließt den Hinweis")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: actionColumns), spacing: 8) {
                actions
            }
            NumberBar(columns: digitColumns, keyHeight: keyHeight, noteMode: noteMode, remaining: remaining) { digit in
                guard let cell = selection else { return }
                apply(noteMode ? .note(digit, cell: cell) : .digit(digit, cell: cell))
            }
        }
        // A tap between two keys is a near miss, not a tap outside: it keeps the selection.
        .contentShape(.rect)
        .onTapGesture {}
    }

    @ViewBuilder private var actions: some View {
        ActionButton(title: "Rückgängig", symbol: "arrow.uturn.backward") { mutate { $0.undo() } }
            .disabled(!game.canUndo)
        ActionButton(title: "Wiederholen", symbol: "arrow.uturn.forward") { mutate { $0.redo() } }
            .disabled(!game.canRedo)
        ActionButton(title: "Löschen", symbol: "eraser") {
            guard let cell = selection else { return }
            apply(.clear(cell: cell))
        }
        ActionButton(title: "Notizen", symbol: "pencil", isOn: noteMode) { noteMode.toggle() }
        ActionButton(title: "Tipp", symbol: "lightbulb") { showHint() }
        ActionButton(title: "Prüfen", accessibilityTitle: "Überprüfen", symbol: "checkmark.circle") { check() }
    }

    func apply(_ input: CellInput) {
        guard !game.isSolved else { return } // Scribble commits its text a moment after the pencil lifts
        mutate { game in
            switch input {
            case let .digit(digit, cell, written):
                game.setDigit(digit, at: cell)
                // Old ink is kept when another digit replaces it, so undo brings the handwriting back.
                if let written { ink[cell] = written } else if ink[cell]?.digit == digit { ink[cell] = nil }
            case let .note(digit, cell): game.toggleNote(digit, at: cell)
            case let .clear(cell): game.clear(cell)
            }
        }
    }

    /// Runs `change` and, only if the board actually changed, saves and evaluates the new state.
    private func mutate(_ change: (inout Game) -> Void) {
        let before = (game.entries, game.notes)
        change(&game)
        guard before != (game.entries, game.notes) else { return }
        banner = nil
        focus = []
        if game.isSolved {
            try? store.deleteGame() // a leftover save only offers a finished game once more
            return
        }
        if game.isFull { game.markErrors() }
        save()
    }

    private func showHint() {
        switch game.hint() {
        case let .wrongEntry(row):
            announce("In Zeile \(row) stimmt etwas nicht.")
        case let .step(step):
            focus = Set(step.focus)
            announce("\(step.technique.title): \(step.explanation)")
        case nil:
            announce("Für diese Stellung habe ich keinen Tipp.")
        }
        save()
    }

    private func check() {
        let errors = game.check().count
        announce(errors == 0 ? "Keine Fehler gefunden." : "\(errors) Fehler markiert.")
        save()
    }

    private func announce(_ text: String) {
        banner = text
        AccessibilityNotification.Announcement(text).post()
    }

    private func save() {
        guard !game.isSolved else { return } // the save was deleted on solve; never bring it back
        try? store.save(game, ink: ink) // nothing to offer the player beyond retrying on the next move
    }
}

/// Symbol above a short caption; `isOn` marks a toggle that is switched on.
private struct ActionButton: View {
    let title: String
    var accessibilityTitle: String?
    let symbol: String
    var isOn: Bool?
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 34)
                    .foregroundStyle(isOn == true ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                    .background {
                        if isOn == true {
                            Capsule().fill(.tint)
                        }
                    }
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .animation(.spring(duration: 0.25), value: isOn)
        .accessibilityLabel(accessibilityTitle ?? title)
        .accessibilityAddTraits(isOn == true ? .isSelected : [])
    }
}

extension TimeInterval {
    var clock: String { Duration.seconds(self).formatted(.time(pattern: .minuteSecond)) }
}
