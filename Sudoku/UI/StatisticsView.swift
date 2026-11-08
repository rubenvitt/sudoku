import SwiftUI
import SudokuEngine

/// Solved games, best and average times per variant and difficulty. Opened from the menu's toolbar.
struct StatisticsView: View {
    let store: Store
    @State private var statistics = Statistics()
    @State private var confirmingReset = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent

    var body: some View {
        NavigationStack {
            Group {
                if statistics.isEmpty {
                    ContentUnavailableView("Noch keine Statistik", systemImage: "chart.bar",
                                           description: Text("Sobald du ein Rätsel startest, erscheint es hier."))
                } else {
                    list
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .onAppear { statistics = store.loadStatistics() }
    }

    private var list: some View {
        List {
            Section {
                totals
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            ForEach(statistics.playedVariants, id: \.id) { variant in
                Section(variant.title) {
                    ForEach(variant.difficulties, id: \.self) { difficulty in
                        let summary = statistics.summary(variant: variant.id, difficulty: difficulty)
                        if summary.started > 0 { row(summary, difficulty) }
                    }
                }
            }
            Section {
                Button("Statistik zurücksetzen", role: .destructive) { confirmingReset = true }
                    .frame(maxWidth: .infinity)
            }
        }
        .confirmationDialog("Alle Statistiken löschen?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive) {
                // Shown as reset only once saved: a failed write keeps the numbers that will load next time.
                if (try? store.saveStatistics(Statistics())) != nil { statistics = Statistics() }
            }
        } message: {
            Text("Gelöste Rätsel, Zeiten und Bestzeiten gehen dabei verloren.")
        }
    }

    private var totals: some View {
        let total = statistics.summary()
        return HStack(spacing: 10) {
            tile("Gelöst", "\(total.solved)", "checkmark.seal", .green)
            tile("Ohne Tipps", "\(total.withoutHints)", "lightbulb.slash", .yellow)
            tile("Spielzeit", total.playTime.spoken, "hourglass", accent)
        }
    }

    private func tile(_ title: LocalizedStringKey, _ value: String, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(value)
    }

    private func row(_ summary: Statistics.Summary, _ difficulty: Difficulty) -> some View {
        HStack(spacing: 14) {
            Image(systemName: difficulty.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(difficulty.color.gradient, in: .rect(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(difficulty.title).font(.headline)
                Text("\(summary.solved) von \(summary.started) gelöst")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let best = summary.best, let average = summary.average {
                VStack(alignment: .trailing, spacing: 2) {
                    Label(best.clock, systemImage: "trophy")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .accessibilityLabel("Bestzeit \(best.clock)")
                    Text("Ø \(average.clock)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Durchschnitt \(average.clock)")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("statistics-\(difficulty.rawValue)")
    }
}

extension TimeInterval {
    /// "2 Std., 5 Min." – for totals that can run past an hour.
    var spoken: String {
        Duration.seconds(self).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }
}
