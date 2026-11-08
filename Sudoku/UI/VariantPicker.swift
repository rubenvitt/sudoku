import SwiftUI
import SudokuEngine

/// The menu's variant row: the chosen variant large, with its board and rule. Tapping it opens every variant
/// as a tile, so the menu stays the same size however many variants there are.
struct VariantCard: View {
    @Binding var selection: String
    @State private var choosing = false
    @Environment(\.accent) private var accent
    @Environment(\.isEnabled) private var isEnabled

    private var variant: Variant { Variant.named(selection) ?? .classic }

    var body: some View {
        Button { choosing = true } label: {
            HStack(spacing: 14) {
                VariantPreview(variant: variant)
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Spielart")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .textCase(.uppercase)
                    Text(variant.title).font(.headline)
                    Text(variant.rule)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text("Ändern")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spielart")
        .accessibilityValue(variant.title)
        .accessibilityHint(variant.rule)
        .accessibilityIdentifier("variant")
        .sheet(isPresented: $choosing) {
            VariantSheet(selection: $selection)
        }
    }
}

/// Every variant as a tile with its board and rule; the chosen one is ringed and ticked.
struct VariantSheet: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(Variant.all, id: \.id) { tile($0) }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Spielart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .tint(accent)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func tile(_ variant: Variant) -> some View {
        let isSelected = variant.id == selection
        return Button {
            selection = variant.id
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VariantPreview(variant: variant)
                        .frame(width: 64, height: 64)
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(.quaternary))
                }
                Text(variant.title).font(.headline)
                Text(variant.rule)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? accent : .clear, lineWidth: 2.5)
            }
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(variant.title)
        .accessibilityHint(variant.rule)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("variant-\(variant.id)")
    }
}

/// A miniature board that shows what sets the variant apart: tinted diagonals or windows, Jigsaw regions,
/// Killer cages. Jigsaw and Killer draw a sample, since every puzzle brings its own regions and cages.
struct VariantPreview: View {
    let variant: Variant
    @Environment(\.accent) private var accent

    var body: some View {
        let shown = Self.sample(for: variant)
        Canvas { context, size in
            let side = min(size.width, size.height)
            let step = side / 9
            for index in Set(shown.extras.joined()) {
                let rect = CGRect(x: CGFloat(index % 9) * step, y: CGFloat(index / 9) * step, width: step, height: step)
                context.fill(Path(rect), with: .color(accent.opacity(0.35)))
            }
            for cage in shown.cages {
                context.stroke(cage.outline(step: step, inset: step * 0.15, label: .zero), with: .color(accent),
                               style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
            context.stroke(shown.regionBorders(side: side), with: .color(Color(.label).opacity(0.7)),
                           style: StrokeStyle(lineWidth: 1, lineCap: .square))
        }
        .padding(4)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(.label).opacity(0.7), lineWidth: 1.5))
        .accessibilityHidden(true)
    }

    /// What the preview draws for `variant`: the variant itself, or for Jigsaw and Killer a typical puzzle's shape.
    static func sample(for variant: Variant) -> Variant {
        switch variant.id {
        case Variant.jigsaw.id:
            Variant(id: variant.id, rows: variant.rows, columns: variant.columns, regions: [
                [0, 9, 10, 11, 18, 19, 20, 27, 28],
                [1, 2, 3, 4, 13, 14, 15, 16, 23],
                [5, 6, 7, 8, 17, 24, 25, 26, 35],
                [12, 21, 29, 30, 36, 37, 38, 45, 54],
                [22, 31, 40, 49, 50, 51, 59, 60, 61],
                [32, 33, 34, 41, 42, 43, 44, 52, 53],
                [46, 47, 55, 56, 63, 64, 72, 73, 74],
                [39, 48, 57, 58, 65, 66, 67, 75, 76],
                [62, 68, 69, 70, 71, 77, 78, 79, 80],
            ], extras: [])
        case Variant.killer.id:
            // A few cages spread over the board; all of them would only read as noise at this size.
            Variant(id: variant.id, rows: variant.rows, columns: variant.columns, regions: variant.regions, extras: [], cages: [
                Cage(cells: [0, 9, 10], sum: 18),
                Cage(cells: [4, 13, 14], sum: 21),
                Cage(cells: [15, 16, 24], sum: 12),
                Cage(cells: [29, 30, 39], sum: 24),
                Cage(cells: [33, 42, 51], sum: 19),
                Cage(cells: [46, 47, 55, 64], sum: 18),
                Cage(cells: [67, 68, 76], sum: 18),
                Cage(cells: [70, 79, 80], sum: 19),
            ])
        default:
            variant
        }
    }
}
