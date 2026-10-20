import SwiftUI

/// The player's accent colour: digits they write, the selection and every tinted control.
/// Each preset has a light and a dark shade so written digits stay readable on both backgrounds.
enum AccentTheme: String, CaseIterable, Identifiable {
    case ocean, indigo, lavender, rose, coral, amber, forest, teal, graphite

    static let storageKey = "accentTheme"

    var id: Self { self }

    var title: String {
        switch self {
        case .ocean: "Ozean"
        case .indigo: "Indigo"
        case .lavender: "Lavendel"
        case .rose: "Rosé"
        case .coral: "Koralle"
        case .amber: "Bernstein"
        case .forest: "Wald"
        case .teal: "Petrol"
        case .graphite: "Graphit"
        }
    }

    var color: Color {
        switch self {
        case .ocean: Color(light: 0x007AFF, dark: 0x0A84FF) // the system blue the app shipped with
        case .indigo: Color(light: 0x4B4FD6, dark: 0x7D80F5)
        case .lavender: Color(light: 0x8358D9, dark: 0xB08CFF)
        case .rose: Color(light: 0xD6336C, dark: 0xFF6B9A)
        case .coral: Color(light: 0xE0533A, dark: 0xFF8A70)
        case .amber: Color(light: 0xC27803, dark: 0xF5B83D)
        case .forest: Color(light: 0x2E8B57, dark: 0x5CC98A)
        case .teal: Color(light: 0x0E7C86, dark: 0x3CC4CF)
        case .graphite: Color(light: 0x4A5160, dark: 0xB4BCC8)
        }
    }
}

extension EnvironmentValues {
    /// Use this, not `Color.accentColor`: that one always resolves to the asset catalog's colour.
    @Entry var accent: Color = AccentTheme.ocean.color
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        func rgb(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) })
    }
}

/// Swatches to pick the accent from, with a small preview of how it looks on the board.
struct AccentPicker: View {
    @AppStorage(AccentTheme.storageKey) private var theme: AccentTheme = .ocean
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    preview
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 18) {
                        ForEach(AccentTheme.allCases) { swatch($0) }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Akzentfarbe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .tint(theme.color)
        .sensoryFeedback(.selection, trigger: theme)
    }

    /// Three cells as they look in a game: a given, a selected entry, and a cell sharing its digit.
    private var preview: some View {
        HStack(spacing: 0) {
            previewCell("5", color: .primary, weight: .semibold, fill: .clear)
            previewCell("7", color: theme.color, weight: .medium, fill: theme.color.opacity(0.3))
            previewCell("7", color: theme.color, weight: .medium, fill: theme.color.opacity(0.18))
        }
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(.label).opacity(0.8), lineWidth: 2))
        .background(Color(.systemBackground), in: .rect(cornerRadius: 12, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: theme)
        .accessibilityHidden(true)
    }

    private func previewCell(_ digit: String, color: Color, weight: Font.Weight, fill: Color) -> some View {
        Text(digit)
            .font(.system(size: 34, weight: weight, design: .rounded))
            .foregroundStyle(color)
            .frame(width: 64, height: 64)
            .background(fill)
            .overlay(alignment: .trailing) { Rectangle().fill(Color(.separator)).frame(width: 0.5) }
    }

    private func swatch(_ option: AccentTheme) -> some View {
        Button { theme = option } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(option.color.gradient)
                    .frame(width: 52, height: 52)
                    .overlay {
                        if option == theme {
                            Image(systemName: "checkmark")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(4)
                    .overlay { Circle().stroke(option == theme ? option.color : .clear, lineWidth: 2.5) }
                Text(option.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(option == theme ? .primary : .secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(option == theme ? .isSelected : [])
    }
}
