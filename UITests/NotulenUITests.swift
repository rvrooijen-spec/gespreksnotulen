import XCTest

/// Loopt alle schermen door met voorbeeldgesprekken (-demoData) en bewaart
/// schermafbeeldingen in SCREENSHOT_DIR (via TEST_RUNNER_SCREENSHOT_DIR).
final class NotulenUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        // Systeemmeldingen (bijv. microfoontoegang) automatisch toestaan.
        addUIInterruptionMonitor(withDescription: "Systeemmelding") { alert in
            for label in ["Allow", "OK", "Sta toe", "Toestaan"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    private func shot(_ name: String) {
        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? NSTemporaryDirectory()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test1_GesprekBekijkenEnSprekersBenoemen() {
        app.launch()
        let row = app.buttons["opname-Offertegesprek badkamer"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "voorbeeldgesprek staat in de lijst")
        XCTAssertTrue(app.buttons["opname-Overleg aannemer"].exists, "niet-uitgeschreven opname staat in de lijst")
        shot("01-lijst")

        row.tap()
        XCTAssertTrue(app.staticTexts["Spreker 1"].firstMatch.waitForExistence(timeout: 5), "uitspraken met sprekers zichtbaar")
        XCTAssertTrue(app.staticTexts["Spreker 2"].firstMatch.exists)
        shot("02-gesprek")

        app.buttons["Sprekers benoemen"].tap()
        let field1 = app.textFields["naam-1"]
        XCTAssertTrue(field1.waitForExistence(timeout: 5), "naamveld voor spreker 1")
        field1.tap()
        field1.typeText("Jan")
        let field2 = app.textFields["naam-2"]
        field2.tap()
        field2.typeText("Petra")
        shot("03-sprekers-benoemen")
        app.buttons["Bewaar"].tap()

        XCTAssertTrue(app.staticTexts["Jan"].firstMatch.waitForExistence(timeout: 5), "naam Jan staat bij de uitspraken")
        XCTAssertTrue(app.staticTexts["Petra"].firstMatch.exists, "naam Petra staat bij de uitspraken")
        XCTAssertFalse(app.staticTexts["Spreker 1"].exists, "'Spreker 1' is vervangen door de naam")
        shot("04-gesprek-met-namen")

        app.buttons["Meer"].firstMatch.tap()
        shot("05-menu")
    }

    func test5_DelenMetAI() {
        app.launch()

        // Kort gesprek: de tekst gaat direct mee in de link.
        let row = app.buttons["opname-Offertegesprek badkamer"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.staticTexts["Spreker 1"].firstMatch.waitForExistence(timeout: 5))
        shot("10-ai-stap1-gesprek")

        app.buttons["Deel met AI"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Deel met ChatGPT"].waitForExistence(timeout: 5), "AI-menu toont ChatGPT")
        XCTAssertTrue(app.buttons["Deel met Claude"].exists, "AI-menu toont Claude")
        shot("11-ai-stap2-kies-chatgpt-of-claude")

        app.buttons["Deel met ChatGPT"].tap()
        XCTAssertTrue(app.buttons["Samenvatting en actiepunten"].waitForExistence(timeout: 5), "taken zichtbaar")
        XCTAssertTrue(app.buttons["Notulen maken"].exists)
        XCTAssertTrue(app.buttons["Alleen de tekst"].exists)
        shot("12-ai-stap3-kies-taak")

        app.buttons["Samenvatting en actiepunten"].tap()
        sleep(10)
        shot("13-ai-stap4-chatgpt-geopend")

        // Lang gesprek: via het klembord, met uitleg.
        app.activate()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let longRow = app.buttons["opname-Lang overleg"]
        XCTAssertTrue(longRow.waitForExistence(timeout: 10))
        longRow.tap()
        app.buttons["Deel met AI"].firstMatch.tap()
        app.buttons["Deel met Claude"].tap()
        app.buttons["Notulen maken"].tap()
        let alert = app.alerts["Tekst gekopieerd"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "melding bij lang gesprek")
        shot("14-ai-lang-gesprek-melding")
        alert.buttons["Open Claude"].tap()
        sleep(10)
        shot("15-ai-claude-geopend")
    }

    func test2_Zoeken() {
        app.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15), "zoekveld zichtbaar")
        search.tap()
        search.typeText("offerte")
        XCTAssertTrue(app.buttons["opname-Offertegesprek badkamer"].waitForExistence(timeout: 5), "zoeken vindt tekst in het gesprek")
        XCTAssertFalse(app.buttons["opname-Overleg aannemer"].exists, "andere opname wordt weggefilterd")
        shot("06-zoeken")
    }

    func test3_Instellingen() {
        app.launch()
        let button = app.buttons["Instellingen"]
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
        XCTAssertTrue(app.staticTexts["Spraakmodellen nodig"].waitForExistence(timeout: 5), "modelstatus zichtbaar")
        shot("07-instellingen")
        app.buttons["Klaar"].tap()
    }

    func test4_Opnemen() {
        app.launch()
        let record = app.buttons["Opnemen"]
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()
        app.tap() // geeft de interruption monitor de kans een melding weg te tikken
        sleep(4)
        shot("08-opnemen")

        let stop = app.buttons["Stoppen en bewaren"]
        if stop.exists, stop.isEnabled {
            stop.tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
            sleep(2)
            shot("09-na-opname")
        } else {
            // Simulator zonder microfoon: netjes annuleren moet werken.
            app.buttons["Annuleren"].tap()
            app.buttons["Weggooien"].firstMatch.tap()
            XCTAssertTrue(record.waitForExistence(timeout: 10), "terug in de lijst na annuleren")
            shot("09-na-annuleren")
        }
    }
}
