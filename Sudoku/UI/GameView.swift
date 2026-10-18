import SwiftUI
import SudokuEngine

enum CellInput {
    case digit(Int, cell: Int)
    case note(Int, cell: Int)
    case clear(cell: Int)
}

struct GameView: View {
    @State var game: Game
    @State var noteMode = false
    @State private var selection: Int?
    @State private var focus: Set<Int> = []
    @State private var banner: String?
    @Environment(\.scenePhase) private var scenePhase

    let store: Store
    let onNewGame: (Difficulty) -> Void
    let onMenu: () -> Void

    init(game: Game, store: Store, onNewGame: @escaping (Difficulty) -> Void, onMenu: @escaping () -> Void) {
        _game = State(initialValue: game)
        self.store = store
        self.onNewGame = onNewGame
        self.onMenu = onMenu
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 20) {
                toolbar
                if geo.size.width > geo.size.height {
                    HStack(alignment: .center, spacing: 28) {
                        board
                        controls(columns: 3).frame(width: 300)
                    }
                } else {
                    board
                    controls(columns: 10)
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if game.isSolved {
                ResultView(game: game, onNewGame: { onNewGame(game.puzzle.difficulty) }, onMenu: onMenu)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(duration: 0.4), value: game.isSolved)
        .animation(.easeInOut(duration: 0.2), value: banner)
        .sensoryFeedback(.impact(weight: .light), trigger: game.entries)
        .sensoryFeedback(.success, trigger: game.isSolved) { _, solved in solved }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !game.isSolved {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                game.elapsed += 1
            }
        }
        .onChange(of: scenePhase) { if scenePhase != .active && !game.isSolved { save() } }
    }

    private var board: some View {
        GridView(game: game, selection: $selection, focus: focus, onTwoFingerTap: { mutate { $0.undo() } })
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controls(columns: Int) -> some View {
        VStack(spacing: 16) {
            if let banner {
                Text(banner)
                    .font(.callout)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: .rect(cornerRadius: 16))
                    .onTapGesture { self.banner = nil }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            NumberBar(columns: columns, noteMode: noteMode, onDigit: { digit in
                guard let cell = selection else { return }
                apply(noteMode ? .note(digit, cell: cell) : .digit(digit, cell: cell))
            }, onClear: {
                guard let cell = selection else { return }
                apply(.clear(cell: cell))
            })
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            toolButton("Menü", "chevron.backward") { save(); onMenu() }
            Spacer()
            Text(game.elapsed.clock)
                .font(.system(.title2, design: .rounded, weight: .medium).monospacedDigit())
                .accessibilityLabel("Zeit \(game.elapsed.clock)")
            Spacer()
            toolButton("Rückgängig", "arrow.uturn.backward") { mutate { $0.undo() } }
                .disabled(!game.canUndo)
            toolButton("Wiederholen", "arrow.uturn.forward") { mutate { $0.redo() } }
                .disabled(!game.canRedo)
            toolButton("Notizen", noteMode ? "pencil.circle.fill" : "pencil.circle") { noteMode.toggle() }
                .accessibilityAddTraits(noteMode ? .isSelected : [])
            toolButton("Tipp", "lightbulb") { showHint() }
            toolButton("Überprüfen", "checkmark.circle") { _ = game.check(); save() }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
    }

    private func toolButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.iconOnly)
                .font(.title2)
                .frame(width: 52, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
    }

    func apply(_ input: CellInput) {
        mutate { game in
            switch input {
            case let .digit(digit, cell): game.setDigit(digit, at: cell)
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
        if game.isFull { _ = game.check() }
        save()
    }

    private func showHint() {
        switch game.hint() {
        case let .wrongEntry(row):
            banner = "In Zeile \(row) stimmt etwas nicht."
        case let .step(step):
            focus = Set(step.focus)
            banner = step.explanation
        case nil:
            banner = "Für diese Stellung habe ich keinen Tipp."
        }
        save()
    }

    private func save() {
        try? store.save(game) // nothing to offer the player beyond retrying on the next move
    }
}

extension TimeInterval {
    var clock: String { Duration.seconds(self).formatted(.time(pattern: .minuteSecond)) }
}
