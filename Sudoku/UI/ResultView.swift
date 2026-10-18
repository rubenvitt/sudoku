import SwiftUI
import SudokuEngine

struct ResultView: View {
    let game: Game
    let onNewGame: () -> Void
    let onMenu: () -> Void
    @State private var starting = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("Gelöst")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                }
                Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 12) {
                    row("Stufe", game.puzzle.difficulty.title)
                    row("Zeit", game.elapsed.clock)
                    row("Tipps", "\(game.hintsUsed)")
                    row("Prüfungen", "\(game.checksUsed)")
                    row("Gefundene Fehler", "\(game.errorsFound)")
                }
                .font(.title3)
                HStack(spacing: 16) {
                    Button("Menü", action: onMenu)
                        .buttonStyle(.bordered)
                    Button {
                        starting = true
                        onNewGame()
                    } label: {
                        Text("Neues Spiel").opacity(starting ? 0 : 1)
                            .overlay { if starting { ProgressView() } }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(starting)
                    .accessibilityLabel("Neues Spiel")
                }
                .controlSize(.large)
                .font(.title3.weight(.semibold))
            }
            .padding(40)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 32))
            .shadow(color: .black.opacity(0.15), radius: 30, y: 10)
        }
        .accessibilityAddTraits(.isModal)
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).monospacedDigit().gridColumnAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
