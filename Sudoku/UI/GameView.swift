import SwiftUI
import SudokuEngine

enum CellInput: Equatable {
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
    @Environment(\.horizontalSizeClass) private var sizeClass

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
            if sizeClass == .compact {
                // iPhone and narrow iPad windows: the actions move down to the keys, within thumb reach.
                VStack(spacing: 12) {
                    compactToolbar
                    board
                    controls(columns: 5, compact: true)
                }
                .padding(16)
            } else {
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
        }
        .disabled(game.isSolved)
        .accessibilityHidden(game.isSolved)
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
                if game.isSolved { return } // solved during the sleep: the result shows the final time
                game.elapsed += 1
            }
        }
        .onChange(of: scenePhase) { if scenePhase != .active && !game.isSolved { save() } }
    }

    private var board: some View {
        GridView(game: game, selection: $selection, focus: focus)
            .equatable()
            .aspectRatio(1, contentMode: .fit)
            // Before `.frame`, so the canvas covers exactly the grid and shares its coordinates.
            .overlay {
                PencilCanvas(givens: givens, noteMode: noteMode, onInput: apply,
                             onSelect: { selection = $0 }, onUndo: { mutate { $0.undo() } })
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var givens: Set<Int> {
        Set(game.puzzle.givens.cells.indices.filter { game.puzzle.givens.cells[$0] != 0 })
    }

    private func controls(columns: Int, compact: Bool = false) -> some View {
        VStack(spacing: compact ? 12 : 16) {
            // Zero-height anchor: the banner grows upward over free space, so the grid's size
            // (and the pencil canvas laid over it) never changes when it appears.
            Color.clear.frame(height: 0).overlay(alignment: .bottom) {
                if let banner {
                    Button { self.banner = nil } label: {
                        Text(banner)
                            .font(.callout)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.thinMaterial, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHint("Schließt den Hinweis")
                    .transition(.opacity)
                }
            }
            if compact {
                HStack(spacing: 0) { actions(stretch: true) }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.regularMaterial, in: .capsule)
            }
            NumberBar(columns: columns, keyHeight: compact ? 52 : 64, noteMode: noteMode, onDigit: { digit in
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
            menuButton
            Spacer()
            clock
            Spacer()
            actions()
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
    }

    private var compactToolbar: some View {
        HStack(spacing: 6) {
            menuButton
            Spacer()
            clock
            Spacer()
            Color.clear.frame(width: 52, height: 44) // balances the menu button, so the clock stays centred
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
    }

    private var menuButton: some View {
        toolButton("Menü", "chevron.backward") { save(); onMenu() }
    }

    private var clock: some View {
        Text(game.elapsed.clock)
            .font(.system(.title2, design: .rounded, weight: .medium).monospacedDigit())
            .accessibilityLabel("Zeit \(game.elapsed.clock)")
    }

    /// `stretch` spreads the buttons across the compact action row.
    @ViewBuilder private func actions(stretch: Bool = false) -> some View {
        toolButton("Rückgängig", "arrow.uturn.backward", stretch: stretch) { mutate { $0.undo() } }
            .disabled(!game.canUndo)
        toolButton("Wiederholen", "arrow.uturn.forward", stretch: stretch) { mutate { $0.redo() } }
            .disabled(!game.canRedo)
        toolButton("Notizen", noteMode ? "pencil.circle.fill" : "pencil.circle", stretch: stretch) { noteMode.toggle() }
            .accessibilityAddTraits(noteMode ? .isSelected : [])
        toolButton("Tipp", "lightbulb", stretch: stretch) { showHint() }
        toolButton("Überprüfen", "checkmark.circle", stretch: stretch) { check() }
    }

    private func toolButton(_ title: String, _ symbol: String, stretch: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.iconOnly)
                .font(.title2)
                .frame(minWidth: 52, maxWidth: stretch ? .infinity : 52, minHeight: 44, maxHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
    }

    func apply(_ input: CellInput) {
        guard !game.isSolved else { return } // pencil input lands 0.4 s + recognition after the stroke
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
        try? store.save(game) // nothing to offer the player beyond retrying on the next move
    }
}

extension TimeInterval {
    var clock: String { Duration.seconds(self).formatted(.time(pattern: .minuteSecond)) }
}
