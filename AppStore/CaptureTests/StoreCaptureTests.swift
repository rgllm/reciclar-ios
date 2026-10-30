import Foundation
import XCTest

/// Release captures of the installed app against the production API.
/// Community reports are opened and never submitted.
@MainActor
final class StoreCaptureTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        grantLocation()
        setLocation(latitude: 41.5388, longitude: -8.6151)
        app.launchArguments = [
            "-StoreScreenshots",
            "-AppleLanguages", "(pt-PT)",
            "-AppleLocale", "pt_PT",
        ]
        app.launch()
        acceptSystemPrompts()
        overrideStatusBar()
    }

    func testStoreScreens() {
        let search = app.buttons["Pesquisar lugar ou morada"]
        XCTAssertTrue(search.waitForExistence(timeout: 40), "the map chrome did not appear")
        openPlace("Barcelos")
        if !waitForMapContent(timeout: 50) {
            openPlace("Braga")
            XCTAssertTrue(waitForMapContent(timeout: 50), "no ecopontos appeared in Barcelos or Braga")
        }
        zoomUntilPinsOrGiveUp()
        settle(8)
        overrideStatusBar()
        assertNoSemLeituraCallout()
        capture("01-mapa")

        openFirstEcoponto()
        XCTAssertTrue(app.buttons["Reportar problema"].waitForExistence(timeout: 15))
        reveal("Reportar problema")
        settle(1)
        overrideStatusBar()
        capture("02-ecoponto")

        revealReportChoices()
        XCTAssertTrue(app.buttons["Lixo fora dos contentores"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Vandalizado"].exists)
        settle(1)
        overrideStatusBar()
        capture("03-reportar")
        closeDetail()

        app.tabBars.buttons["Reciclagem"].tap()
        let guideSearch = app.searchFields["Onde deito isto?"]
        XCTAssertTrue(guideSearch.waitForExistence(timeout: 15))
        guideSearch.tap()
        guideSearch.typeText("verniz de vidro")
        let entry = element(containing: "Frasco de verniz de vidro")
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.buttons["Ver no mapa"].waitForExistence(timeout: 10))
        dismissKeyboard()
        reveal("Fontes")
        settle(1)
        overrideStatusBar()
        capture("04-guia")

        app.buttons["Ver no mapa"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        _ = waitForMapContent(timeout: 40)
        let glassFilter = app.buttons.matching(
            NSPredicate(format: "selected == true AND label CONTAINS[cd] %@", "vidro")
        ).firstMatch
        XCTAssertTrue(glassFilter.waitForExistence(timeout: 15), "the glass filter chip was not selected")
        settle(6)
        overrideStatusBar()
        assertNoSemLeituraCallout()
        capture("05-guia-mapa")

        app.tabBars.buttons["Estatísticas"].tap()
        XCTAssertTrue(app.staticTexts["Ecopontos"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Total"].waitForExistence(timeout: 20))
        settle(1)
        overrideStatusBar()
        capture("06-estatisticas")

        app.tabBars.buttons["Mapa"].tap()
        clearFiltersIfNeeded()
        openUncoveredPlace()
        XCTAssertTrue(
            app.staticTexts["Sem ecopontos nesta zona"].waitForExistence(timeout: 20),
            "the empty-area message did not appear"
        )
        settle(2)
        overrideStatusBar()
        capture("07-sem-cobertura")
    }

    private func openPlace(_ name: String) {
        let search = app.buttons["Pesquisar lugar ou morada"]
        if !search.waitForExistence(timeout: 10) { app.swipeDown() }
        if !search.isHittable { app.swipeDown() }
        search.tap()
        let field = searchField()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("\(name), Portugal")
        let place = searchResult(named: name)
        XCTAssertTrue(place.waitForExistence(timeout: 30), "no search result for \(name)")
        place.tap()
        XCTAssertTrue(search.waitForExistence(timeout: 20))
    }

    private func searchField() -> XCUIElement {
        let prompted = app.searchFields["Lugar ou morada"]
        if prompted.waitForExistence(timeout: 3) { return prompted }
        return app.searchFields.firstMatch
    }

    private func searchResult(named name: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[cd] %@", name)
        return waitUntilElement(timeout: 30) {
            let table = self.app.tables.buttons.matching(predicate).firstMatch
            if table.exists { return table }
            let collection = self.app.collectionViews.buttons.matching(predicate).firstMatch
            if collection.exists { return collection }
            let sheet = self.app.sheets.buttons.matching(predicate).firstMatch
            if sheet.exists { return sheet }
            return nil
        } ?? app.collectionViews.buttons.matching(predicate).firstMatch
    }

    private func openUncoveredPlace() {
        for name in ["Beja", "Evora", "Braganca"] {
            openPlace(name)
            if app.staticTexts["Sem ecopontos nesta zona"].waitForExistence(timeout: 20) {
                return
            }
            if app.buttons["Tentar novamente"].exists {
                app.buttons["Tentar novamente"].tap()
                if app.staticTexts["Sem ecopontos nesta zona"].waitForExistence(timeout: 20) {
                    return
                }
            }
        }
    }

    private func waitForMapContent(timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            self.element(containing: "contentor").exists
                || self.element(containing: "Grupo de").exists
                || self.element(containing: "Com espaço").exists
        }
    }

    private func zoomUntilPinsOrGiveUp() {
        for _ in 0..<6 {
            if element(containing: "contentor").exists { return }
            let map = app.maps.firstMatch
            if map.exists { map.pinch(withScale: 2.0, velocity: 1) }
            settle(2)
        }
    }

    private func openFirstEcoponto() {
        app.buttons["Mais filtros"].tap()
        let list = app.buttons["Lista de ecopontos visíveis"]
        if !list.waitForExistence(timeout: 8) { app.swipeUp() }
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        list.tap()
        XCTAssertTrue(app.navigationBars["Lista"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                self.listRow(containing: "Com espaço") != nil
                    || self.listRow(containing: "Ocupação") != nil
                    || self.app.cells.firstMatch.exists
            },
            "the visible list was empty"
        )
        let row = listRow(containing: "Com espaço")
            ?? listRow(containing: "Ocupação")
            ?? app.cells.firstMatch
        row.tap()
        XCTAssertTrue(app.buttons["Reportar problema"].waitForExistence(timeout: 15))
    }

    private func listRow(containing text: String) -> XCUIElement? {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let cell = app.cells.matching(predicate).firstMatch
        if cell.exists { return cell }
        let button = app.collectionViews.buttons.matching(predicate).firstMatch
        if button.exists { return button }
        let tableButton = app.tables.buttons.matching(predicate).firstMatch
        if tableButton.exists { return tableButton }
        return nil
    }

    private func revealReportChoices() {
        moveToOpenEcoponto()
        let report = app.buttons["Reportar problema"]
        if !report.isEnabled {
            let verify = app.buttons["Verificar a minha posição"]
            if verify.waitForExistence(timeout: 8) { verify.tap() }
            _ = waitUntil(timeout: 25) { report.isEnabled }
        }
        XCTAssertTrue(report.isEnabled, "reporting stayed disabled, so the choices could not be shown")
        report.tap()
        reveal("Lixo fora dos contentores")
        reveal("Vandalizado")
    }

    private func moveToOpenEcoponto() {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "ecoponto-coordinates:")
        var coordinate = app.descendants(matching: .any).matching(predicate).firstMatch
        var swipes = 0
        while !coordinate.exists, swipes < 6 {
            app.swipeUp()
            swipes += 1
            coordinate = app.descendants(matching: .any).matching(predicate).firstMatch
        }
        XCTAssertTrue(coordinate.exists, "the ecoponto coordinate was not exposed")
        let identifier = coordinate.identifier
        let token = identifier.split(separator: ":", maxSplits: 1).dropFirst().joined()
        let parts = token.split(separator: ",").map(String.init)
        guard parts.count == 2, let latitude = Double(parts[0]), let longitude = Double(parts[1]) else {
            XCTFail("could not parse coordinates from \(identifier)")
            return
        }
        setLocation(latitude: latitude, longitude: longitude)
        settle(2)
    }

    private func clearFiltersIfNeeded() {
        let clear = app.buttons["Limpar"]
        if clear.exists, clear.isHittable {
            clear.tap()
            return
        }
        guard clear.exists else { return }
        app.buttons["Mais filtros"].tap()
        let sheetClear = app.buttons["Limpar filtros"]
        XCTAssertTrue(sheetClear.waitForExistence(timeout: 8))
        sheetClear.tap()
        let close = app.buttons["Fechar"]
        if close.waitForExistence(timeout: 3) { close.tap() }
    }

    private func closeDetail() {
        let close = app.buttons["Fechar"]
        if close.waitForExistence(timeout: 5), close.isHittable {
            close.tap()
            return
        }
        app.swipeDown()
    }

    private func reveal(_ label: String) {
        var swipes = 0
        let target = element(containing: label)
        while !target.isHittable, swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
    }

    private func dismissKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        for title in ["Procurar", "Pesquisar", "Search", "Ir"] {
            let key = keyboard.buttons[title]
            if key.exists {
                key.tap()
                return
            }
        }
    }

    private func element(containing text: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let button = app.buttons.matching(predicate).firstMatch
        if button.exists { return button }
        let cell = app.cells.matching(predicate).firstMatch
        if cell.exists { return cell }
        let textElement = app.staticTexts.matching(predicate).firstMatch
        if textElement.exists { return textElement }
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    private func assertNoSemLeituraCallout() {
        let callout = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Sem leitura")
        ).firstMatch
        XCTAssertFalse(callout.exists, "a Sem leitura label is visible")
    }

    private func capture(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        post(path: "/screenshot?name=\(name)", body: shot.pngRepresentation)
    }

    /// The UI test runs in the simulator, so simctl is invoked on the Mac via the bridge.
    private func grantLocation() {
        post(path: "/privacy", body: Data())
    }

    private func setLocation(latitude: Double, longitude: Double) {
        let body = String(format: "%.6f,%.6f", latitude, longitude)
        post(path: "/location", body: Data(body.utf8))
    }

    private func overrideStatusBar() {
        post(path: "/status-bar", body: Data())
    }

    private func post(path: String, body: Data) {
        let base = ProcessInfo.processInfo.environment["SIMCTL_BRIDGE_URL"] ?? "http://127.0.0.1:8765"
        guard let url = URL(string: base + path) else {
            XCTFail("invalid bridge URL \(base)\(path)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 30
        let state = BridgeState()
        let session = URLSession(configuration: .ephemeral)
        session.dataTask(with: request) { data, response, error in
            if let error {
                state.message = error.localizedDescription
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let detail = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                state.message = "HTTP \(http.statusCode) \(detail)"
            }
            state.semaphore.signal()
        }.resume()
        let wait = state.semaphore.wait(timeout: .now() + 35)
        session.finishTasksAndInvalidate()
        if wait == .timedOut {
            XCTFail("simctl bridge timed out for \(path)")
            return
        }
        if let message = state.message {
            XCTFail("simctl bridge \(path): \(message)")
        }
    }

    private func acceptSystemPrompts() {
        addUIInterruptionMonitor(withDescription: "system prompt") { alert in
            for title in [
                "Permitir durante a utilização da app",
                "Permitir ao usar a app",
                "Permitir uma vez",
                "Allow While Using App",
                "Allow Once",
            ] {
                let button = alert.buttons[title]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }

    private func settle(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        return condition()
    }

    private func waitUntilElement(timeout: TimeInterval, _ body: () -> XCUIElement?) -> XCUIElement? {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if let element = body() { return element }
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        return body()
    }
}

private final class BridgeState: @unchecked Sendable {
    var message: String?
    let semaphore = DispatchSemaphore(value: 0)
}
