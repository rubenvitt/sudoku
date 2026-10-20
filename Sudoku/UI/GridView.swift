import SwiftUI
import SudokuEngine

/// The square board; cells are exact `side / 9` squares, which the Scribble layer laid over it relies on.
struct GridView: View, Equatable {
    let game: Game
    @Binding var selection: Int?
    var focus: Set<Int> = []

    /// Ignores `elapsed` so the per-second timer tick doesn't redraw all 81 cells.
    nonisolated static func == (lhs: GridView, rhs: GridView) -> Bool {
        MainActor.assumeIsolated {
            lhs.game.entries == rhs.game.entries && lhs.game.notes == rhs.game.notes
                && lhs.game.errorMarks == rhs.game.errorMarks && lhs.game.puzzle.givens == rhs.game.puzzle.givens
                && lhs.selection == rhs.selection && lhs.focus == rhs.focus
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width / 9
            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { column in
                            cell(row * 9 + column, size: size)
                        }
                    }
                }
            }
            .overlay { lines.allowsHitTesting(false) }
        }
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(.label).opacity(0.8), lineWidth: 2))
        // The shadow sits on a plain shape, so it isn't re-rendered with every cell change.
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        }
        .animation(.easeOut(duration: 0.15), value: selection)
        .animation(.easeOut(duration: 0.25), value: focus)
    }

    private func cell(_ index: Int, size: CGFloat) -> some View {
        let value = Int(game.entries.cells[index])
        let isGiven = game.puzzle.givens.cells[index] != 0
        let isWrong = game.errorMarks.contains(index)
        let selectedValue = selection.map { Int(game.entries.cells[$0]) } ?? 0
        return Button { selection = index } label: {
            ZStack {
                Rectangle().fill(background(index, value: value, isWrong: isWrong))
                if value != 0 {
                    Text("\(value)")
                        .font(.system(size: size * 0.58, weight: isGiven ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(isWrong ? Color.red : isGiven ? Color.primary : Color.accentColor)
                        .contentTransition(.numericText())
                } else {
                    notes(game.notes[index], size: size, highlight: selectedValue)
                }
            }
            .frame(width: size, height: size)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(index, value: value, isGiven: isGiven, isWrong: isWrong))
        .accessibilityAddTraits(selection == index ? .isSelected : [])
    }

    /// "Zeile 1, Spalte 3, leer, Notizen 1, 2, 4" / "Zeile 9, Spalte 9, 9, vorgegeben"
    private func accessibilityLabel(_ index: Int, value: Int, isGiven: Bool, isWrong: Bool) -> String {
        var label = "Zeile \(index / 9 + 1), Spalte \(index % 9 + 1), \(value == 0 ? "leer" : "\(value)")"
        let notes = (1...9).filter { game.notes[index] & (1 << ($0 - 1)) != 0 }
        if value == 0 && !notes.isEmpty { label += ", Notizen \(notes.map(String.init).joined(separator: ", "))" }
        if isGiven { label += ", vorgegeben" }
        if isWrong { label += ", falsch" }
        return label
    }

    /// Notes of `highlight`, the digit in the selected cell, stand out so its candidates are easy to spot.
    private func notes(_ mask: CandidateMask, size: CGFloat, highlight: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { column in
                        let digit = row * 3 + column
                        let isHighlighted = digit == highlight
                        Text("\(digit)")
                            .font(.system(size: size * 0.22, weight: isHighlighted ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isHighlighted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                            .frame(width: size / 3.4, height: size / 3.4)
                            .opacity(mask & (1 << (digit - 1)) != 0 ? 1 : 0)
                    }
                }
            }
        }
    }

    private func background(_ index: Int, value: Int, isWrong: Bool) -> Color {
        if isWrong { return .red.opacity(0.15) }
        if focus.contains(index) { return .yellow.opacity(0.35) }
        guard let selected = selection else { return .clear }
        if selected == index { return .accentColor.opacity(0.3) }
        let selectedValue = Int(game.entries.cells[selected])
        if selectedValue != 0 && value == selectedValue { return .accentColor.opacity(0.18) }
        let sameBox = selected / 27 == index / 27 && selected % 9 / 3 == index % 9 / 3
        if selected / 9 == index / 9 || selected % 9 == index % 9 || sameBox { return .accentColor.opacity(0.07) }
        return .clear
    }

    private var lines: some View {
        Canvas { context, size in
            let step = size.width / 9
            for i in 1..<9 {
                let offset = CGFloat(i) * step
                var path = Path()
                path.move(to: CGPoint(x: offset, y: 0)); path.addLine(to: CGPoint(x: offset, y: size.height))
                path.move(to: CGPoint(x: 0, y: offset)); path.addLine(to: CGPoint(x: size.width, y: offset))
                let isBox = i % 3 == 0
                context.stroke(path, with: .color(isBox ? Color(.label).opacity(0.8) : Color(.separator)), lineWidth: isBox ? 1.5 : 0.5)
            }
        }
    }
}
