import ReciclarCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Security)
import Security
#endif

@main
enum ReciclarCoreChecks {
    static func main() async {
        let areaFailures = await runAreaChecks()
        for failure in areaFailures { FileHandle.standardError.write(Data("FAIL area: \(failure)\n".utf8)) }
        let reportFailures = await runReportChecks()
        for failure in reportFailures { FileHandle.standardError.write(Data("FAIL report: \(failure)\n".utf8)) }
        let tileFailures = runTileChecks()
        for failure in tileFailures { FileHandle.standardError.write(Data("FAIL tile: \(failure)\n".utf8)) }
        var failures = areaFailures.count + reportFailures.count + tileFailures.count

        func expect(_ condition: Bool, _ message: String, file: StaticString = #fileID, line: UInt = #line) {
            if !condition {
                failures += 1
                FileHandle.standardError.write(Data("FAIL \(file):\(line) \(message)\n".utf8))
            }
        }

        do {
            let data = try FixtureResource.sampleLocationPayloadJSON()
            let result = try LocationNormalizer.decode(from: data, provenance: .developmentFixture)
            let location = result.locations[0]
            expect(location.id == "SYN-1001", "idlocal kept as string")
            expect(location.concessionaireID == "OP-7", "concessionaire kept as string")
            expect(location.address == nil, "blank address omitted")
            expect(location.locationDescription == nil, "blank description omitted")
            expect(location.displayName == "Vila Norte", "display name uses locality")
            expect(location.containers.count == 3, "three containers preserved")
            expect(location.containers.map(\.id) == ["C-1001", "C-1002", "C-1003"], "container ids kept as strings")
            expect(location.containers[0].category.id == WasteCategory.sampleGlass.id, "glass category")
            expect(location.containers[1].category.id == WasteCategory.samplePackaging.id, "packaging category")
            expect(location.containers[2].category.id == WasteCategory.samplePaper.id, "paper category")
            expect(location.containers[0].volumeLitres == 2500, "volume parsed")
            expect(location.containers[0].fillReading?.percentFull == 25, "percent parsed")
            expect(location.containers[2].fillReading == nil, "malformed percent is not zero")
            expect(DataProvenance.userFacingLabel(from: "Catálogo / Operador Alfa") == "Operador Alfa", "provenance keeps operator")
            expect(DataProvenance.userFacingLabel(from: "   ") == nil, "blank provenance is hidden")

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
            let parts = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: location.containers[0].fillReading!.recordedAt
            )
            expect(parts.year == 2026 && parts.month == 8 && parts.day == 11 && parts.hour == 10 && parts.minute == 15, "Lisbon timestamp")
        } catch {
            failures += 1
            FileHandle.standardError.write(Data("FAIL sample payload \(error)\n".utf8))
        }

        do {
            let json = """
            {"idlocal":"9","latitude":41.5,"longitude":-8.4,"Containers":[{"idcontainer_sensor":"x","idwaste_type":"99","waste_desc":"Fluxo novo"}]}
            """.data(using: .utf8)!
            let location = try LocationNormalizer.decode(from: json, provenance: .developmentFixture).locations[0]
            expect(location.containers[0].category.id.rawValue == "99", "unknown category id")
            expect(location.containers[0].category.name == "Fluxo novo", "unknown category name")
        } catch {
            failures += 1
            FileHandle.standardError.write(Data("FAIL unknown category \(error)\n".utf8))
        }

        do {
            let json = """
            [{"idlocal":"a","latitude":41.5,"longitude":-8.4,"Containers":[{"idcontainer_sensor":"1","idwaste_type":"2"}]},{"idlocal":"a","latitude":41.6,"longitude":-8.5,"Containers":[{"idcontainer_sensor":"2","idwaste_type":"3"}]}]
            """.data(using: .utf8)!
            let result = try LocationNormalizer.decode(from: json, provenance: .developmentFixture)
            expect(result.locations.count == 1, "duplicate id keeps first")
            expect(result.locations[0].coordinate.latitude == 41.5, "first coordinate kept")
        } catch {
            failures += 1
            FileHandle.standardError.write(Data("FAIL duplicates \(error)\n".utf8))
        }

        do {
            let json = """
            {"idlocal":"bad","latitude":200,"longitude":-8.4,"Containers":[{"idcontainer_sensor":"1","idwaste_type":"2"}]}
            """.data(using: .utf8)!
            let result = try LocationNormalizer.decode(from: json, provenance: .developmentFixture)
            expect(result.locations.isEmpty, "invalid coordinates dropped")
        } catch {
            failures += 1
            FileHandle.standardError.write(Data("FAIL invalid coordinates \(error)\n".utf8))
        }

        let now = Date(timeIntervalSince1970: 1_788_768_000)
        let fresh = FillReading(percentFull: 89, recordedAt: now.addingTimeInterval(-60))
        expect(FillReadingPolicy.hasSpaceAvailable(reading: fresh, at: now), "89 percent has space")
        expect(!FillReadingPolicy.hasSpaceAvailable(reading: FillReading(percentFull: 90, recordedAt: now.addingTimeInterval(-60)), at: now), "90 percent has no space")
        expect(!FillReadingPolicy.hasSpaceAvailable(reading: FillReading(percentFull: 91, recordedAt: now.addingTimeInterval(-60)), at: now), "91 percent has no space")
        expect(FillReadingPolicy.evidence(from: FillReading(percentFull: 10, recordedAt: now.addingTimeInterval(-24 * 60 * 60 - 1)), at: now) == .none, "stale reading")
        expect(FillReadingPolicy.evidence(from: FillReading(percentFull: 10, recordedAt: now.addingTimeInterval(60)), at: now) == .none, "future reading")
        expect(FillReadingPolicy.evidence(from: nil, at: now) == .none, "missing reading")
        expect(FillReadingPolicy.evidence(from: FillReading(percentFull: 20, recordedAt: now.addingTimeInterval(-24 * 60 * 60)), at: now) != .none, "24h edge is usable")

        expect(FillReadingPolicy.maxAge == 24 * 60 * 60, "readings stay usable for 24 hours")
        expect(FillReadingPolicy.spaceAvailableBelowPercent == 90, "space threshold is 90 percent")
        let day = FillReadingPolicy.maxAge
        func reading(_ percent: Int, age: TimeInterval) -> FillReading {
            FillReading(percentFull: percent, recordedAt: now.addingTimeInterval(-age))
        }
        expect(FillReadingPolicy.availability(of: reading(89, age: 1), at: now) == .available, "89 percent is available")
        expect(FillReadingPolicy.availability(of: reading(90, age: 1), at: now) == .noSpace, "exactly 90 percent is not available")
        expect(FillReadingPolicy.availability(of: reading(91, age: 1), at: now) == .noSpace, "91 percent is not available")
        expect(FillReadingPolicy.status(of: reading(90, age: 1), at: now).percentFull == 90, "90 percent keeps its reading")
        expect(FillReadingPolicy.availability(of: reading(0, age: 0), at: now) == .available, "0 percent recorded now is available")
        expect(FillReadingPolicy.availability(of: reading(89, age: day), at: now) == .available, "exactly 24h at 89 percent is available")
        expect(FillReadingPolicy.availability(of: reading(0, age: day), at: now) == .available, "exactly 24h under 90 percent is available")
        expect(FillReadingPolicy.availability(of: reading(90, age: day), at: now) == .noSpace, "exactly 24h at 90 percent is not available")
        expect(FillReadingPolicy.availability(of: reading(89, age: day + 1), at: now) == .unknown, "one second past 24h is unknown")
        expect(!FillReadingPolicy.hasSpaceAvailable(reading: reading(0, age: day + 1), at: now), "stale reading is not available")
        expect(FillReadingPolicy.availability(of: nil, at: now) == .unknown, "missing reading is unknown")
        expect(FillReadingPolicy.status(of: nil, at: now).percentFull == nil, "missing reading has no percent")
        expect(FillReadingPolicy.status(of: nil, at: now).portugueseLabel == "Sem leitura", "unknown label")
        expect(!FillReadingPolicy.status(of: nil, at: now).showsMapCaption, "unknown reading has no map caption")
        expect(FillReadingPolicy.status(of: nil, at: now).detailExplanation == LocationSpaceStatus.missingReadingExplanation, "unknown reading is explained on tap")
        expect(FillReadingPolicy.status(of: reading(89, age: 1), at: now).showsMapCaption, "available reading keeps its map caption")
        expect(FillReadingPolicy.status(of: reading(90, age: 1), at: now).showsMapCaption, "full reading keeps its map caption")
        expect(FillReadingPolicy.status(of: reading(89, age: 1), at: now).detailExplanation == nil, "available reading has no missing-reading explanation")
        expect(FillReadingPolicy.status(of: nil, at: now).accessibilityLabel == "Ocupação desconhecida", "unknown voiceover is not available")
        expect(FillReadingPolicy.status(of: reading(89, age: 1), at: now).accessibilityLabel == "Com espaço disponível, 89 por cento ocupado", "available voiceover")
        expect(FillReadingPolicy.status(of: reading(90, age: 1), at: now).accessibilityLabel == "Sem espaço disponível, 90 por cento ocupado", "no-space voiceover")
        expect(FillReadingPolicy.availability(of: FillReading(percentFull: 10, recordedAt: now.addingTimeInterval(1)), at: now) == .unknown, "future reading is unknown")

