import SwiftUI
import SudokuEngine

/// The menu's row into the practice room.
struct PracticeEntry: View {
    @Environment(ExerciseStock.self) private var exercises
    @Environment(\.accent) private var accent

    var body: some View {
        NavigationLink {
            TechniqueList()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "graduationcap.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(accent.gradient, in: .rect(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Techniken üben").font(.headline)
                    Text("\(Exercises.techniques.count) Techniken · \(exercises.practisedCount) geübt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("practice")
    }
}

/// Every technique, grouped by the difficulty it belongs to, ticked once practised.
struct TechniqueList: View {
    @Environment(ExerciseStock.self) private var exercises

    var body: some View {
        List {
            ForEach(Difficulty.allCases, id: \.self) { difficulty in
                Section(difficulty.title) {
                    ForEach(Exercises.techniques.filter { $0.difficulty == difficulty }, id: \.self) { technique in
                        NavigationLink {
                            TechniquePage(technique: technique)
                        } label: {
                            row(technique)
                        }
                        .accessibilityIdentifier("technique-\(technique)")
                    }
                }
            }
        }
        .navigationTitle("Techniken üben")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ technique: Technique) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let english = technique.englishName { // the common name, to find it in other books and apps
                    Text(technique.title) + Text(verbatim: " (\(english))").foregroundStyle(.secondary)
                } else {
                    Text(technique.title)
                }
                Text(technique.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if exercises.isPractised(technique) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Geübt")
            }
        }
    }
}

