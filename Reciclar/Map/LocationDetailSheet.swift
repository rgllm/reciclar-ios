import ReciclarCore
import MapKit
import SwiftUI

struct LocationDetailSheet: View {
    let location: Ecoponto
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    materials
                    community
                    source
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                model.issueFeedback = nil
                model.refreshReportPositionIfAuthorized()
            }
            .navigationTitle("Ecoponto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.toggleFavourite(location.id) }
                    } label: {
                        Image(systemName: model.isFavourite(location.id) ? "star.fill" : "star")
                    }
                    .accessibilityLabel(model.isFavourite(location.id) ? "Remover dos favoritos" : "Adicionar aos favoritos")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", systemImage: "xmark") {
                        model.selectedLocationID = nil
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(location.displayName)
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                if let place = location.placeLine, place != location.displayName {
                    Text(place)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if let explanation = locationSpaceStatus.detailExplanation {
                    HStack(spacing: 6) {
                        Image(systemName: MapPalette.symbolName(for: .unknown))
                            .accessibilityHidden(true)
                        Text(explanation)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                }
            }
            HStack(spacing: 12) {
                Button(action: openDirections) {
                    Label("Direções", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                ShareLink(item: mapsURL) {
                    Label("Partilhar localização", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 30, minHeight: 30)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Partilhar localização")
            }
            .controlSize(.large)
        }
    }

    private var materials: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Contentores").font(.headline)
                Spacer()
                Text("\(location.containers.count) contentores")
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(location.containers.enumerated()), id: \.offset) { index, container in
                    if index > 0 { Divider().padding(.leading, 72) }
                    ContainerSummaryRow(container: container, now: model.now)
                        .padding(16)
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        }
    }

    private var community: some View {
        let issues = model.visibleIssues(for: location)
        let availability = model.reportAvailability(for: location)
        let showsChooser = model.reportChooserLocationID == location.id
        let selection = model.reportDraft.ecopontoID == location.id ? model.reportDraft.selectedIssue : nil
        let canSend = availability.isEnabled && selection != nil && !model.reportDraft.isSubmitting
        return VStack(alignment: .leading, spacing: 12) {
            if !issues.isEmpty {
                Text("Observações da comunidade").font(.headline)
                ForEach(issues) { issue in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(PortugueseRelativeTime.reportedPhrase(kind: issue.kind, from: issue.reportedAt, now: model.now), systemImage: "exclamationmark.bubble")
                            .font(.subheadline)
                        Button("Dar como resolvido") {
                            Task { await model.resolveIssue(for: location, kind: issue.kind) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isSubmittingIssue || model.reportDraft.isSubmitting)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }
                if model.isSubmittingIssue {
                    ProgressView("A enviar…")
                }
            }

            Button {
                model.openReportChooser(for: location)
            } label: {
                Text(IssueReportPolicy.buttonTitle)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!availability.isEnabled)
            .accessibilityLabel(availability.accessibilityLabel)
            .accessibilityHint(availability.accessibilityHint)

            if let explanation = availability.explanation {
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if availability.canRequestPosition {
                Button(IssueReportPolicy.positionCheckTitle) {
                    Task { await model.refreshReportPosition() }
                }
                .accessibilityHint(IssueReportPolicy.positionCheckAccessibilityHint)
            }

            if showsChooser {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(CommunityIssueKind.allCases) { kind in
                        let selected = selection == kind
                        Button {
                            model.selectReportIssue(kind, for: location)
                        } label: {
                            HStack {
                                Text(kind.portugueseLabel)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if selected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.primary)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .disabled(model.reportDraft.isSubmitting)
                        .accessibilityLabel(kind.portugueseLabel)
                        .accessibilityHint(kind.reportChoiceAccessibilityHint)
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Tipos de problema")

                Button {
                    Task { await model.submitReport(for: location) }
                } label: {
                    Text(model.reportDraft.sendButtonTitle)
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSend)
                .accessibilityLabel(model.reportDraft.sendButtonAccessibilityLabel)
                .accessibilityHint(model.reportDraft.sendButtonAccessibilityHint)

                if model.reportDraft.isSubmitting {
                    ProgressView("A enviar…")
                }
                if let failure = model.reportDraft.failureMessage {
                    Text(failure)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }

            if let feedback = model.issueFeedback {
                Text(feedback)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            Text("Relatos de utilizadores, não verificados pelo operador.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sobre este ecoponto", systemImage: "info.circle").font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                if let provenance = location.provenance.userFacingLabel {
                    Text(provenance)
                }
                Text(location.coordinate.displayString)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("ecoponto-coordinates:\(coordinateToken)")
                    .accessibilityValue(coordinateToken)
                if let synced = model.snapshot.lastSuccessfulSync {
                    Text("Atualizado na app \(PortugueseRelativeTime.phrase(from: synced, now: model.now)).")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
        }
    }

    private var mapsURL: URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(location.coordinate.latitude),\(location.coordinate.longitude)"),
            URLQueryItem(name: "q", value: location.displayName),
        ]
        return components.url!
    }

    private var locationSpaceStatus: LocationSpaceStatus {
        model.filter.spaceStatus(of: location, at: model.now)
    }

    /// POSIX coordinates for the store-capture test. The visible text stays in pt-PT.
    private var coordinateToken: String {
        String(
            format: "%.6f,%.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            location.coordinate.latitude,
            location.coordinate.longitude
        )
    }

    private func openDirections() {
        let item = MKMapItem(location: CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), address: nil)
        item.name = location.displayName
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
    }
}

private struct ContainerSummaryRow: View {
    let container: Container
    let now: Date
    @ScaledMetric private var iconSize = 42.0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: WasteCategoryPresentation.symbol(for: container.category))
                .font(.title2.weight(.semibold))
                .foregroundStyle(WasteCategoryPresentation.color(for: container))
                .frame(width: iconSize, height: iconSize)
                .background(
                    WasteCategoryPresentation.color(for: container).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(WasteCategoryPresentation.title(for: container.category))
                    .font(.headline)
                spaceLine
                if case let .usable(_, recordedAt) = FillReadingPolicy.evidence(from: container.fillReading, at: now) {
                    Text("Leitura \(PortugueseRelativeTime.phrase(from: recordedAt, now: now))")
                        .font(.caption).foregroundStyle(.secondary)
                } else if RecyclingStream.classifying(name: container.category.name) == .packaging {
                    Text("Plástico, metal e pacotes de bebidas")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let volume = container.volumeLitres {
                    Text("\(volume.formatted(.number.locale(Locale(identifier: "pt_PT")))) litros")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let collected = container.lastCollectionAt, collected <= now {
                    Text("Última recolha \(PortugueseRelativeTime.phrase(from: collected, now: now))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var spaceStatus: LocationSpaceStatus {
        FillReadingPolicy.status(of: container.fillReading, at: now)
    }

    @ViewBuilder
    private var spaceLine: some View {
        switch spaceStatus.availability {
        case .available, .noSpace:
            if let percent = spaceStatus.percentFull {
                HStack(spacing: 6) {
                    Image(systemName: MapPalette.symbolName(for: spaceStatus.availability))
                        .foregroundStyle(MapPalette.color(for: spaceStatus.availability))
                        .accessibilityHidden(true)
                    Text("\(spaceStatus.portugueseLabel) · \(percent) % ocupado")
                        .foregroundStyle(.primary)
                }
                .font(.subheadline)
            }
        case .unknown:
            if let explanation = spaceStatus.detailExplanation {
                HStack(spacing: 6) {
                    Image(systemName: MapPalette.symbolName(for: .unknown))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(explanation)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }

    private var accessibilityText: String {
        var parts = [WasteCategoryPresentation.title(for: container.category), spaceStatus.accessibilityLabel]
        if let explanation = spaceStatus.detailExplanation {
            parts.append(explanation)
        }
        if case let .usable(_, recordedAt) = FillReadingPolicy.evidence(from: container.fillReading, at: now) {
            parts.append("Leitura \(PortugueseRelativeTime.phrase(from: recordedAt, now: now))")
        }
        if let volume = container.volumeLitres {
            let litres = volume.formatted(.number.locale(Locale(identifier: "pt_PT")))
            parts.append("\(litres) litros")
        }
        if let collected = container.lastCollectionAt, collected <= now {
            parts.append("Última recolha \(PortugueseRelativeTime.phrase(from: collected, now: now))")
        }
        return parts.joined(separator: ". ")
    }
}