        func place(_ id: String, _ containers: [Container]) -> Ecoponto {
            Ecoponto(
                id: id,
                coordinate: Coordinate(latitude: 41.5, longitude: -8.4),
                containers: containers,
                provenance: .developmentFixture
            )
        }
        let unknownLocation = place("no-reading", [Container(id: "c", category: WasteCategory.sampleGlass)])
        expect(LocationFilter().spaceStatus(of: unknownLocation, at: now).availability == .unknown, "location without a reading is unknown")
        expect(!LocationFilter(requiresSpaceAvailable: true).matches(unknownLocation, at: now), "unknown location is not filtered as available")
        let emptyContainers = place("no-containers", [])
        expect(LocationFilter().spaceStatus(of: emptyContainers, at: now).availability == .unknown, "location without containers is unknown")
        let fullLocation = place("full", [Container(id: "c", category: WasteCategory.sampleGlass, fillReading: reading(90, age: 60))])
        expect(LocationFilter().spaceStatus(of: fullLocation, at: now).availability == .noSpace, "90 percent location is not available")
        let staleOnly = place("stale", [Container(id: "c", category: WasteCategory.sampleGlass, fillReading: reading(10, age: day + 1))])
        expect(LocationFilter().spaceStatus(of: staleOnly, at: now).availability == .unknown, "stale location is unknown, not available")
        expect(LocationFilter().spaceStatus(of: staleOnly, at: now).accessibilityLabel == "Ocupação desconhecida", "stale voiceover is not available")
        let mixed = place("mixed", [
            Container(id: "g", category: WasteCategory.sampleGlass, fillReading: reading(20, age: 60)),
            Container(id: "p", category: WasteCategory.samplePaper, fillReading: reading(95, age: 60)),
        ])
        expect(LocationFilter().spaceStatus(of: mixed, at: now).availability == .available, "any container under 90 percent makes the location available")
        expect(LocationFilter().spaceStatus(of: mixed, at: now).percentFull == 20, "available percent is the lowest qualifying reading")
        let anySpace = LocationFilter(requiresSpaceAvailable: true)
        expect(anySpace.matches(mixed, at: now), "unfiltered space filter agrees with available status")
        let paperOnly = LocationFilter(requiredTokens: [.stream(.paper)])
        expect(paperOnly.spaceStatus(of: mixed, at: now).availability == .noSpace, "filtered paper at 95 percent is not available")
        var paperSpace = paperOnly
        paperSpace.requiresSpaceAvailable = true
        expect(!paperSpace.matches(mixed, at: now), "paper space filter agrees with no-space status")
        let glassOnly = LocationFilter(requiredTokens: [.stream(.glass)])
        expect(glassOnly.spaceStatus(of: mixed, at: now).availability == .available, "filtered glass at 20 percent is available")
        expect(glassOnly.spaceStatus(of: staleOnly, at: now).availability == .unknown, "stale filtered reading is unknown")
        let glassUnread = place("glass-unread", [
            Container(id: "g", category: WasteCategory.sampleGlass),
            Container(id: "p", category: WasteCategory.samplePaper, fillReading: reading(10, age: 60)),
        ])
        expect(glassOnly.spaceStatus(of: glassUnread, at: now).availability == .unknown, "a missing filtered reading is not available")
        expect(LocationFilter().spaceStatus(of: glassUnread, at: now).availability == .available, "another container can still show space")

        expect(
            MapLoadPresentationPolicy.presentation(
                needsZoom: false, visibleLocationCount: 0, isLoading: false,
                refreshFailed: false, areaLoaded: true, filtersActive: false
            ) == .noCoverage,
            "successful empty area is no coverage"
        )
        expect(
            MapLoadPresentationPolicy.presentation(
                needsZoom: false, visibleLocationCount: 0, isLoading: false,
                refreshFailed: true, areaLoaded: false, filtersActive: false
            ) == .failed,
            "failed download is an error"
        )
        expect(
            MapLoadPresentationPolicy.presentation(
                needsZoom: false, visibleLocationCount: 0, isLoading: false,
                refreshFailed: true, areaLoaded: true, filtersActive: false
            ) == .failed,
            "a failed refresh is not shown as empty coverage"
        )
        expect(
            MapLoadPresentationPolicy.presentation(
                needsZoom: false, visibleLocationCount: 3, isLoading: false,
                refreshFailed: true, areaLoaded: true, filtersActive: false
            ) == .locations,
            "cached locations stay visible when refresh fails"
        )
        expect(
            MapLoadPresentationPolicy.presentation(
                needsZoom: false, visibleLocationCount: 0, isLoading: false,
                refreshFailed: false, areaLoaded: true, filtersActive: true
            ) == .noMatches,
            "active filters are not no coverage"
        )
        expect(
            MapLoadPresentationPolicy.presentation(
                needsZoom: false, visibleLocationCount: 0, isLoading: true,
                refreshFailed: false, areaLoaded: false, filtersActive: false
            ) == .loading,
            "an in-flight load is not an empty area"
        )

        let freshnessCoordinate = Coordinate(latitude: 41.5, longitude: -8.4)
        func located(_ readings: [FillReading]) -> Ecoponto {
            Ecoponto(
                id: "freshness",
                coordinate: freshnessCoordinate,
                containers: readings.enumerated().map { index, reading in
                    Container(id: "c\(index)", category: .sampleGlass, fillReading: reading)
                },
                provenance: .developmentFixture
            )
        }
        let recorded = now.addingTimeInterval(-60)
        let active = located([FillReading(percentFull: 10, recordedAt: recorded)])
        expect(
            FreshnessSchedule.nextFillBoundary(locations: [active], now: now) == recorded.addingTimeInterval(FillReadingPolicy.maxAge),
            "next fill boundary is the 24h expiry"
        )
        let futureRecorded = now.addingTimeInterval(30)
        let future = located([FillReading(percentFull: 10, recordedAt: futureRecorded)])
        expect(FreshnessSchedule.nextFillBoundary(locations: [future], now: now) == futureRecorded, "future reading boundary is when it becomes usable")
        let staleRecorded = now.addingTimeInterval(-(FillReadingPolicy.maxAge + 5))
        let staleLocation = located([FillReading(percentFull: 10, recordedAt: staleRecorded)])
        expect(FreshnessSchedule.nextFillBoundary(locations: [staleLocation], now: now) == .distantFuture, "expired readings do not schedule a boundary")
        let exact = located([FillReading(percentFull: 10, recordedAt: now.addingTimeInterval(-FillReadingPolicy.maxAge))])
        expect(FreshnessSchedule.nextFillBoundary(locations: [exact], now: now) == .distantFuture, "boundary at exactly now is not pending")
        let soon = now.addingTimeInterval(10)
        let later = now.addingTimeInterval(50)
        let boundarySample = located([
            FillReading(percentFull: 10, recordedAt: soon),
            FillReading(percentFull: 20, recordedAt: later.addingTimeInterval(-FillReadingPolicy.maxAge))
        ])
        let oracle = [boundarySample].flatMap { $0.containers.compactMap(\.fillReading) }
            .flatMap { [$0.recordedAt, $0.recordedAt.addingTimeInterval(24 * 60 * 60)] }
            .filter { $0 > now }.min() ?? Date.distantFuture
        expect(FreshnessSchedule.nextFillBoundary(locations: [boundarySample], now: now) == oracle, "fill boundary matches the map walk")
        expect(FreshnessSchedule.nextFillBoundary(locations: [boundarySample], now: now) == soon, "earliest future fill boundary wins")
        let report = CommunityEvent(
            id: "e",
            ecopontoID: "freshness",
            issue: .vandalised,
            kind: .report,
            serverTimestamp: now.addingTimeInterval(-100)
        )
        expect(
            FreshnessSchedule.nextBoundary(locations: [], events: [report], now: now)
                == report.serverTimestamp.addingTimeInterval(CommunityIssuePolicy.expiry),
            "report expiry is a freshness boundary"
        )
        expect(FreshnessSchedule.delay(now: now, notBefore: .distantPast, nextBoundary: now.addingTimeInterval(3_600)) == 60, "freshness waits at most a minute")
        expect(FreshnessSchedule.delay(now: now, notBefore: .distantPast, nextBoundary: now.addingTimeInterval(12)) == 12, "freshness can wake for an earlier expiry")
        expect(
            FreshnessSchedule.delay(now: now, notBefore: now.addingTimeInterval(40), nextBoundary: now.addingTimeInterval(5)) == 40,
            "freshness rate limit holds a nearer expiry"
        )
        expect(FreshnessSchedule.delay(now: now, notBefore: .distantPast, nextBoundary: nil) == 60, "freshness without a boundary waits a minute")
        expect(FreshnessSchedule.delay(now: now, notBefore: .distantPast, nextBoundary: now.addingTimeInterval(-5)) == 60, "past boundary does not schedule a short wake")

