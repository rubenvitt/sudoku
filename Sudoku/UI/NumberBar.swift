import SwiftUI

/// Digit entry for fingers and VoiceOver; the pencil writes directly into the grid.
struct NumberBar: View {
    let columns: Int
    let noteMode: Bool
    let onDigit: (Int) -> Void
    let onClear: () -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(1...9, id: \.self) { digit in
                key { onDigit(digit) } label: {
                    Text("\(digit)")
                        .font(.system(size: noteMode ? 22 : 32, weight: noteMode ? .medium : .regular, design: .rounded))
                        .foregroundStyle(noteMode ? Color.secondary : Color.accentColor)
                }
                .accessibilityLabel("Ziffer \(digit)")
            }
            key(action: onClear) {
                Image(systemName: "delete.backward").font(.title2)
            }
            .accessibilityLabel("Löschen")
        }
        .animation(.easeInOut(duration: 0.15), value: noteMode)
    }

    private func key(action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