/// One technique: what it says, an example to step through, and the way into an exercise.
struct TechniquePage: View {
    let technique: Technique
    @State private var showsStep = false
    @Environment(ExerciseStock.self) private var exercises
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var example: Exercise? { Exercises.starters[technique] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(technique.title).font(.largeTitle.bold())
                    if let english = technique.englishName {
                        Text(english).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(technique.summary).font(.headline)
                    Text(technique.details).foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                if let example, let step = example.applications.first {
                    exampleSection(example, step: step)
                }
                NavigationLink {
                    PracticeView(technique: technique)
                } label: {
                    Label("Selbst probieren", systemImage: "pencil.and.scribble")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .accessibilityIdentifier("try")
                if exercises.isPractised(technique) {
                    Label("Geübt", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, sizeClass == .compact ? 16 : 32)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exampleSection(_ example: Exercise, step: Step) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Beispiel").font(.title3.bold()).accessibilityAddTraits(.isHeader)
            GridView(game: shownGame(example, step: step), selection: .constant(nil), focus: Set(step.focus),
                     struck: showsStep ? step.struck : [:])
                .aspectRatio(1, contentMode: .fit)
                .allowsHitTesting(false)
                .accessibilityLabel("Beispiel für \(technique.title)")
            if showsStep {
                Text(step.explanation)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            Button {
                showsStep.toggle()
                if showsStep { AccessibilityNotification.Announcement(step.explanation).post() }
            } label: {
                Text(showsStep ? LocalizedStringKey("Schritt ausblenden") : LocalizedStringKey("Schritt zeigen"))
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("show-step")
        }
        .animation(.easeInOut(duration: 0.25), value: showsStep)
    }

    /// The example as a game: with the step's digit placed once it is shown.
    private func shownGame(_ example: Exercise, step: Step) -> Game {
        var game = example.game
        if showsStep, let p = step.placement { game.setDigit(p.digit, at: p.cell) }
        return game
    }
}

extension Step {
    /// The notes the step crosses out, per cell.
    var struck: [Int: CandidateMask] {
        var result: [Int: CandidateMask] = [:]
        for e in eliminations { result[e.cell, default: 0] |= 1 << (e.digit - 1) }
        return result
    }
}

/// One exercise on the game's board. Moves the technique doesn't back are taken back at once; the exercise is done as
/// soon as one application of the technique is complete.
struct PracticeView: View {
    let technique: Technique
    @State private var exercise: Exercise?
    @State private var game: Game?
    @State private var noteMode = false
    @State private var selection: Int?
    @State private var ink: [Int: Ink] = [:]
    @State private var revisions: [Int: Int] = [:]
    @State private var banner: String?
    @State private var flash: Int?
    /// 0 = no help yet; 1 the key sentence, 2 the groups, 3 the cells, 4 the solution.
    @State private var helpLevel = 0
    @State private var outcome: Outcome?
    @Environment(ExerciseStock.self) private var exercises
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accent) private var accent

    private struct Outcome: Equatable {
        let solved: Bool
        let explanation: String
        let focus: Set<Int>
        let struck: [Int: CandidateMask]

        static func == (a: Outcome, b: Outcome) -> Bool { a.solved == b.solved && a.explanation == b.explanation }
    }

    var body: some View {
        Group {
            if let exercise, let game {
                content(exercise, game: game)
            } else {
                ProgressView()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(technique.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if exercise == nil { next() } }
        .animation(.easeInOut(duration: 0.2), value: banner)
        .animation(.spring(duration: 0.4), value: outcome)
        .sensoryFeedback(.success, trigger: outcome) { _, new in new?.solved == true }
        .sensoryFeedback(.error, trigger: flash) { _, new in new != nil }
    }

    private func content(_ exercise: Exercise, game: Game) -> some View {
        VStack(spacing: 14) {
            Text(exercise.isSingle ? LocalizedStringKey("Setze eine Ziffer, die hier sicher ist.")
                                   : LocalizedStringKey("Streiche die Notizen, die wegfallen."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            board(exercise, game: game)
            controls(game)
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, sizeClass == .compact ? 12 : 24)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(outcome != nil)
        .overlay(alignment: .bottom) {
            if let outcome { result(outcome).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
    }

    private func board(_ exercise: Exercise, game: Game) -> some View {
        let hinted = exercise.applications.first
        let focus: Set<Int> = outcome?.focus ?? (helpLevel >= 3 ? Set(hinted?.focus ?? []) : [])
        let area: Set<Int> = helpLevel == 2 ? hinted.map(Self.area) ?? [] : []
        return GridView(game: game, selection: $selection, focus: focus, ink: ink, area: area,
                        struck: outcome?.struck ?? [:], flash: flash)
            .equatable()
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                ScribbleLayer(givens: Set((0..<81).filter { exercise.cells.cells[$0] != 0 }), noteMode: noteMode,
                              onInput: apply, inkColor: accent, onSelect: { selection = selection == $0 ? nil : $0 },
                              onUndo: undo, revisions: revisions)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controls(_ game: Game) -> some View {
        VStack(spacing: 12) {
            Color.clear.frame(height: 0).overlay(alignment: .bottom) {
                if let banner {
                    Text(banner)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .background(.regularMaterial, in: .rect(cornerRadius: 18, style: .continuous))
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture { self.banner = nil }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            HStack(spacing: 10) {
                Button { undo() } label: { Label("Rückgängig", systemImage: "arrow.uturn.backward") }
                    .disabled(!game.canUndo)
                Button { noteMode.toggle() } label: { Label("Notizen", systemImage: "pencil") }
                    .tint(noteMode ? accent : .secondary)
                    .accessibilityAddTraits(noteMode ? .isSelected : [])
                    .accessibilityIdentifier("notes")
                Button { help() } label: { Label(helpLevel >= 3 ? LocalizedStringKey("Auflösen") : LocalizedStringKey("Tipp"), systemImage: "lightbulb") }
                    .accessibilityIdentifier("hint")
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .font(.subheadline.weight(.medium))
            NumberBar(columns: 9, keyHeight: sizeClass == .compact ? 52 : 64, noteMode: noteMode,
                      remaining: remaining(game)) { digit in
                guard let cell = selection else { return }
                revisions[cell, default: 0] += 1
                apply(noteMode ? .note(digit, cell: cell) : .digit(digit, cell: cell))
            }
        }
    }

    private func result(_ outcome: Outcome) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(outcome.solved ? LocalizedStringKey("Geschafft") : LocalizedStringKey("So geht es"),
                  systemImage: outcome.solved ? "checkmark.circle.fill" : "lightbulb.max.fill")
                .font(.headline)
                .foregroundStyle(outcome.solved ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.yellow))
            Text(outcome.explanation)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Zurück") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Nächste Übung") { next() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("next-exercise")
            }
        }
        .padding(18)
        .background(.regularMaterial, in: .rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        .padding(16)
    }

    /// How often each digit 1…9 may still be placed; index 0 is unused.
    private func remaining(_ game: Game) -> [Int] {
        var counts = [Int](repeating: 9, count: 10)
        for value in game.entries.cells where value != 0 { counts[Int(value)] -= 1 }
        return counts
    }

    /// The groups the application happens in: those holding two of its cells, or all groups of a single cell.
    private static func area(_ step: Step) -> Set<Int> {
        let groups = Variant.classic.groups
        let focus = Set(step.focus)
        let chosen = focus.count == 1
            ? groups.filter { !focus.isDisjoint(with: $0) }
            : groups.filter { focus.intersection($0).count >= 2 }
        return Set(chosen.joined())
    }

    private func next() {
        guard let new = exercises.take(technique) else { return }
        exercise = new
        game = new.game
        noteMode = !new.isSingle
        selection = nil
        ink = [:]
        revisions = [:]
        banner = nil
        flash = nil
        helpLevel = 0
        outcome = nil
    }

    private func apply(_ input: CellInput) {
        guard var game, let exercise, outcome == nil else { return }
        let before = (game.entries, game.notes)
        let cell: Int
        switch input {
        case let .digit(digit, c, written):
            cell = c
            game.setDigit(digit, at: c)
            if let written { ink[c] = written }
        case let .note(digit, c):
            cell = c
            game.toggleNote(digit, at: c)
        case let .clear(c):
            cell = c
            game.clear(c)
        }
        guard before != (game.entries, game.notes) else { return }
        banner = nil
        switch exercise.judge(entries: game.entries, notes: game.notes) {
        case .going:
            self.game = game
        case let .wrong(_, digit, isNote):
            game.undo()
            self.game = game
            ink[cell] = nil
            revisions[cell, default: 0] += 1
            reject(cell, text: isNote
                ? String(localized: "Passt nicht, die \(digit) bleibt.")
                : String(localized: "Die \(digit) passt hier nicht."))
        case let .solved(step):
            self.game = game
            finish(step, solved: helpLevel < 4)
        }
    }

    private func undo() {
        guard var game, outcome == nil else { return }
        let before = (entries: game.entries.cells, notes: game.notes)
        game.undo()
        self.game = game
        for cell in 0..<81 where game.entries.cells[cell] != before.entries[cell] || game.notes[cell] != before.notes[cell] {
            revisions[cell, default: 0] += 1
        }
    }

    private func reject(_ cell: Int, text: String) {
        flash = cell
        announce(text)
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            if flash == cell { flash = nil }
        }
    }

    /// Four steps of help, each a little more: the key sentence, the groups, the cells, then the solution.
    private func help() {
        guard let exercise, let step = exercise.applications.first else { return }
        helpLevel += 1
        switch helpLevel {
        case 1: announce(technique.summary)
        case 2: announce(String(localized: "Schau in die markierte Gegend."))
        case 3: announce(String(localized: "Die gelben Felder tragen den Schluss."))
        default: finish(step, solved: false)
        }
    }

    private func finish(_ step: Step, solved: Bool) {
        if solved { exercises.recordSolved(technique) }
        banner = nil
        if !solved, var game, let p = step.placement, game.entries.cells[p.cell] == 0 {
            game.setDigit(p.digit, at: p.cell)
            self.game = game
        }
        outcome = Outcome(solved: solved, explanation: step.explanation, focus: Set(step.focus),
                          struck: solved ? [:] : step.struck)
        AccessibilityNotification.Announcement(
            "\(solved ? String(localized: "Geschafft") : String(localized: "So geht es")). \(step.explanation)").post()
    }

    private func announce(_ text: String) {
        banner = text
        AccessibilityNotification.Announcement(text).post()
    }
}