        let snapshot = DevelopmentFixtures.snapshot(at: now)
        let eastPlace = snapshot.location(id: "dev-east")!
        var andFilter = LocationFilter(requiredCategories: [WasteCategory.sampleGlass.id, WasteCategory.samplePaper.id])
        expect(!andFilter.matches(eastPlace, at: now), "AND filter rejects missing paper")
        andFilter.requiredCategories = [WasteCategory.sampleGlass.id, WasteCategory.samplePackaging.id]
        expect(andFilter.matches(eastPlace, at: now), "AND filter accepts glass and packaging")

        let spaceFilter = LocationFilter(requiresSpaceAvailable: true)
        expect(spaceFilter.matches(snapshot.location(id: "dev-north")!, at: now), "fresh below 90 has space")
        expect(!spaceFilter.matches(snapshot.location(id: "dev-south")!, at: now), "90 and above have no space")
        expect(!spaceFilter.matches(snapshot.location(id: "dev-west")!, at: now), "missing readings are not available")

        var glassSpace = LocationFilter(requiredCategories: [WasteCategory.sampleGlass.id], requiresSpaceAvailable: true)
        expect(!glassSpace.matches(eastPlace, at: now), "stale glass reading is not space")
        expect(glassSpace.matches(snapshot.location(id: "dev-north")!, at: now), "fresh glass has space")
        glassSpace.reset()
        expect(!glassSpace.isActive, "reset clears filter")

        let northPlace = snapshot.location(id: "dev-north")!
        expect(northPlace.containers.count == 3 && northPlace.acceptedCategories.count == 3, "containers stay separate")

        let events = [
            CommunityEvent(id: "old-vandalism", ecopontoID: "dev-ridge", issue: .vandalised, kind: .report, serverTimestamp: now.addingTimeInterval(-8 * 24 * 60 * 60)),
            CommunityEvent(id: "new-rubbish", ecopontoID: "dev-ridge", issue: .rubbishOutsideContainers, kind: .report, serverTimestamp: now.addingTimeInterval(-2 * 24 * 60 * 60)),
            CommunityEvent(id: "resolved-rubbish", ecopontoID: "dev-ridge", issue: .rubbishOutsideContainers, kind: .resolution, serverTimestamp: now.addingTimeInterval(-24 * 60 * 60)),
            CommunityEvent(id: "fresh-vandalism", ecopontoID: "dev-ridge", issue: .vandalised, kind: .report, serverTimestamp: now.addingTimeInterval(-3 * 60 * 60)),
        ]
        let visible = CommunityIssuePolicy.visibleIssues(in: events, for: "dev-ridge", at: now)
        expect(visible.map(\.kind) == [.vandalised], "resolution hides rubbish, fresh vandalism remains")
        expect(
            PortugueseRelativeTime.reportedPhrase(kind: .vandalised, from: events[3].serverTimestamp, now: now) == "Vandalizado · reportado há 3 horas",
            "relative time phrase"
        )
        expect(
            CommunityIssuePolicy.visibleIssues(
                in: [
                    CommunityEvent(id: "resolved", ecopontoID: "dev-ridge", issue: .vandalised, kind: .resolution, serverTimestamp: now.addingTimeInterval(-60)),
                    CommunityEvent(id: "older-report", ecopontoID: "dev-ridge", issue: .vandalised, kind: .report, serverTimestamp: now.addingTimeInterval(-120)),
                ],
                for: "dev-ridge",
                at: now
            ).isEmpty,
            "older cached report does not restore resolved issue"
        )

        let destination = Coordinate(latitude: 10.0000, longitude: 10.0000)
        let nearby = LocationFix(coordinate: Coordinate(latitude: 10.0001, longitude: 9.9999), horizontalAccuracy: 10, timestamp: now.addingTimeInterval(-5))
        if case .withinRange = Geodesy.evaluate(destination: destination, fix: nearby, now: now) {
            // ok
        } else {
            expect(false, "nearby fix should be within range")
        }
        let far = LocationFix(coordinate: Coordinate(latitude: 10.0082, longitude: 9.9929), horizontalAccuracy: 10, timestamp: now)
        if case .tooFar = Geodesy.evaluate(destination: destination, fix: far, now: now) {
            // ok
        } else {
            expect(false, "far fix should be rejected")
        }
        expect(Geodesy.evaluate(destination: destination, fix: LocationFix(coordinate: destination, horizontalAccuracy: 10, timestamp: now.addingTimeInterval(-120)), now: now) == .fixTooOld, "stale fix")
        expect(Geodesy.evaluate(destination: destination, fix: LocationFix(coordinate: destination, horizontalAccuracy: 80, timestamp: now), now: now) == .fixTooInaccurate, "inaccurate fix")
        expect(Geodesy.evaluate(destination: destination, fix: nil, now: now) == .noFix, "missing fix")

        let approximate = LocationFix(coordinate: destination, horizontalAccuracy: 3_000, timestamp: now)
        expect(MapLocationPolicy.canDisplay(approximate, at: now), "approximate location is usable for map browsing")
        expect(MapLocationPolicy.widthKilometres(for: approximate) == 6, "approximate map view stays within area query limits")
        expect(!MapLocationPolicy.canDisplay(LocationFix(coordinate: destination, horizontalAccuracy: 10, timestamp: now.addingTimeInterval(1)), at: now), "future browsing fix rejected")
        expect(!MapLocationPolicy.canDisplay(LocationFix(coordinate: destination, horizontalAccuracy: 10, timestamp: now.addingTimeInterval(-86401)), at: now), "old browsing estimate expires")
        expect(Geodesy.evaluate(destination: destination, fix: approximate, now: now) == .fixTooInaccurate, "browsing estimate does not authorize reports")

        let assistant = CatalogSortingAssistant()
        let glass = await assistant.answer("Onde deito uma garrafa de vidro?")
        expect(glass.destination == "Vidro · ecoponto verde", "glass destination")
        expect(glass.mapCategories == [WasteCategory.sampleGlass.id], "glass map filter")
        expect(glass.kind == .curatedCatalog && !glass.isOutOfScope && !glass.sources.isEmpty, "curated glass reply")

        let pizza = await assistant.answer("caixa de pizza")
        expect(pizza.exceptions.contains(where: { $0.contains("gordura") }), "pizza box excludes soiled parts")
        expect(pizza.mapCategories == [WasteCategory.samplePaper.id], "pizza box maps to paper")

        let batteries = await assistant.answer("pilhas")
        expect(batteries.isOutOfScope && batteries.mapCategories.isEmpty, "batteries out of scope")
        expect(batteries.destination.contains("fora do âmbito"), "batteries copy")

        let unknown = await assistant.answer("um objeto estranho que não reconheço")
        expect(unknown.mapCategories.isEmpty && unknown.clarification != nil && !unknown.isOutOfScope, "unknown item is not forced")

        let cup = await assistant.answer("copo partido")
        expect(cup.isOutOfScope && cup.mapCategories.isEmpty, "tableware not forced into glass")

        let invented = AssistantReplySanitizer.makeReply(
            destination: "Embalagens de vidro",
            preparation: [],
            exceptions: [],
            clarification: "",
            proposedCategoryIDs: ["2", "99", "nuclear"],
            citedSourceIDs: ["signage", "invented-source"],
            isOutOfScope: false,
            kind: .model,
            catalog: .development
        )
        expect(invented.mapCategories == [WasteCategory.sampleGlass.id], "unknown category ids are dropped")
        expect(invented.sources.map(\.id) == ["signage"], "invented sources are dropped")

        let forcedHazard = AssistantReplySanitizer.makeReply(
            destination: "Mistura de embalagens",
            preparation: [],
            exceptions: [],
            clarification: nil,
            proposedCategoryIDs: ["4"],
            citedSourceIDs: [],
            isOutOfScope: true,
            kind: .model,
            catalog: .development
        )
        expect(forcedHazard.mapCategories.isEmpty, "out of scope never opens a map filter")
        let catalog = SortingCatalog.development
        expect(Set(catalog.entries.map(\.id)).count == catalog.entries.count, "catalog ids are unique")
        expect(catalog.entries.filter { !$0.isOutOfScope }.allSatisfy { !$0.sources.isEmpty && $0.sources.allSatisfy { $0.reviewedOn != nil } }, "supported guidance has reviewed sources")
        expect(catalog.entries.filter(\.isOutOfScope).allSatisfy { $0.categoryIDs.isEmpty }, "unsupported residues never route to a container")
        expect(catalog.entries.first(where: { $0.id == "oil" })!.matchesSearch("OLEO"), "search ignores accents and case")
        expect(catalog.entries.first(where: { $0.id == "oil-bottle" })!.matchesSearch("garrafa oleo"), "search matches separate words")
        expect(catalog.entries.allSatisfy { !$0.matchesSearch("xyzxyz") }, "unmatched search returns no entries")
        let deposit = await assistant.answer("embalagem com símbolo volta")
        expect(deposit.isOutOfScope && deposit.mapCategories.isEmpty, "deposit packaging is excluded")
        expect(!SortingCatalog.development.entries.isEmpty, "sorting catalog has entries for the guide table")
        expect(SortingCatalog.development.entries.contains { $0.isOutOfScope && $0.sources.isEmpty }, "development fixture keeps unlabeled placeholder rows")
        expect(SortingCatalog.development.allowedCategoryIDs == Set([
            WasteCategory.sampleGlass.id,
            WasteCategory.samplePaper.id,
            WasteCategory.samplePackaging.id,
        ]), "guide only exposes supported ecoponto streams")
        expect(!SortingCatalog.development.modelBriefing.isEmpty, "model briefing remains available for catalog tooling")

