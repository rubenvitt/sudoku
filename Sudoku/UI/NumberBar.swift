import SwiftUI

/// Digit entry for fingers and VoiceOver; the pencil writes directly into the grid.
struct NumberBar: View {
    let columns: Int
    var keyHeight: CGFloat = 64
    let noteMode: Bool
    /// How often each digit may still be placed, indexed by digit.
    let remaining: [Int]
    let onDigit: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 8) {
            ForEach(1...9, id: \.self) { digit in
                let done = remaining[digit] <= 0
                Button { onDigit(digit) } label: {
                    VStack(spacing: 2) {
                        Text("\(digit)")
                            .font(.system(size: noteMode ? keyHeight * 0.34 : keyHeight * 0.46,
                                          weight: noteMode ? .medium : .regular, design: .rounded))
                            .foregroundStyle(noteMode ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                        Text(done ? " " : "\(remaining[digit])")
                            .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, minHeight: keyHeight)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                    .opacity(done ? 0.35 : 1)
                    .contentShape(.rect)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Ziffer \(digit)")
                .accessibilityValue(done ? "vollständig" : "noch \(remaining[digit])")
            }
        }
        .animation(.easeInOut(duration: 0.15), value: noteMode)
    }
}
