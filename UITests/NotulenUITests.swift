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

        // Na openen moet je verplicht aangeven wie jij bent.
        row.tap()
        let field1 = app.textFields["naam-1"]
        XCTAssertTrue(field1.waitForExistence(timeout: 5), "'Wie ben jij?' opent vanzelf")
        let save = app.buttons["Bewaar"]
        XCTAssertFalse(save.isEnabled, "bewaren kan pas na 'Dit ben ik'")
        XCTAssertFalse(app.buttons["Annuleer"].exists, "verplicht: geen annuleerknop")
        shot("02-wie-ben-jij")

        field1.tap()
        field1.typeText("Jan")
        let me = app.switches["ik-1"]
        me.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(me.value as? String, "1", "'Dit ben ik' staat aan bij stem 1")
        XCTAssertTrue(save.isEnabled, "bewaren kan nu")
        shot("03-sprekers-benoemen")
        save.tap()

        XCTAssertTrue(app.staticTexts["Jan"].firstMatch.waitForExistence(timeout: 5), "eigen naam bij de uitspraken")
        XCTAssertTrue(app.staticTexts["Persoon 2"].firstMatch.exists, "de ander heet standaard 'Persoon 2'")
        shot("04-gesprek-met-namen")

        // Naam van de ander later alsnog invullen (vrijblijvend).
        app.buttons["Sprekers benoemen"].tap()
        let field2 = app.textFields["naam-2"]
        XCTAssertTrue(field2.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Annuleer"].exists, "na de eerste keer wel annuleren")
        field2.tap()
        field2.typeText("Petra")
        app.buttons["Bewaar"].tap()
        XCTAssertTrue(app.staticTexts["Petra"].firstMatch.waitForExistence(timeout: 5), "naam Petra bij de uitspraken")

        app.buttons["Meer"].firstMatch.tap()
        shot("05-menu")
    }

    func test8_LijstMetNaamtags() {
        app.launch()
        let row = app.buttons["opname-Offertegesprek badkamer"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertTrue(row.label.contains("Jan") && row.label.contains("Petra"), "namen als tags onder de titel: \(row.label)")
        XCTAssertTrue(row.label.contains("oktober") || row.label.contains("okt") || row.label.contains("2026"), "datum onder de titel: \(row.label)")
        shot("18-lijst-met-tags")
    }

    func test9_NaamWijzigen() {
        app.launch()
        let row = app.buttons["opname-Lang overleg"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        let titleButton = app.buttons["Naam wijzigen: Lang overleg"]
        XCTAssertTrue(titleButton.waitForExistence(timeout: 5), "titel is aantikbaar")
        titleButton.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20) + "Teamoverleg november")
        shot("19-naam-wijzigen")
        app.alerts.buttons["Bewaar"].tap()
        XCTAssertTrue(app.buttons["Naam wijzigen: Teamoverleg november"].waitForExistence(timeout: 5), "nieuwe naam opgeslagen")
    }

    func test5_DelenMetAI() {
        app.launch()

        // Kort gesprek: de tekst gaat direct mee in de link.
        let row = app.buttons["opname-Offertegesprek badkamer"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        answerWhoAmIIfAsked()
        XCTAssertTrue(app.buttons["Deel met AI"].firstMatch.waitForExistence(timeout: 5))
        shot("10-ai-stap1-gesprek")

        app.buttons["Deel met AI"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Deel met ChatGPT"].waitForExistence(timeout: 5), "AI-menu toont ChatGPT")
        XCTAssertTrue(app.buttons["Deel met Claude"].exists, "AI-menu toont Claude")
        shot("11-ai-stap2-kies-chatgpt-of-claude")

        XCTAssertTrue(app.buttons["Deel als tekstbestand"].exists, "AI-menu toont tekstbestand")
        app.buttons["Deel met ChatGPT"].tap()
        XCTAssertTrue(app.buttons["Samenvatting en actiepunten"].waitForExistence(timeout: 5), "taken zichtbaar")
        XCTAssertTrue(app.buttons["Notulen maken"].exists)
        XCTAssertTrue(app.buttons["Alleen de tekst"].exists)
        shot("12-ai-stap3-kies-taak")

        app.buttons["Samenvatting en actiepunten"].tap()
        waitForSafari()
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
        waitForSafari()
        shot("15-ai-claude-geopend")
    }

    /// Als "Wie ben jij?" nog verschijnt (bijv. als test 1 niet draaide): invullen.
    private func answerWhoAmIIfAsked() {
        let me = app.switches["ik-1"]
        if me.waitForExistence(timeout: 3), app.buttons["Bewaar"].exists, !app.buttons["Annuleer"].exists {
            me.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            app.buttons["Bewaar"].tap()
        }
    }

    /// In de simulator staan de ChatGPT- en Claude-apps niet, dus opent Safari.
    /// Wachten tot die echt op de voorgrond staat en de pagina geladen is.
    private func waitForSafari() {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 30), "website wordt geopend")
        sleep(15)
    }

    func test6_Importeren() {
        app.launch()
        let button = app.buttons["Gesprek importeren"]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "grijze importknop boven opnemen")
        XCTAssertTrue(app.buttons["Opnemen"].exists)
        XCTAssertLessThan(button.frame.minY, app.buttons["Opnemen"].frame.minY, "importknop staat boven de opnameknop")
        button.tap()
        XCTAssertTrue(app.buttons["Open Dictafoon"].waitForExistence(timeout: 5), "uitleg Dictafoon")
        XCTAssertTrue(app.buttons["Kies een audiobestand"].exists, "optie Bestanden")
        shot("16-importeren")
    }

    func test7_DelenAlsTekstbestand() {
        app.launch()
        let row = app.buttons["opname-Offertegesprek badkamer"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        answerWhoAmIIfAsked()
        app.buttons["Deel met AI"].firstMatch.tap()
        app.buttons["Deel als tekstbestand"].tap()
        XCTAssertTrue(app.buttons["Notulen maken"].waitForExistence(timeout: 5))
        app.buttons["Notulen maken"].tap()
        let shareSheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 10), "iOS-deelmenu verschijnt met het tekstbestand")
        sleep(2)
        shot("17-deel-als-tekstbestand")
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
        XCTAssertTrue(app.secureTextFields["api-sleutel"].waitForExistence(timeout: 5), "veld voor AssemblyAI-sleutel zichtbaar")
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
