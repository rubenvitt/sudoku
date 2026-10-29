import XCTest
import UIKit

final class SmokeTests: XCTestCase {
    @MainActor
    func testAppLaunches() {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    @MainActor
    func testStartGameEnterDigitAndCheck() {
        let app = launch(["-uiTestFixedPuzzle"])
        app.buttons["Leicht"].tap()
        app.buttons["Zeile 1, Spalte 3, leer"].tap()
        app.buttons["Ziffer 9"].tap()           // bekannt falsch im Fixture
        app.buttons["Überprüfen"].tap()
        XCTAssertTrue(app.buttons["Zeile 1, Spalte 3, 9, falsch"].exists)
        XCTAssertTrue(app.buttons["1 Fehler markiert."].exists)
    }

    /// Plays the fixed puzzle to the end, through portrait and (on iPad) landscape, and starts the next game.
    @MainActor
    func testPlayThroughToResultAndNewGame() {
        let givens = Array("53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79")
        let solution = Array("534678912672195348198342567859761423426853791713924856961537284287419635345286179")
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        let app = launch(["-uiTestFixedPuzzle"])
        app.buttons["Leicht"].tap()

        app.buttons["Zeile 1, Spalte 3, leer"].tap()
        app.buttons["Notizen"].tap()
        for digit in [1, 2, 4] { app.buttons["Ziffer \(digit)"].tap() }
        app.buttons["Notizen"].tap()
        XCTAssertTrue(app.buttons["Zeile 1, Spalte 3, leer, Notizen 1, 2, 4"].exists)
        let cornerCell = app.buttons["Zeile 9, Spalte 9, 9, vorgegeben"]
        let frameWithoutBanner = cornerCell.frame
        app.buttons["Tipp"].tap()
        sleep(1) // let the banner transition finish before the screenshot
        XCTAssertEqual(cornerCell.frame, frameWithoutBanner) // the hint banner must not resize the grid
        attachScreenshot("Spiel Hochformat")

        let lastEmpty = givens.lastIndex(of: ".")!
        for (index, given) in givens.enumerated() where given == "." {
            if index == 40 && UIDevice.current.userInterfaceIdiom == .pad { // the iPhone stays in portrait
                let portraitFrame = cornerCell.frame
                XCUIDevice.shared.orientation = .landscapeLeft
                waitUntilSettled(cornerCell, awayFrom: portraitFrame) // taps during the rotation hit stale cell frames
            }
            if index == 50 && UIDevice.current.userInterfaceIdiom == .pad { attachScreenshot("Spiel Querformat") }
            let cell = "Zeile \(index / 9 + 1), Spalte \(index % 9 + 1)"
            let notes = index == 2 ? ", Notizen 1, 2, 4" : "" // the cell noted above
            let button = app.buttons["\(cell), leer\(notes)"]
            if !button.isSelected { button.tap() } // tapping the selected cell again would clear the selection
            app.buttons["Ziffer \(solution[index])"].tap()
            if index != lastEmpty { // the last entry ends the game and replaces the grid with the result
                XCTAssertTrue(app.buttons["\(cell), \(solution[index])"].waitForExistence(timeout: 5),
                              "\(cell) does not show \(solution[index]); a cell or digit tap was missed")
            }
        }

        XCTAssertTrue(app.buttons["Neues Spiel"].waitForExistence(timeout: 5))
        attachScreenshot("Auswertung")
        app.buttons["Neues Spiel"].tap()
        XCTAssertTrue(app.buttons["Zeile 1, Spalte 3, leer"].waitForExistence(timeout: 5))
    }

    /// App Store screenshots. Skipped in normal runs; the Screenshots workflow sets SCREENSHOTS=1 and one
    /// SCREENSHOT_LANGUAGE per run. Finds everything by identifier, so it works in every language.
    @MainActor
    func testAppStoreScreenshots() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["SCREENSHOTS"] == "1", "only for the Screenshots workflow")
        let givens = Array("53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79")
        let solution = Array("534678912672195348198342567859761423426853791713924856961537284287419635345286179")
        let empty = givens.indices.filter { givens[$0] == "." }
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["-uiTestFixedPuzzle"], language: environment["SCREENSHOT_LANGUAGE"] ?? "de")
        app.buttons["difficulty-easy"].tap()

        func cell(_ index: Int) -> XCUIElement { app.buttons["cell-\(index)"] }
        func fill(_ indices: some Sequence<Int>) {
            for index in indices {
                cell(index).tap()
                app.buttons["digit-\(solution[index])"].tap()
            }
        }

        fill(empty.prefix(24))
        app.buttons["notes"].tap()
        for index in empty.dropFirst(26).prefix(6) {
            cell(index).tap()
            let digit = Int(String(solution[index]))!
            for note in Set([digit, digit % 9 + 1]).sorted() { app.buttons["digit-\(note)"].tap() }
        }
        app.buttons["notes"].tap()
        cell(0).tap() // the given 5: highlights every 5
        attachScreenshot("1-Spiel")

        app.buttons["hint"].tap()
        sleep(1)
        attachScreenshot("2-Tipp")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 5))
        attachScreenshot("3-Menü")

        app.buttons["continue"].tap()
        fill(empty.dropFirst(24))
        XCTAssertTrue(app.buttons["newGame"].waitForExistence(timeout: 5))
        sleep(1)
        attachScreenshot("4-Auswertung")
    }

    /// The app in `language`; German by default, which the labels in these tests are written in.
    @MainActor
    private func launch(_ arguments: [String] = [], language: String = "de") -> XCUIApplication {
        let regions = ["de": "DE", "en": "US", "fr": "FR", "es": "ES", "it": "IT"]
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(regions[language] ?? "DE")"]
            + arguments
        app.launch()
        return app
    }

    /// Polls until the element has left `oldFrame` and its frame stays the same between two samples.
    @MainActor
    private func waitUntilSettled(_ element: XCUIElement, awayFrom oldFrame: CGRect, timeout: TimeInterval = 10) {
        var previous = oldFrame
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            usleep(300_000)
            let current = element.frame
            if current != oldFrame && current == previous { return }
            previous = current
        }
        XCTFail("\(element) did not settle in a new frame within \(timeout) s")
    }

    @MainActor
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testTwoFingerTapUndoes() {
        let app = launch(["-uiTestFixedPuzzle"])
        app.buttons["Leicht"].tap()
        app.buttons["Zeile 1, Spalte 3, leer"].tap()
        app.buttons["Ziffer 4"].tap()
        app.buttons["Zeile 1, Spalte 3, 4"].twoFingerTap()
        XCTAssertTrue(app.buttons["Zeile 1, Spalte 3, leer"].waitForExistence(timeout: 2))
    }
}
