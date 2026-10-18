import XCTest

final class SmokeTests: XCTestCase {
    @MainActor
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    @MainActor
    func testStartGameEnterDigitAndCheck() {
        let app = XCUIApplication(); app.launchArguments = ["-uiTestFixedPuzzle"]; app.launch()
        app.buttons["Leicht"].tap()
        app.buttons["Zeile 1, Spalte 3, leer"].tap()
        app.buttons["Ziffer 9"].tap()           // bekannt falsch im Fixture
        app.buttons["Überprüfen"].tap()
        XCTAssertTrue(app.buttons["Zeile 1, Spalte 3, 9, falsch"].exists)
    }

    /// Plays the fixed puzzle to the end, through portrait and landscape, and starts the next game.
    @MainActor
    func testPlayThroughToResultAndNewGame() {
        let givens = Array("53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79")
        let solution = Array("534678912672195348198342567859761423426853791713924856961537284287419635345286179")
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication(); app.launchArguments = ["-uiTestFixedPuzzle"]; app.launch()
        app.buttons["Leicht"].tap()

        app.buttons["Zeile 1, Spalte 3, leer"].tap()
        app.buttons["Notizen"].tap()
        for digit in [1, 2, 4] { app.buttons["Ziffer \(digit)"].tap() }
        app.buttons["Notizen"].tap()
        let cornerCell = app.buttons["Zeile 9, Spalte 9, 9"]
        let frameWithoutBanner = cornerCell.frame
        app.buttons["Tipp"].tap()
        sleep(1) // let the banner transition finish before the screenshot
        XCTAssertEqual(cornerCell.frame, frameWithoutBanner) // the hint banner must not resize the grid
        attachScreenshot("Spiel Hochformat")

        for (index, given) in givens.enumerated() where given == "." {
            if index == 40 {
                XCUIDevice.shared.orientation = .landscapeLeft
                sleep(2) // taps during the rotation animation hit stale cell frames
            }
            if index == 50 { attachScreenshot("Spiel Querformat") }
            app.buttons["Zeile \(index / 9 + 1), Spalte \(index % 9 + 1), leer"].tap()
            app.buttons["Ziffer \(solution[index])"].tap()
        }

        XCTAssertTrue(app.buttons["Neues Spiel"].waitForExistence(timeout: 5))
        attachScreenshot("Auswertung")
        app.buttons["Neues Spiel"].tap()
        XCTAssertTrue(app.buttons["Zeile 1, Spalte 3, leer"].waitForExistence(timeout: 5))
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
        let app = XCUIApplication(); app.launchArguments = ["-uiTestFixedPuzzle"]; app.launch()
        app.buttons["Leicht"].tap()
        app.buttons["Zeile 1, Spalte 3, leer"].tap()
        app.buttons["Ziffer 4"].tap()
        app.buttons["Zeile 1, Spalte 3, 4"].twoFingerTap()
        XCTAssertTrue(app.buttons["Zeile 1, Spalte 3, leer"].waitForExistence(timeout: 2))
    }
}
