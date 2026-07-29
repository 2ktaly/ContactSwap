import XCTest

/// Prüft die beiden Eigenheiten der Swap-Seite, die sich nur am laufenden
/// Programm zeigen: die eigene Liste der behaltenen Kontakte und die
/// Bestätigung als Feld in der Liste statt als Pop-up.
final class SwapFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBehaltenBekommtEigenenAbschnitt() throws {
        let app = launchApp()

        XCTAssertFalse(app.staticTexts["Behalten (1)"].exists,
                       "Ohne Auswahl darf der Abschnitt nicht auftauchen")

        firstContact(in: app).tap()

        XCTAssertTrue(app.staticTexts["Behalten (1)"].waitForExistence(timeout: 2),
                      "Nach der Auswahl fehlt der eigene Behalten-Abschnitt")
        XCTAssertTrue(app.staticTexts["Alle Kontakte (6)"].exists,
                      "Die vollständige Liste muss darunter bestehen bleiben")

        attachScreenshot(app, name: "Behalten-Abschnitt")
    }

    @MainActor
    func testLeerenZeigtBestaetigungAlsFeldStattPopup() throws {
        let app = launchApp()
        firstContact(in: app).tap()

        app.buttons["Leeren"].tap()

        // Ein confirmationDialog wäre ein Sheet – die Bestätigung muss
        // stattdessen als normale Zeile in der Liste erscheinen.
        XCTAssertTrue(app.staticTexts["Adressbuch leeren?"].waitForExistence(timeout: 2),
                      "Die Bestätigung fehlt")
        XCTAssertEqual(app.sheets.count, 0, "Die Bestätigung darf kein Pop-up sein")
        XCTAssertTrue(app.buttons["Sichern und leeren"].exists)
        XCTAssertTrue(app.buttons["Abbrechen"].exists)

        // Die Auswahl bleibt währenddessen sichtbar – genau das kann ein
        // Pop-up nicht leisten.
        XCTAssertTrue(app.staticTexts["Behalten (1)"].exists,
                      "Die Auswahl muss neben der Bestätigung sichtbar bleiben")

        attachScreenshot(app, name: "Bestätigung als Feld")

        app.buttons["Abbrechen"].tap()
        XCTAssertFalse(app.staticTexts["Adressbuch leeren?"].waitForExistence(timeout: 1),
                       "Abbrechen muss das Feld wieder schließen")
    }

    @MainActor
    func testKostenloseFassungStehtNurInDenEinstellungen() throws {
        let app = launchApp()

        XCTAssertFalse(app.staticTexts["Kostenlose Fassung"].exists,
                       "Die Swap-Seite soll frei von Hinweisen zur Fassung bleiben")

        app.tabBars.buttons["Einstellungen"].tap()

        XCTAssertTrue(app.staticTexts["Swaps übrig"].waitForExistence(timeout: 2),
                      "In den Einstellungen fehlt der Zähler")
        XCTAssertTrue(app.buttons["buy-lifetime"].exists, "Kauf-Knopf fehlt")
        XCTAssertTrue(app.buttons["restore-purchase"].exists, "Wiederherstellen fehlt")
        XCTAssertTrue(app.buttons["bulk-licenses"].exists, "Hinweis auf Massenlizenzen fehlt")

        attachScreenshot(app, name: "Einstellungen mit Kaufbereich")
    }

    @MainActor
    func testEinfuehrungKommtVorDerBerechtigungsfrage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenWelcome", "NO", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Willkommen"].waitForExistence(timeout: 5),
                      "Der Einführungsbildschirm fehlt")
        XCTAssertTrue(app.staticTexts["Kontaktzugriff wird benötigt"].exists)
        XCTAssertTrue(app.staticTexts["Ausschließlich auf diesem Gerät"].exists)

        // Der Systemdialog darf erst nach dem Weiter-Knopf erscheinen.
        XCTAssertFalse(app.staticTexts["Ausschließlich lokal"].exists,
                       "Die Swap-Seite darf vor dem Weiter-Knopf nicht sichtbar sein")

        attachScreenshot(app, name: "Einführung")

        XCTAssertTrue(app.buttons["Weiter"].exists, "Weiter-Knopf fehlt")
    }

    /// Prüft, dass ein nicht-deutsches System die App auf Englisch bekommt.
    /// Französisch steht hier für „irgendeine Sprache, die es nicht gibt“: Es
    /// muss auf Englisch zurückfallen, nicht auf Deutsch.
    @MainActor
    func testFremdspracheBekommtEnglisch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenWelcome", "NO", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5),
                      "Ein französisches System muss auf Englisch fallen, nicht auf Deutsch")
        XCTAssertFalse(app.staticTexts["Willkommen"].exists)
        XCTAssertTrue(app.staticTexts["Contact access required"].exists)
        XCTAssertTrue(app.buttons["Continue"].exists)

        attachScreenshot(app, name: "Englische Fassung")
    }

    // MARK: - Hilfen

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        // Überspringt den Einführungsbildschirm, der sonst jedem Test im Weg
        // stünde, und legt die Sprache fest: Diese Tests prüfen die deutschen
        // Texte, unabhängig davon, wie der Simulator eingestellt ist.
        app.launchArguments = ["-hasSeenWelcome", "YES", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Ausschließlich lokal"].waitForExistence(timeout: 5),
                      "Swap-Seite wurde nicht geladen – fehlt der Kontaktzugriff?")
        return app
    }

    @MainActor
    private func firstContact(in app: XCUIApplication) -> XCUIElement {
        let contact = app.buttons["Anna Haro, 555-522-8243"]
        return contact.exists ? contact : app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "Anna Haro")
        ).firstMatch
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
