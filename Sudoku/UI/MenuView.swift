import SwiftUI
import SudokuEngine

struct MenuView: View {
    let store: Store
    @Environment(PuzzleStock.self) private var stock
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var saved: Game?
    @State private var path: [Session] = []
    @State private var pendingDiscard: Difficulty?
    @State private var starting: Difficulty?

    struct Session: Hashable {
        let id = UUID()
        let game: Game

        static func == (lhs: Session, rhs: Session) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            menu
                .navigationTitle("Sudoku")
                .navigationDestination(for: Session.self) { session in
                    // Leaving saves the game first, so reloading afterwards shows the current time.
                    GameView(game: session.game, store: store, onNewGame: start,
                             onMenu: { path.removeAll() }, onLeave: { saved = store.loadGame() })
                        .id(session.id)
                }
        }
    }

    private var menu: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if let saved { continueCard(saved) }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Neues Spiel").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        Text("Klassisch · 9 × 9").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                        ForEach(Difficulty.allCases, id: \.self) { difficulty in
                            difficultyButton(difficulty)
                        }
                    }
                }
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, sizeClass == .compact ? 16 : 32)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { saved = store.loadGame() }
        .confirmationDialog("Aktuelles Spiel verwerfen?", isPresented: .init(
            get: { pendingDiscard != nil }, set: { if !$0 { pendingDiscard = nil } }
        ), titleVisibility: .visible, presenting: pendingDiscard) { difficulty in
            Button("Verwerfen und \(difficulty.title) starten", role: .destructive) { start(difficulty) }
        } message: { _ in
            Text("Dein laufendes Spiel geht dabei verloren.")
        }
    }

    private func continueCard(_ game: Game) -> some View {
        Button { path = [Session(game: game)] } label: {
            HStack(spacing: 20) {
                BoardThumbnail(game: game)
                    .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weiterspielen").font(.title2.bold())
                    Text("\(game.puzzle.difficulty.title) · \(game.elapsed.clock)")
                        .font(.subheadline.monospacedDigit())
                        .opacity(0.85)
                    ProgressView(value: game.progress)
                        .tint(.white)
                        .padding(.top, 4)
                        .accessibilityLabel("\(Int(game.progress * 100)) Prozent gelöst")
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .symbolRenderingMode(.hierarchical)
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(Color.accentColor.gradient, in: .rect(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.accentColor.opacity(0.3), radius: 16, y: 8)
            .contentShape(.rect(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(starting != nil) // a pending start would replace this game once its puzzle arrives
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weiterspielen")
        .accessibilityValue("\(game.puzzle.difficulty.title), \(game.elapsed.clock)")
    }

    private func difficultyButton(_ difficulty: Difficulty) -> some View {
        Button {
            if saved != nil { pendingDiscard = difficulty } else { start(difficulty) }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: difficulty.symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(difficulty.color.gradient, in: .rect(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(difficulty.title).font(.headline)
                    Text(difficulty.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if starting == difficulty {
                    ProgressView()
                } else {
                    DifficultyMeter(level: difficulty.level, color: difficulty.color)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(starting != nil)
        .accessibilityLabel(difficulty.title)
        .accessibilityHint(difficulty.subtitle)
    }

    private func start(_ difficulty: Difficulty) {
        guard starting == nil else { return } // one tap, one puzzle
        starting = difficulty
        Task {
            let game = Game(puzzle: await stock.take(difficulty))
            try? store.save(game) // a failed save only loses the resume option
            starting = nil
            saved = game
            path = [Session(game: game)]
        }
    }
}

/// Four bars, filled up to the difficulty's level.
private struct DifficultyMeter: View {
    let level: Int
    let color: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...4, id: \.self) { bar in
                Capsule()
                    .fill(bar <= level ? AnyShapeStyle(color) : AnyShapeStyle(.quaternary))
                    .frame(width: 5, height: 6 + CGFloat(bar) * 4)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A miniature of the saved board: givens and entries as dots, on a 3×3 box grid.
private struct BoardThumbnail: View {
    let game: Game

    var body: some View {
        Canvas { context, size in
            let step = size.width / 9
            for index in 0..<81 where game.entries.cells[index] != 0 {
                let rect = CGRect(x: CGFloat(index % 9) * step, y: CGFloat(index / 9) * step, width: step, height: step)
                    .insetBy(dx: step * 0.22, dy: step * 0.22)
                let isGiven = game.puzzle.givens.cells[index] != 0
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(isGiven ? 0.95 : 0.55)))
            }
            for i in [3, 6] {
                let offset = CGFloat(i) * step
                var path = Path()
                path.move(to: CGPoint(x: offset, y: 0)); path.addLine(to: CGPoint(x: offset, y: size.height))
                path.move(to: CGPoint(x: 0, y: offset)); path.addLine(to: CGPoint(x: size.width, y: offset))
                context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 1)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.15), in: .rect(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Shrinks slightly while pressed, like system cards.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

extension Difficulty {
    var level: Int { Difficulty.allCases.firstIndex(of: self)! + 1 }

    var subtitle: String {
        switch self {
        case .easy: "Zum Ankommen – nur einfache Schritte"
        case .medium: "Kästen, Zeilen und Spalten im Blick"
        case .hard: "Paare und Dreier finden"
        case .expert: "X-Wing, Swordfish & Co."
        }
    }

    var symbol: String {
        switch self {
        case .easy: "leaf.fill"
        case .medium: "flame.fill"
        case .hard: "bolt.fill"
        case .expert: "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .easy: .green
        case .medium: .orange
        case .hard: .pink
        case .expert: .purple
        }
    }
}

extension Game {
    /// Share of the cells to fill that are filled, 0…1.
    var progress: Double {
        let open = puzzle.givens.cells.filter { $0 == 0 }.count
        guard open > 0 else { return 1 }
        let filled = zip(puzzle.givens.cells, entries.cells).filter { $0 == 0 && $1 != 0 }.count
        return Double(filled) / Double(open)
    }
}
