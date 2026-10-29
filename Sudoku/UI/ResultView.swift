import SwiftUI
import SudokuEngine

struct ResultView: View {
    let game: Game
    let onNewGame: () -> Void
    let onMenu: () -> Void
    @State private var starting = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.green.gradient)
                        .symbolEffect(.bounce, value: appeared)
                    Text("Gelöst!")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("\(game.puzzle.difficulty.title) in \(game.elapsed.clock)")
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile("Zeit", game.elapsed.clock, "stopwatch", .blue)
                    tile("Tipps", "\(game.hintsUsed)", "lightbulb", .yellow)
                    tile("Prüfungen", "\(game.checksUsed)", "checkmark.circle", .teal)
                    tile("Gefundene Fehler", "\(game.errorsFound)", "xmark.octagon", .red)
                }
                VStack(spacing: 10) {
                    Button {
                        starting = true
                        onNewGame()
                    } label: {
                        Text("Neues Spiel").opacity(starting ? 0 : 1)
                            .overlay { if starting { ProgressView().tint(.white) } }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(starting)
                    .accessibilityLabel("Neues Spiel")
                    .accessibilityIdentifier("newGame")
                    Button(action: onMenu) {
                        Text("Zum Menü").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .buttonBorderShape(.capsule)
                .font(.headline)
            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 30, y: 10)
            .padding(16) // keeps the card off the edges of an iPhone
        }
        .accessibilityAddTraits(.isModal)
        .onAppear { appeared = true }
    }

    private func tile(_ title: LocalizedStringKey, _ value: String, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .semibold).monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(value)
    }
}
