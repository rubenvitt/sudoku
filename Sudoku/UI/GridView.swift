import SwiftUI
import UIKit
import SudokuEngine

/// The square board. Its own top-left is the origin of coordinate space `"grid"`; cells are exact `side / 9` squares.
struct GridView: View {
    let game: Game
    @Binding var selection: Int?
    var focus: Set<Int> = []
    var onCellFrame: (Int, CGRect) -> Void = { _, _ in }
    var onTwoFingerTap: () -> Void = {}

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
            .onChange(of: size, initial: true) {
                for index in 0..<81 {
                    onCellFrame(index, CGRect(x: CGFloat(index % 9) * size, y: CGFloat(index / 9) * size, width: size, height: size))
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.label), lineWidth: 3))
        .coordinateSpace(.named("grid"))
        .gesture(TwoFingerTap(action: onTwoFingerTap))
        .animation(.easeOut(duration: 0.15), value: selection)
        .animation(.easeOut(duration: 0.25), value: focus)
    }

    private func cell(_ index: Int, size: CGFloat) -> some View {
        let value = Int(game.entries.cells[index])
        let isGiven = game.puzzle.givens.cells[index] != 0
        let isWrong = game.errorMarks.contains(index)
        return Button { selection = index } label: {
            ZStack {
                Rectangle().fill(background(index, value: value, isWrong: isWrong))
                if value != 0 {
                    Text("\(value)")
                        .font(.system(size: size * 0.6, weight: isGiven ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(isWrong ? Color.red : isGiven ? Color.primary : Color.accentColor)
                        .contentTransition(.numericText())
                } else {
                    notes(game.notes[index], size: size)
                }
            }
            .frame(width: size, height: size)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Zeile \(index / 9 + 1), Spalte \(index % 9 + 1), \(value == 0 ? "leer" : "\(value)")\(isWrong ? ", falsch" : "")")
        .accessibilityAddTraits(selection == index ? .isSelected : [])
    }

    private func notes(_ mask: CandidateMask, size: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { column in
                        let digit = row * 3 + column
                        Text("\(digit)")
                            .font(.system(size: size * 0.22, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: size / 3.4, height: size / 3.4)
                            .opacity(mask & (1 << (digit - 1)) != 0 ? 1 : 0)
                    }
                }
            }
        }
    }

    private func background(_ index: Int, value: Int, isWrong: Bool) -> Color {
        if isWrong { return .red.opacity(0.15) }
        if focus.contains(index) { return .orange.opacity(0.3) }
        guard let selected = selection else { return .clear }
        if selected == index { return .accentColor.opacity(0.32) }
        let selectedValue = Int(game.entries.cells[selected])
        if selectedValue != 0 && value == selectedValue { return .accentColor.opacity(0.2) }
        let sameBox = selected / 27 == index / 27 && selected % 9 / 3 == index % 9 / 3
        if selected / 9 == index / 9 || selected % 9 == index % 9 || sameBox { return .accentColor.opacity(0.08) }
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
                context.stroke(path, with: .color(isBox ? Color(.label) : Color(.separator)), lineWidth: isBox ? 2 : 0.5)
            }
        }
    }
}

/// Two-finger tap = undo (spec §5); fingers only, so the pencil never triggers it.
private struct TwoFingerTap: UIGestureRecognizerRepresentable {
    let action: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTouchesRequired = 2
        recognizer.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        if recognizer.state == .ended { action() }
    }
}
