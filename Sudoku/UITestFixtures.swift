#if DEBUG
import SudokuEngine

/// Fixed puzzles for UI tests and App Store screenshots: launch with `-uiTestFixedPuzzle`.
enum UITestFixtures {
    /// Solved Sudoku from the Wikipedia article; the classic puzzle and the Killer cages are built on it.
    static let solution = Grid("534678912672195348198342567859761423426853791713924856961537284287419635345286179")

    static let classic = Puzzle(
        variant: .classic,
        givens: Grid("53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"),
        solution: solution,
        difficulty: .easy)

    /// Unique from the cages alone, without a single given.
    static let killer = Puzzle(
        variant: Variant(
            id: Variant.killer.id, rows: Variant.killer.rows, columns: Variant.killer.columns,
            regions: Variant.killer.regions, extras: [],
            cages: [
                Cage(cells: [29, 30, 39], sum: 24),
                Cage(cells: [31, 40], sum: 11),
                Cage(cells: [50, 59, 60, 69], sum: 19),
                Cage(cells: [0, 9, 10], sum: 18),
                Cage(cells: [22, 23], sum: 6),
                Cage(cells: [33, 42, 51], sum: 19),
                Cage(cells: [77, 78], sum: 7),
                Cage(cells: [65, 66, 74, 75], sum: 18),
                Cage(cells: [45, 54, 63], sum: 18),
                Cage(cells: [15, 16, 24], sum: 12),
                Cage(cells: [32, 41], sum: 4),
                Cage(cells: [11, 20], sum: 10),
                Cage(cells: [36, 37, 38], sum: 12),
                Cage(cells: [5, 6, 7, 8], sum: 20),
                Cage(cells: [1, 2, 3], sum: 13),
                Cage(cells: [67, 68, 76], sum: 18),
                Cage(cells: [17, 25, 26], sum: 21),
                Cage(cells: [44, 52, 53], sum: 12),
                Cage(cells: [72, 73], sum: 7),
                Cage(cells: [19, 28], sum: 14),
                Cage(cells: [61, 62, 71], sum: 17),
                Cage(cells: [46, 47, 55, 64], sum: 18),
                Cage(cells: [70, 79, 80], sum: 19),
                Cage(cells: [18, 27], sum: 9),
                Cage(cells: [48, 49, 58], sum: 14),
                Cage(cells: [4, 13, 14], sum: 21),
                Cage(cells: [12, 21], sum: 4),
                Cage(cells: [56, 57], sum: 6),
                Cage(cells: [34, 35, 43], sum: 14)
            ]),
        givens: Grid(String(repeating: ".", count: 81)),
        solution: solution,
        difficulty: .easy)

    static let jigsaw = Puzzle(
        variant: Variant(
            id: Variant.jigsaw.id, rows: Variant.jigsaw.rows, columns: Variant.jigsaw.columns,
            regions: [
                [[0, 9, 10, 11, 18, 19, 20, 27, 28],
                [1, 2, 3, 4, 13, 14, 15, 16, 23],
                [5, 6, 7, 8, 17, 24, 25, 26, 35],
                [12, 21, 29, 30, 36, 37, 38, 45, 54],
                [22, 31, 40, 49, 50, 51, 59, 60, 61],
                [32, 33, 34, 41, 42, 43, 44, 52, 53],
                [46, 47, 55, 56, 63, 64, 72, 73, 74],
                [39, 48, 57, 58, 65, 66, 67, 75, 76],
                [62, 68, 69, 70, 71, 77, 78, 79, 80]]
            ],
            extras: []),
        givens: Grid("61...832...9.2....18.6...7.....3529........4..94.6.1....18.2.5.2..41.....7.3.6.12"),
        solution: Grid("617958324359724861182643579748135296923581647594267138461872953236419785875396412"),
        difficulty: .easy)
}
#endif