        let production = SortingCatalog.production
        let ecopontoStreams: Set<WasteCategory.ID> = [
            WasteCategory.sampleGlass.id,
            WasteCategory.samplePaper.id,
            WasteCategory.samplePackaging.id,
        ]
        expect(production.version != SortingCatalog.development.version, "production catalog is not the development fixture")
        expect(Set(production.entries.map(\.id)).count == production.entries.count, "production ids are unique")
        expect(production.entries.allSatisfy { entry in
            !entry.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !entry.sources.isEmpty
                && entry.sources.allSatisfy { $0.reviewedOn != nil && $0.url.scheme == "https" }
        }, "every production entry cites a reviewed https source")
        expect(production.entries.allSatisfy { $0.categoryIDs.isSubset(of: ecopontoStreams) }, "production map categories stay within ecoponto streams")
        expect(production.entries.filter(\.isOutOfScope).allSatisfy { $0.categoryIDs.isEmpty }, "production out of scope never opens the map")
        expect(production.allowedCategoryIDs == ecopontoStreams, "production map filters stay on the three ecoponto streams")
        let allowedHosts: Set<String> = [
            "www.pontoverde.pt", "www.lipor.pt", "apambiente.pt", "sdrportugal.pt", "valormed.pt", "electrao.pt",
        ]
        let citedHosts = Set(production.entries.flatMap(\.sources).compactMap(\.url.host))
        expect(citedHosts.isSubset(of: allowedHosts) && citedHosts == Set(production.sources.compactMap(\.url.host)), "production sources stay on cited publishers")
        expect(production.entries.first { $0.id == "glass-bottle" }?.destination == "Ecoponto verde", "glass bottle bin")
        expect(production.entries.first { $0.id == "glass-bottle" }?.categoryIDs == [WasteCategory.sampleGlass.id], "glass bottle map filter")
        expect(production.entries.first { $0.id == "cooking-oil" }?.matchesSearch("OLEO") == true, "production oil search")
        expect(production.entries.first { $0.id == "cooking-oil" }?.categoryIDs.isEmpty == true, "cooking oil is not an ecoponto stream")
        expect(production.entries.first { $0.id == "batteries" }?.destination.contains("pilhas") == true, "batteries name the pilhas container")
        expect(production.entries.first { $0.id == "volta" }?.categoryIDs.isEmpty == true, "volta does not open the yellow filter")
        expect(production.entries.first { $0.id == "medicine" }?.categoryIDs.isEmpty == true, "medicine packaging is not forced into glass")
        expect(production.entries.first { $0.id == "drinking-glass" }?.categoryIDs.isEmpty == true, "drinking glasses are not glass packaging")

        let ecopontoBinDestinations: Set<String> = ["Ecoponto verde", "Ecoponto azul", "Ecoponto amarelo"]
        func showsEcopontoBin(_ entry: SortingEntry) -> Bool {
            !entry.categoryIDs.isEmpty || ecopontoBinDestinations.contains(entry.destination)
        }
        expect(production.entries.filter(showsEcopontoBin).allSatisfy { entry in
            !entry.sources.isEmpty
                && entry.sources.allSatisfy { $0.reviewedOn != nil && $0.url.scheme == "https" }
        }, "every production entry with a bin cites a reviewed source")

