import SwiftUI
import SudokuEngine

struct MenuView: View {
    let store: Store
    @Environment(PuzzleStock.self) private var stock
    @State private var saved: Game?
    @State private var session: Session?
    @State private var pendingDiscard: Difficulty?
    @State private var starting: Difficulty?

    private struct Session {
        let id = UUID()
        let game: Game
    }

    private let kinds = ["Klassisch"]

    var body: some View {
        if let session {
            GameView(game: session.game, store: store, onNewGame: start, onMenu: { self.session = nil })
                .id(session.id)
        } else {
            menu
        }
    }

    private var menu: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                Text("Sudoku")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .accessibilityAddTraits(.isHeader)

                if let saved { continueButton(saved) }

                section("Art") {
                    VStack(spacing: 0) {
                        ForEach(kinds, id: \.self) { kind in
                            HStack {
                                Text(kind)
                                Spacer()
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                            .font(.title3)
                            .padding()
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isSelected)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                }

                section("Stufe") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                        ForEach(Difficulty.allCases, id: \.self) { difficulty in
                            difficultyButton(difficulty)
                        }
                    }
                }
            }
            .frame(maxWidth: 640)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { saved = store.loadGame() }
        .confirmationDialog("Aktuelles Spiel verwerfen?", isPresented: .init(
            get: { pendingDiscard != nil }, set: { if !$0 { pendingDiscard = nil } }
        ), titleVisibility: .visible, presenting: pendingDiscard) { difficulty in
            Button("Verwerfen", role: .destructive) { start(difficulty) }
        }
    }

    private func continueButton(_ game: Game) -> some View {
        Button { session = Session(game: game) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weiterspielen").font(.title2.weight(.semibold))
                    Text("\(game.puzzle.difficulty.title) · \(game.elapsed.clock)")
                        .font(.body.monospacedDigit())
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "play.fill").font(.title)
            }
            .foregroundStyle(.white)
            .padding(24)
            .background(Color.accentColor.gradient, in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(starting != nil) // a pending start would replace this game once its puzzle arrives
        .accessibilityElement(children: .combine)
    }

    private func difficultyButton(_ difficulty: Difficulty) -> some View {
        Button {
            if saved != nil { pendingDiscard = difficulty } else { start(difficulty) }
        } label: {
            Text(difficulty.title)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 96)
                .overlay(alignment: .trailing) {
                    if starting == difficulty { ProgressView().padding(.trailing, 20) }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(starting != nil)
        .accessibilityLabel(difficulty.title)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            content()
        }
    }

    private func start(_ difficulty: Difficulty) {
        guard starting == nil else { return } // one tap, one puzzle
        starting = difficulty
        Task {
            let game = Game(puzzle: await stock.take(difficulty))
            try? store.save(game) // a failed save only loses the resume option
            starting = nil
            session = Session(game: game)
        }
    }
}
