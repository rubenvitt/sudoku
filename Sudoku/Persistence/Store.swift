import Foundation
import SudokuEngine

struct Store: Sendable {
    let directory: URL

    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static var applicationSupport: Store {
        Store(directory: URL.applicationSupportDirectory.appending(path: "Sudoku", directoryHint: .isDirectory))
    }

    private var gameURL: URL { directory.appending(path: "game.json") }
    private var stockURL: URL { directory.appending(path: "stock.json") }
    private var inkURL: URL { directory.appending(path: "ink.json") }

    /// Missing and corrupt files both mean "no saved game".
    func loadGame() -> Game? { load(Game.self, from: gameURL) }

    /// The handwriting is written with every save, so a new game never shows the last game's ink.
    func save(_ game: Game, ink: [Int: Ink] = [:]) throws {
        try write(game, to: gameURL)
        try write(ink, to: inkURL)
    }

    /// The saved game's handwriting; missing or corrupt means none, and the digits show typeset.
    func loadInk() -> [Int: Ink] { load([Int: Ink].self, from: inkURL) ?? [:] }

    func deleteGame() throws {
        for url in [gameURL, inkURL] {
            do { try FileManager.default.removeItem(at: url) }
            catch CocoaError.fileNoSuchFile {}
        }
    }

    func loadStock() -> [Difficulty: Puzzle] { load([Difficulty: Puzzle].self, from: stockURL) ?? [:] }

    func saveStock(_ stock: [Difficulty: Puzzle]) throws { try write(stock, to: stockURL) }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