        func catalogText(_ entry: SortingEntry) -> String {
            ([entry.canonicalName] + entry.aliases + [entry.destination])
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_PT"))
        }
        func isHazardousCatalogItem(_ entry: SortingEntry) -> Bool {
            let text = catalogText(entry)
            if text.contains("isqueiro") || text.contains("agulha") || text.contains("led") { return true }
            if text.contains("corto-perfurante") || text.contains("corto perfurante") { return true }
            return text.contains("seringa") && !text.contains("doseadora")
        }
        let hazardous = production.entries.filter(isHazardousCatalogItem)
        expect(hazardous.contains { $0.id == "sharps" }, "needles stay in the production catalog")
        expect(hazardous.contains { $0.id == "lighter" }, "lighters stay in the production catalog")
        expect(hazardous.contains { $0.id == "led-lamp" }, "LED lamps stay in the production catalog")
        expect(hazardous.allSatisfy { entry in
            entry.categoryIDs.isEmpty
                && !showsEcopontoBin(entry)
                && !entry.destination.localizedCaseInsensitiveContains("ecoponto")
        }, "hazardous items never map to an ecoponto bin")
        let sharpsDestination = production.entries.first { $0.id == "sharps" }?.destination.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "pt_PT")
        )
        expect(sharpsDestination?.contains("farmacia") == false, "needles are not sent to a pharmacy")

        let paperCup = production.entries.first { $0.id == "paper-cup" }
        expect(paperCup?.destination == "As regras variam: confirma com o teu município", "paper cups name no bin")
        expect(paperCup?.categoryIDs.isEmpty == true && paperCup.map(showsEcopontoBin) == false, "paper cups do not open an ecoponto")
        expect(paperCup?.sources.isEmpty == false, "paper cups still cite the conflicting pages")

        let rollOn = production.entries.first { $0.id == "deodorant-glass" }
        expect(rollOn?.destination == "Ecoponto verde" && rollOn?.categoryIDs == [WasteCategory.sampleGlass.id], "glass roll-on goes to the green bin")
        expect(rollOn?.sources.map(\.id) == ["spv-passo"], "glass roll-on cites only the 2025 Ponto Verde article")

        let liporLabel = "Regra LIPOR (Grande Porto) — pode variar no teu município"
        for id in ["thermal-receipt", "egg-box", "cooking-oil"] {
            expect(
                production.entries.first { $0.id == id }?.clarification?.contains(liporLabel) == true,
                "\(id) carries the LIPOR scope label"
            )
        }
        expect(production.entries.contains { entry in
            catalogText(entry).contains("cimento")
        } == false, "cement sacks stay out of the production catalog")
        let guide = CatalogSortingAssistant(catalog: .production)
        let producedGlass = await guide.answer("garrafa de vidro")
        expect(
            producedGlass.destination == "Ecoponto verde"
                && producedGlass.mapCategories == [WasteCategory.sampleGlass.id]
                && !producedGlass.sources.isEmpty,
            "production glass reply"
        )
        let producedBatteries = await guide.answer("pilhas")
        expect(
            !producedBatteries.isOutOfScope
                && producedBatteries.mapCategories.isEmpty
                && producedBatteries.destination.contains("pilhas"),
            "production batteries stay off the map"
        )
        let producedVolta = await guide.answer("embalagem com símbolo volta")
        expect(producedVolta.destination == "Ponto volta" && producedVolta.mapCategories.isEmpty, "production volta destination")

        let favourites = FavouritesStore(persistence: InMemoryFavouritesStore())
        await favourites.add("dev-ridge", at: now)
        await favourites.add("missing-from-api", at: now)
        let hasReal = await favourites.contains("dev-ridge")
        let hasMissing = await favourites.contains("missing-from-api")
        expect(hasReal && hasMissing, "favourites survive independently")

        let reportClient = MockReciclarClient(clock: { now })
        let reportRepo = AreaRepository(client: reportClient, store: InMemorySnapshotStore())
        let request = IssueSubmissionRequest(ecopontoID: "dev-north", issue: .vandalised)
        _ = try? await reportRepo.submitReport(request)
        let reported = CommunityIssuePolicy.visibleIssues(
            in: await reportRepo.currentSnapshot().communityEvents,
            for: "dev-north",
            at: now
        )
        expect(reported.map(\.kind) == [.vandalised], "confirmed report merged immediately")

        let failClient = MockReciclarClient(clock: { now })
        await failClient.setFailNextSubmit(true)
        let failRepo = AreaRepository(client: failClient, store: InMemorySnapshotStore())
        do {
            _ = try await failRepo.submitReport(request)
            expect(false, "failed submit should throw")
        } catch {
            expect((error as? ReciclarAPIError) == .unavailable, "failed submit error")
        }
        let failedVisible = CommunityIssuePolicy.visibleIssues(
            in: await failRepo.currentSnapshot().communityEvents,
            for: "dev-north",
            at: now
        )
        expect(failedVisible.isEmpty, "failed submit does not appear")

        expect(RecyclingStream.classifying(name: "Embalagens de Vidro") == .glass, "glass stream")
        expect(RecyclingStream.classifying(name: "Embalagens de papel e cartão") == .paper, "paper stream")
        expect(RecyclingStream.classifying(name: "Mistura de embalagens - 150106") == .packaging, "packaging stream")
        expect(RecyclingStream.classifying(name: "RSU") == nil, "unknown stream stays unnamed")

        let liveGlass = Ecoponto(
            id: "glass-16",
            coordinate: Coordinate(latitude: 41.55, longitude: -8.42),
            containers: [
                Container(id: "c16", category: WasteCategory(id: WasteCategory.ID("16"), name: "Embalagens de Vidro")),
            ],
            provenance: .developmentFixture
        )
        let streamFilter = LocationFilter(requiredTokens: [.stream(.glass)])
        expect(streamFilter.matches(liveGlass, at: now), "glass token matches sibling waste-type id")
        expect(streamFilter.matches(eastPlace, at: now), "fixture glass name matches stream token")

        let chips = WasteFilterChip.chips(from: [liveGlass, eastPlace])
        expect(chips.contains { $0.token == .stream(.glass) && $0.categoryIDs.contains(WasteCategory.ID("16")) }, "chips merge glass ids")

        do {
            let page = try decodeAPILocationPage(from: FixtureResource.sampleAPILocationsPageJSON())
            expect(page.locations.count == 2, "invalid coordinates dropped")
            expect(page.removedIDs == ["gone-1"], "removed ids decoded")
            expect(page.hasMore && page.nextCursor != nil, "cursor preserved")
            expect(page.syncToken == "2026-09-07T13:43:03.818Z", "sync token")
            expect(!page.isFixtureData, "live page is not fixture")
            expect(page.locations[0].containers[0].fillReading?.percentFull == 25, "fill percent")
            expect(page.locations[0].containers[1].fillReading?.percentFull == 0, "zero fill is not treated as missing")
            expect(page.locations[1].address == nil, "n/a address omitted")
            expect(page.communityEvents.first?.issue == .vandalised, "wire alias vandalized")
            expect(CommunityIssueKind(wireValue: "litter_outside_containers") == .rubbishOutsideContainers, "litter wire")
        } catch {
            failures += 1
            FileHandle.standardError.write(Data("FAIL api page \(error)\n".utf8))
        }

        let dense = (0..<40).map { index in
            Ecoponto(
                id: "p-\(index)",
                coordinate: Coordinate(latitude: 41.5 + Double(index) * 0.05, longitude: -8.4),
                containers: [Container(id: "c-\(index)", category: WasteCategory.sampleGlass)],
                provenance: .developmentFixture
            )
        }
        let wide = MapPresentationPolicy.items(
            from: dense,
            in: GeographicBounds(center: Coordinate(latitude: 42.0, longitude: -8.4), latitudeDelta: 3, longitudeDelta: 1),
            latitudeSpan: 3,
            filter: LocationFilter(),
            now: now
        )
        expect(wide.contains { if case .cluster = $0 { true } else { false } }, "wide zoom clusters")
        let tightBounds = GeographicBounds(
            center: Coordinate(latitude: 41.5, longitude: -8.4),
            latitudeDelta: 0.04,
            longitudeDelta: 0.04
        )
        let tight = MapPresentationPolicy.items(
            from: dense,
            in: tightBounds,
            latitudeSpan: 0.04,
            filter: LocationFilter(),
            now: now
        )
        expect(tight.allSatisfy { if case .pin = $0 { true } else { false } }, "close zoom shows pins")

        var index = SpatialIndex(locations: dense)
        expect(index.location(id: "p-0")?.coordinate.latitude == 41.5, "spatial index lookup")
        let nearbyPins = index.locations(
            in: GeographicBounds(center: Coordinate(latitude: 41.5, longitude: -8.4), latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        expect(nearbyPins.contains { $0.id == "p-0" }, "spatial query includes nearby pin")
        expect(!nearbyPins.contains { $0.id == "p-39" }, "spatial query excludes distant pin")
        index.rebuild([])
        expect(index.location(id: "p-0") == nil, "rebuild clears index")

        let andStreams = LocationFilter(requiredTokens: [.stream(.glass), .stream(.paper)])
        expect(!andStreams.matches(eastPlace, at: now), "AND streams reject missing paper")
        expect(andStreams.matches(snapshot.location(id: "dev-north")!, at: now), "AND streams accept glass and paper")

        var glassSpaceToken = LocationFilter(requiredTokens: [.stream(.glass)], requiresSpaceAvailable: true)
        expect(!glassSpaceToken.matches(eastPlace, at: now), "stale glass is not space for stream token")
        expect(glassSpaceToken.matches(snapshot.location(id: "dev-north")!, at: now), "fresh glass has space for stream token")
        glassSpaceToken.reset()
        expect(!glassSpaceToken.isActive, "reset clears stream tokens")

        let listed = MapPresentationPolicy.listLocations(
            from: dense,
            in: GeographicBounds(center: Coordinate(latitude: 41.5, longitude: -8.4), latitudeDelta: 1.2, longitudeDelta: 0.3),
            filter: LocationFilter(),
            now: now,
            limit: 5
        )
        expect(listed.count == 5, "list locations honour limit")

        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("ecopontos-cache-\(UUID().uuidString)", isDirectory: true)
        let disk = DiskSnapshotStore(directory: cacheDir)
        let persisted = LocationSnapshot(
            locations: [liveGlass],
            communityEvents: [
                CommunityEvent(id: "evt-1", ecopontoID: liveGlass.id, issue: .vandalised, kind: .report, serverTimestamp: now)
            ],
            lastSuccessfulSync: now,
            isFixtureData: false,
            syncToken: "2026-09-07T13:43:03Z",
            removedLocationIDs: ["gone-1"],
            coverageNote: "Cobertura limitada aos dados públicos de pontos de recolha. Não é cobertura nacional."
        )
        do {
            try await disk.save(persisted)
            let loaded = try await disk.load()
            expect(loaded?.syncToken == "2026-09-07T13:43:03Z", "disk keeps sync token")
            expect(loaded?.removedLocationIDs.contains("gone-1") == true, "disk keeps removed ids")
            expect(loaded?.coverageNote?.contains("dados públicos") == true, "disk keeps coverage note")
            expect(loaded?.isFixtureData == false, "disk keeps fixture flag")
            var opaque = liveGlass
            opaque.id = "rc_0123456789abcdef0123"
            var next = persisted
            next.locations = [opaque]
            next.communityEvents = [
                CommunityEvent(id: "evt-opaque", ecopontoID: opaque.id, issue: .vandalised, kind: .report, serverTimestamp: now)
            ]
            try await disk.save(next)
            let reloaded = try await disk.load()
            expect(reloaded?.locations.first?.id == opaque.id, "opaque location id survives relaunch")
            expect(reloaded?.communityEvents.first?.ecopontoID == opaque.id, "opaque event id survives relaunch")
            expect(reloaded?.syncToken == next.syncToken, "opaque cache keeps the sync token")
        } catch {
            failures += 1
            FileHandle.standardError.write(Data("FAIL disk cache \(error)\n".utf8))
        }
        try? FileManager.default.removeItem(at: cacheDir)

        let favClient = MockReciclarClient(clock: { now })
        await favClient.setGoneIDs(["ghost"])
        await favClient.setExtraLocations([
            "extra-fav": Ecoponto(
                id: "extra-fav",
                coordinate: Coordinate(latitude: 41.2, longitude: -8.5),
                containers: [Container(id: "xf", category: WasteCategory.samplePaper)],
                provenance: .developmentFixture
            )
        ])
        let favRepo = AreaRepository(client: favClient, store: InMemorySnapshotStore())
        await favRepo.refreshFavourite(id: "ghost", now: now)
        expect(await favRepo.currentSnapshot().removedLocationIDs.contains("ghost"), "gone favourite is marked removed")
        await favRepo.refreshFavourite(id: "extra-fav", now: now)
        expect(await favRepo.currentSnapshot().location(id: "extra-fav") != nil, "missing favourite is fetched")

        do {
            let detailJSON = """
            {"location":{"id":"42","latitude":41.1,"longitude":-8.6,"address":"n/a","provenance":{"label":"Catálogo / Operador Beta"},"updated_at":"2026-09-07T13:37:18.073Z","containers":[{"id":"c","waste_type_id":"3","waste_name":"Embalagens de Vidro","color_token":"#339933","volume_litres":2500.0}],"active_issues":[]},"community_events":[{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","ecoponto_id":"42","issue":"litter_outside_containers","kind":"report","server_timestamp":"2026-09-07T12:00:00.000Z"}]}
            """.data(using: .utf8)!
            let detail = try decodeAPILocationDetail(from: detailJSON)
            expect(detail.location.id == "42", "detail id")
            expect(detail.location.address == nil, "detail n/a address omitted")
            expect(detail.location.provenance.label == "Operador Beta", "provenance keeps the operator name")
            expect(detail.location.containers[0].volumeLitres == 2500, "volume from number")
            expect(detail.communityEvents.first?.issue == .rubbishOutsideContainers, "litter alias")
        } catch {
            failures += 1
            FileHandle.standardError.write(Data("FAIL api detail \(error)\n".utf8))
        }

        do {
            let statsJSON = """
            {"as_of":"2026-09-08T12:00:00.000Z","sync_token":"2026-09-08T12:00:00.000Z","is_fixture_data":false,"coverage_note":"Cobertura limitada aos dados públicos de pontos de recolha. Não é cobertura nacional.","fill_note":"O espaço disponível e as leituras com menos de 24 horas referem-se à data da última sincronização.","fill_evaluated_at":"2026-09-08T12:00:00.000Z","geography":{"country":"PT","area_km2":92227,"road_km":71294},"density":{"locations_per_100_road_km":17.5,"locations_per_km2":0.14,"with_space_per_100_road_km":13.83,"with_space_per_km2":0.11},"locations":{"total":12480,"districts":15,"municipalities":181,"operators":11,"with_space_available":9860,"with_usable_reading":10200,"with_space_percent":79},"containers":{"total":28640,"with_usable_reading":18205,"with_usable_reading_percent":64,"with_space_available":16400,"by_stream":[{"id":"glass","name":"Embalagens de vidro","count":9120},{"id":"paper","name":"Papel e cartão","count":9410},{"id":"packaging","name":"Mistura de embalagens","count":10110}]},"districts":[{"name":"Distrito A","location_count":2100,"container_count":4800}],"community":{"locations_with_visible_issues":2,"visible_issues":{"litter_outside_containers":1,"vandalized":1}}}
            """.data(using: .utf8)!
            let stats = try decodeAPIStats(from: statsJSON)
            expect(stats.locations.total == 12_480, "stats location total")
            expect(stats.locations.withSpaceAvailable == 9_860, "stats space available")
            expect(stats.containers?.byStream.first?.id == "glass", "stats glass stream")
            expect(stats.districts.first?.name == "Distrito A", "stats district")
            expect(stats.community?.vandalized == 1, "stats community")
            expect(stats.coverageNote.contains("dados públicos") == true, "stats coverage note")
            expect(!stats.isFixtureData, "live stats are not fixtures")
            expect(PortuguesePlaceName.district("VIANA DO CASTELO") == "Viana do Castelo", "district title case")
            expect(PortuguesePlaceName.district("SETÚBAL") == "Setúbal", "district accent kept")
        } catch {
            failures += 1
            FileHandle.standardError.write(Data("FAIL api stats \(error)\n".utf8))
        }

        do {
            let liveFallbackJSON = """
            {"as_of":"2026-09-07T13:43:03.818Z","sync_token":"2026-09-07T13:43:03.818Z","is_fixture_data":false,"coverage_note":"Cobertura limitada aos dados públicos de pontos de recolha. Não é cobertura nacional.","geography":{"country":"PT","area_km2":92227,"road_km":71294},"density":{"locations_per_100_road_km":21.19,"locations_per_km2":0.16},"locations":{"total":4,"districts":1,"municipalities":1,"operators":0},"districts":[{"name":"Distrito A","location_count":4,"container_count":0}],"community":{"locations_with_visible_issues":0,"visible_issues":{"litter_outside_containers":0,"vandalized":0}}}
            """.data(using: .utf8)!
            let live = try decodeAPIStats(from: liveFallbackJSON)
            expect(live.locations.total == 4, "fill-free stats total")
            expect(live.containers == nil, "fill-free stats omit containers")
            expect(live.locations.operators == 0, "operators may be zero before a full stats publish")
            expect(live.asOf != nil, "fractional as_of decodes")
        } catch {
            failures += 1
            FileHandle.standardError.write(Data("FAIL live fallback stats \(error)\n".utf8))
        }

        let statsDir = FileManager.default.temporaryDirectory.appendingPathComponent("ecopontos-stats-\(UUID().uuidString)", isDirectory: true)
        let statsStore = DiskStatsStore(directory: statsDir)
        do {
            let cached = CachedCatalogStatistics(statistics: DevelopmentFixtures.statistics(at: now), fetchedAt: now)
            try await statsStore.save(cached)
            let loaded = try await statsStore.load()
            expect(loaded?.statistics.locations.total == 12_480, "disk keeps stats totals")
            expect(loaded?.statistics.isFixtureData == true, "disk keeps fixture flag")
        } catch {
            failures += 1
            FileHandle.standardError.write(Data("FAIL stats cache \(error)\n".utf8))
        }
        try? FileManager.default.removeItem(at: statsDir)

        let statsClient = MockReciclarClient(clock: { now })
        let statsRepo = StatsRepository(
            client: statsClient,
            store: InMemoryStatsStore(),
            policy: SyncPolicy(interval: 15 * 60, maxAttempts: 1, baseDelayNanoseconds: 0)
        )
        await statsRepo.refresh(now: now)
        expect(await statsRepo.current()?.locations.total == 12_480, "stats repository loads mock aggregates")
        expect(await statsRepo.current()?.isFixtureData == true, "mock stats stay labeled as fixtures")
        await statsRepo.refreshIfNeeded(now: now.addingTimeInterval(60))
        expect(await statsRepo.current()?.locations.total == 12_480, "fresh stats are not refetched inside the interval")

        await runHTTPClientChecks(
            expect: { condition, message in expect(condition, message) },
            failures: &failures
        )
        runLegacyInstallationChecks(expect: { condition, message in expect(condition, message) })

        let oldCache = """
        {"locations":[],"communityEvents":[],"isFixtureData":false}
        """.data(using: .utf8)!
        do {
            let decoded = try JSONDecoder().decode(LocationSnapshot.self, from: oldCache)
            expect(decoded.syncToken == nil && decoded.removedLocationIDs.isEmpty, "old cache decodes without new keys")
        } catch {
            failures += 1
            FileHandle.standardError.write(Data("FAIL old cache \(error)\n".utf8))
        }

        if failures > 0 {
            FileHandle.standardError.write(Data("\(failures) checks failed\n".utf8))
            exit(1)
        }
        print("ReciclarCoreChecks passed")
    }
}

extension MockReciclarClient {
    func setFailNextFetch(_ value: Bool) { failNextFetch = value }
    func setFailNextSubmit(_ value: Bool) { failNextSubmit = value }
    func setPages(_ value: [LocationSyncPage]?) { pages = value }
    func setGoneIDs(_ value: Set<String>) { goneIDs = value }
    func setExtraLocations(_ value: [String: Ecoponto]) { extraLocations = value }
    func setNextError(_ value: ReciclarAPIError?) { nextError = value }
    func setScriptedEvents(_ value: [CommunityEvent]) { scriptedEvents = value }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var responseHeaders: [String: String] = [:]
    nonisolated(unsafe) static var lastURL: String = ""
    nonisolated(unsafe) static var lastBody = Data()
    nonisolated(unsafe) static var lastHeaders: [String: String] = [:]
    nonisolated(unsafe) static var lastCachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let current = StubURLProtocol.lock.withLock { StubURLProtocol.handler }
        guard let current, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let body = requestHTTPBody(request)
        StubURLProtocol.lock.withLock {
            StubURLProtocol.lastURL = url.absoluteString
            StubURLProtocol.lastBody = body
            StubURLProtocol.lastHeaders = request.allHTTPHeaderFields ?? [:]
            StubURLProtocol.lastCachePolicy = request.cachePolicy
        }
        let (status, data) = current(request)
        var headers = ["Content-Type": "application/json"]
        let extras = StubURLProtocol.lock.withLock { StubURLProtocol.responseHeaders }
        for (key, value) in extras { headers[key] = value }
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

func requestHTTPBody(_ request: URLRequest) -> Data {
    if let body = request.httpBody, !body.isEmpty {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return Data()
    }
    if stream.streamStatus == .notOpen {
        stream.open()
    }
    var collected = Data()
    let bufferSize = 1_024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while true {
        let count = stream.read(buffer, maxLength: bufferSize)
        if count <= 0 {
            break
        }
        collected.append(buffer, count: count)
    }
    return collected
}

func stubSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
}

@MainActor
func runHTTPClientChecks(
    expect: (Bool, String) -> Void,
    failures: inout Int
) async {
    expect(ReciclarAppVersion.headerValue(marketing: "1.1.0", build: "6") == "1.1.0 (6)", "version header is marketing version and build")
    expect(ReciclarAppVersion.headerField == "X-Reciclar-Version", "version header name")
    let versionDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("reciclar-version-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: versionDirectory) }
    do {
        try FileManager.default.createDirectory(at: versionDirectory, withIntermediateDirectories: true)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleShortVersionString</key><string>1.1.0</string>
        <key>CFBundleVersion</key><string>6</string>
        </dict></plist>
        """
        try plist.write(to: versionDirectory.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        let bundle = Bundle(url: versionDirectory)
        expect(bundle.flatMap(ReciclarAppVersion.headerValue(in:)) == "1.1.0 (6)", "version header comes from the bundle")
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL version bundle \(error)\n".utf8))
    }

    let client = HTTPReciclarClient(
        configuration: ReciclarAPIConfiguration(
            baseURL: ReciclarAPIConfiguration.productionBaseURL,
            session: stubSession()
        ),
        versionHeader: "1.1.0 (6)"
    )

    let areaBounds = GeographicBounds(minLatitude: 40.5, maxLatitude: 40.6, minLongitude: -8.5, maxLongitude: -8.4)
    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.handler = { _ in
                var payload = (try? FixtureResource.sampleAPILocationsPageJSON()) ?? Data("{}".utf8)
                if var text = String(data: payload, encoding: .utf8), let range = text.range(of: "{") {
                    text.replaceSubrange(range, with: #"{"scope":{"kind":"area","bbox":[-8.5,40.5,-8.4,40.6]},"#)
                    let invalidRow = """
                        {
                          "id": "bad",
                          "latitude": 200,
                          "longitude": -8.4,
                          "provenance": { "label": "Operador" },
                          "updated_at": "2026-09-07T13:37:18.073Z",
                          "containers": [],
                          "active_issues": []
                        },
                    """
                    text = text.replacingOccurrences(of: invalidRow, with: "")
                    payload = Data(text.utf8)
                }
                return (200, payload)
            }
        }
        let area = try await client.fetchArea(bounds: areaBounds, cursor: "page-2")
        let urlString = StubURLProtocol.lock.withLock { StubURLProtocol.lastURL }
        expect(area.page.locations.count == 2, "http area decodes stub page")
        expect(area.page.removedIDs == ["gone-1"], "http area keeps removed ids")
        expect(urlString.contains("bbox="), "area request sends bbox")
        expect(urlString.contains("cursor="), "area request sends cursor")
        let headers = StubURLProtocol.lock.withLock { StubURLProtocol.lastHeaders }
        expect(headers["X-Reciclar-Version"] == "1.1.0 (6)", "request sends the bundle version header")
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http area \(error)\n".utf8))
    }

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.handler = { _ in
                (
                    400,
                    Data(#"{"error":"invalid_sync_token","message":"O token de sincronização expirou. Peça um snapshot completo."}"#.utf8)
                )
            }
        }
        _ = try await client.fetchArea(bounds: areaBounds, cursor: nil)
        expect(false, "invalid token should throw")
    } catch let error as ReciclarAPIError {
        expect(error == .invalidSyncToken, "maps invalid_sync_token")
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http invalid token \(error)\n".utf8))
    }

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.handler = { _ in
                (410, Data(#"{"error":"gone","message":"Este ecoponto já não consta da fonte."}"#.utf8))
            }
        }
        _ = try await client.fetchLocation(id: "1")
        expect(false, "gone location should throw")
    } catch let error as ReciclarAPIError {
        expect(error == .gone, "maps gone")
        expect(error.userMessage == "Este ecoponto já não consta da fonte.", "gone copy")
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http gone \(error)\n".utf8))
    }

    let request = IssueSubmissionRequest(ecopontoID: "1", issue: .rubbishOutsideContainers)

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.handler = { _ in
                (
                    403,
                    Data(#"{"error":"proximity","message":"É preciso estar junto ao ecoponto para reportar ou resolver um problema."}"#.utf8)
                )
            }
        }
        _ = try await client.submitReport(request)
        expect(false, "proximity should throw")
    } catch let error as ReciclarAPIError {
        if case .proximity(let message) = error {
            expect(message.contains("junto"), "proximity uses server message")
        } else {
            expect(false, "expected proximity error")
        }
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http proximity \(error)\n".utf8))
    }

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.handler = { _ in
                (
                    201,
                    Data(#"{"id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","ecoponto_id":"1","issue":"litter_outside_containers","kind":"report","server_timestamp":"2026-09-07T12:00:00.000Z"}"#.utf8)
                )
            }
        }
        let event = try await client.submitReport(request)
        let urlString = StubURLProtocol.lock.withLock { StubURLProtocol.lastURL }
        let json = StubURLProtocol.lock.withLock { String(data: StubURLProtocol.lastBody, encoding: .utf8) ?? "" }
        let headers = StubURLProtocol.lock.withLock { StubURLProtocol.lastHeaders }
        expect(event.issue == .rubbishOutsideContainers, "report event mapped")
        expect(urlString.contains("/v1/locations/1/reports"), "report path")
        expect(json.contains("litter_outside_containers"), "report uses canonical issue")
        expect(!json.contains("rubbishOutsideContainers"), "report does not send swift raw value")
        expectUnlinkedSubmission(
            json: json,
            headers: headers,
            ecopontoID: "1",
            issue: "litter_outside_containers",
            kind: "report",
            label: "report",
            expect: expect
        )
        _ = try await client.submitReport(request)
        let second = StubURLProtocol.lock.withLock { String(data: StubURLProtocol.lastBody, encoding: .utf8) ?? "" }
        let secondHeaders = StubURLProtocol.lock.withLock { StubURLProtocol.lastHeaders }
        expect(
            submissionFields(second) == submissionFields(json),
            "a second report does not attach a stored or fresh installation id"
        )
        expectUnlinkedSubmission(
            json: second,
            headers: secondHeaders,
            ecopontoID: "1",
            issue: "litter_outside_containers",
            kind: "report",
            label: "repeated report",
            expect: expect
        )
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http report \(error)\n".utf8))
    }

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.handler = { _ in
                (
                    200,
                    Data(#"{"as_of":"2026-09-08T12:00:00.000Z","sync_token":"2026-09-08T12:00:00.000Z","is_fixture_data":false,"coverage_note":"Cobertura limitada.","geography":{"country":"PT","area_km2":92227,"road_km":71294},"density":{"locations_per_100_road_km":0.14,"locations_per_km2":0.01},"locations":{"total":4,"districts":1,"municipalities":1,"operators":1},"districts":[{"name":"Distrito A","location_count":4,"container_count":8}],"community":{"locations_with_visible_issues":0,"visible_issues":{"litter_outside_containers":0,"vandalized":0}}}"#.utf8)
                )
            }
        }
        let stats = try await client.fetchStats()
        let urlString = StubURLProtocol.lock.withLock { StubURLProtocol.lastURL }
        expect(stats.locations.total == 4, "http stats total")
        expect(stats.districts.first?.name == "Distrito A", "http stats district")
        expect(urlString.contains("/v1/stats"), "stats path")
        expect(stats.containers == nil, "fill stats may be omitted")
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http stats \(error)\n".utf8))
    }

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.responseHeaders = [:]
            StubURLProtocol.handler = { _ in
                (429, Data(#"{"error":"rate_limited","message":"Demasiados reportes neste momento. Tente mais tarde."}"#.utf8))
            }
        }
        _ = try await client.submitResolution(
            IssueResolutionRequest(ecopontoID: "1", issue: .vandalised)
        )
        expect(false, "rate limit should throw")
    } catch let error as ReciclarAPIError {
        if case .rateLimited(let message, let retry) = error {
            expect(message == IssueReportPolicy.rateLimitMessage, "resolve 429 uses the pt-PT rate-limit copy")
            expect(error.userMessage == IssueReportPolicy.rateLimitMessage, "resolve 429 is shown to the user")
            expect(retry == nil, "resolve 429 without Retry-After has no delay")
        } else {
            expect(false, "expected rate limited")
        }
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http 429 \(error)\n".utf8))
    }

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.responseHeaders = ["Retry-After": "30"]
            StubURLProtocol.handler = { _ in (429, Data()) }
        }
        _ = try await client.submitReport(request)
        expect(false, "empty 429 should throw")
    } catch let error as ReciclarAPIError {
        if case .rateLimited(let message, let retry) = error {
            expect(message == "Fizeste muitos reportes. Tenta mais tarde.", "report 429 uses the fixed pt-PT message")
            expect(error.userMessage == message, "report 429 is not silent")
            expect(retry == 30, "report 429 honours Retry-After")
        } else {
            expect(false, "empty 429 is rateLimited")
        }
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http report 429 \(error)\n".utf8))
    }

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.handler = { _ in
                (
                    201,
                    Data(#"{"id":"cccccccc-cccc-cccc-cccc-cccccccccccc","ecoponto_id":"1","issue":"vandalized","kind":"resolution","server_timestamp":"2026-09-07T12:00:00.000Z"}"#.utf8)
                )
            }
        }
        _ = try await client.submitResolution(IssueResolutionRequest(ecopontoID: "1", issue: .vandalised))
        let json = StubURLProtocol.lock.withLock { String(data: StubURLProtocol.lastBody, encoding: .utf8) ?? "" }
        let headers = StubURLProtocol.lock.withLock { StubURLProtocol.lastHeaders }
        let urlString = StubURLProtocol.lock.withLock { StubURLProtocol.lastURL }
        expect(urlString.contains("/reports/vandalized/resolve"), "resolve path carries the category")
        expectUnlinkedSubmission(
            json: json,
            headers: headers,
            ecopontoID: "1",
            issue: "vandalized",
            kind: "resolution",
            label: "resolve",
            expect: expect
        )
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http resolve body \(error)\n".utf8))
    }

    let tileBody = """
    {"sync_token":"tok","tile":{"z":11,"x":972,"y":784},"bbox":[-9.140625,38.685509760012,-8.96484375,38.82259097617711],"locations":[{"id":"syn-tile","latitude":38.7223,"longitude":-9.1393,"provenance":{"label":"Operador Alfa"},"containers":[]}],"next_cursor":null,"has_more":false}
    """.data(using: .utf8)!
    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.responseHeaders = ["ETag": "\"tile\"", "Cache-Control": "public, max-age=300, stale-while-revalidate=3600"]
            StubURLProtocol.handler = { _ in (200, tileBody) }
        }
        let tile = try await client.fetchTile(SlippyTileCoordinate(z: 11, x: 972, y: 784), cursor: nil)
        let urlString = StubURLProtocol.lock.withLock { StubURLProtocol.lastURL }
        let policy = StubURLProtocol.lock.withLock { StubURLProtocol.lastCachePolicy }
        expect(tile.page.locations.map(\.id) == ["syn-tile"], "tile decodes locations")
        expect(tile.page.communityEvents.isEmpty, "tile carries no events")
        expect(urlString.contains("/v1/tiles/11/972/784"), "tile path")
        expect(!urlString.contains("bbox="), "tile request is not a bbox query")
        expect(policy == .useProtocolCachePolicy, "tile uses the protocol cache")
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http tile \(error)\n".utf8))
    }

    do {
        #if os(Linux)
        let cache = URLCache(memoryCapacity: 2 * 1024 * 1024, diskCapacity: 0, diskPath: nil)
        #else
        let cache = URLCache(memoryCapacity: 2 * 1024 * 1024, diskCapacity: 0)
        #endif
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.urlCache = cache
        let cachedClient = HTTPReciclarClient(
            configuration: ReciclarAPIConfiguration(baseURL: ReciclarAPIConfiguration.productionBaseURL, session: URLSession(configuration: configuration))
        )
        let url = URL(string: "https://ecopontos-api.rgllm.workers.dev/v1/stats")!
        let stored = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Type": "application/json",
            "ETag": "\"stats\""
        ])!
        let statsBody = Data(#"{"as_of":"2026-09-08T12:00:00.000Z","sync_token":"2026-09-08T12:00:00.000Z","is_fixture_data":false,"coverage_note":"Cobertura limitada.","geography":{"country":"PT","area_km2":92227,"road_km":71294},"density":{"locations_per_100_road_km":0.14,"locations_per_km2":0.01},"locations":{"total":9,"districts":1,"municipalities":1,"operators":1},"districts":[],"community":{"locations_with_visible_issues":0}}"#.utf8)
        cache.storeCachedResponse(CachedURLResponse(response: stored, data: statsBody), for: URLRequest(url: url))
        StubURLProtocol.lock.withLock {
            StubURLProtocol.responseHeaders = ["ETag": "\"stats\""]
            StubURLProtocol.handler = { _ in (304, Data()) }
        }
        let stats = try await cachedClient.fetchStats()
        expect(stats.locations.total == 9, "304 reuses the cached stats body")
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http 304 \(error)\n".utf8))
    }

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.responseHeaders = ["Retry-After": "120"]
            StubURLProtocol.handler = { _ in
                (429, Data(#"{"error":"rate_limited","message":"Demasiados pedidos. Tente mais tarde."}"#.utf8))
            }
        }
        _ = try await client.fetchTile(SlippyTileCoordinate(z: 11, x: 1, y: 1), cursor: nil)
        expect(false, "tile 429 should throw")
    } catch let error as ReciclarAPIError {
        if case .rateLimited(let message, let retry) = error {
            expect(message.contains("Demasiados"), "tile 429 message")
            expect(retry == 120, "tile 429 honours Retry-After")
        } else {
            expect(false, "tile 429 is rateLimited")
        }
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http tile 429 \(error)\n".utf8))
    }

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.responseHeaders = ["Retry-After": "15"]
            StubURLProtocol.handler = { _ in
                (503, Data(#"{"error":"area_unavailable","message":"Não foi possível carregar esta zona. Tenta novamente."}"#.utf8))
            }
        }
        _ = try await client.fetchCommunityEvents(bounds: GeographicBounds(minLatitude: 38.7, maxLatitude: 38.8, minLongitude: -9.2, maxLongitude: -9.1))
        expect(false, "503 should throw")
    } catch let error as ReciclarAPIError {
        if case .serviceUnavailable(let message, let retry) = error {
            expect(message.contains("zona"), "503 uses the server message")
            expect(retry == 15, "503 honours Retry-After")
        } else {
            expect(false, "503 is serviceUnavailable")
        }
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http 503 \(error)\n".utf8))
    }

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.responseHeaders = ["Cache-Control": "public, max-age=60"]
            StubURLProtocol.handler = { _ in
                (200, Data(#"{"as_of":"2026-09-07T12:00:00.000Z","events":[{"id":"e1","location_id":"lisbon","issue":"vandalized","kind":"report","server_timestamp":"2026-09-07T12:00:00.000Z"}]}"#.utf8))
            }
        }
        let events = try await client.fetchCommunityEvents(bounds: GeographicBounds(minLatitude: 38.7, maxLatitude: 38.8, minLongitude: -9.2, maxLongitude: -9.1))
        let urlString = StubURLProtocol.lock.withLock { StubURLProtocol.lastURL }
        let policy = StubURLProtocol.lock.withLock { StubURLProtocol.lastCachePolicy }
        expect(events.events.first?.ecopontoID == "lisbon", "events use location_id")
        expect(urlString.contains("/v1/community-events"), "events path")
        expect(urlString.contains("bbox="), "events bbox")
        expect(policy == .useProtocolCachePolicy, "events use the protocol cache")
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http events \(error)\n".utf8))
    }

    do {
        StubURLProtocol.lock.withLock {
            StubURLProtocol.responseHeaders = ["ETag": "\"ids\""]
            StubURLProtocol.handler = { _ in
                (200, Data(#"{"locations":[{"id":"kept","latitude":41.2,"longitude":-8.5,"provenance":{"label":"Operador Alfa"},"containers":[]}],"missing":["gone"]}"#.utf8))
            }
        }
        let batch = try await client.fetchLocations(ids: ["gone", "kept"])
        let urlString = StubURLProtocol.lock.withLock { StubURLProtocol.lastURL }
        let policy = StubURLProtocol.lock.withLock { StubURLProtocol.lastCachePolicy }
        expect(batch.locations.map(\.id) == ["kept"], "ids batch returns locations")
        expect(batch.missing == ["gone"], "ids batch returns missing")
        expect(urlString.contains("ids=gone%2Ckept") || urlString.contains("ids=gone,kept"), "ids query")
        expect(policy == .useProtocolCachePolicy, "ids batch uses the protocol cache")
    } catch {
        failures += 1
        FileHandle.standardError.write(Data("FAIL http ids \(error)\n".utf8))
    }

    StubURLProtocol.lock.withLock {
        StubURLProtocol.handler = nil
        StubURLProtocol.responseHeaders = [:]
    }
}

func submissionFields(_ json: String) -> [String: String] {
    let object = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    var fields: [String: String] = [:]
    for (key, value) in object {
        fields[key] = value as? String ?? String(describing: value)
    }
    return fields
}

func expectUnlinkedSubmission(
    json: String,
    headers: [String: String],
    ecopontoID: String,
    issue: String,
    kind: String,
    label: String,
    expect: (Bool, String) -> Void
) {
    guard let object = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] else {
        expect(false, "\(label) body is a JSON object")
        return
    }
    let keys = Set(object.keys)
    expect(keys == ["ecoponto_id", "issue", "kind"], "\(label) body is only the collection point, category, and type")
    expect(object["ecoponto_id"] as? String == ecopontoID, "\(label) sends the collection point id")
    expect(object["issue"] as? String == issue, "\(label) sends the category")
    expect(object["kind"] as? String == kind, "\(label) sends the type")
    let lowered = json.lowercased()
    for token in ["installation", "latitude", "longitude", "accuracy", "recorded_at", "fix_at", "reporter", "identifier"] {
        expect(!lowered.contains(token), "\(label) body has no \(token)")
    }
    let names = headers.keys.map { $0.lowercased() }
    expect(names.contains("x-reciclar-version"), "\(label) still sends the app version header")
    for name in names {
        let identifiesDevice = name.contains("install") || name.contains("device") || name.contains("vendor") || name.contains("reporter")
        expect(!identifiesDevice, "\(label) has no identity header \(name)")
    }
}

func runLegacyInstallationChecks(expect: (Bool, String) -> Void) {
    let suite = "reciclar-legacy-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    for key in LegacyInstallationIdentity.userDefaultsKeys {
        defaults.set("legacy-\(key)", forKey: key)
    }
    defaults.set("keep-viewport", forKey: "map.viewport")
    LegacyInstallationIdentity.deletePersistedValues(userDefaults: defaults)
    for key in LegacyInstallationIdentity.userDefaultsKeys {
        expect(defaults.object(forKey: key) == nil, "launch cleanup removes UserDefaults \(key)")
    }
    expect(defaults.string(forKey: "map.viewport") == "keep-viewport", "launch cleanup leaves the saved map region")

    #if canImport(Security)
    let production: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: LegacyInstallationIdentity.keychainService,
        kSecAttrAccount as String: LegacyInstallationIdentity.keychainAccount,
        kSecValueData as String: Data("legacy-production".utf8),
    ]
    SecItemDelete(production as CFDictionary)
    let stored = SecItemAdd(production as CFDictionary, nil)
    expect(stored == errSecSuccess, "legacy keychain installation id can be stored")
    LegacyInstallationIdentity.deletePersistedValues(userDefaults: defaults)
    var item: CFTypeRef?
    var read = production
    read.removeValue(forKey: kSecValueData as String)
    read[kSecReturnData as String] = true
    read[kSecMatchLimit as String] = kSecMatchLimitOne
    let status = SecItemCopyMatching(read as CFDictionary, &item)
    expect(status == errSecItemNotFound, "launch cleanup deletes the legacy keychain installation id")
    #endif
}
