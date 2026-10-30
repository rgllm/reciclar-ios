import ReciclarCore
import SwiftUI

enum MapPalette {
    static let pin = Color(red: 0.20, green: 0.70, blue: 0.40)
    static let cluster = Color(red: 0.18, green: 0.47, blue: 0.96)

    static var pinUIColor: UIColor {
        pinUIColor(for: .available)
    }

    static var clusterUIColor: UIColor {
        UIColor(red: 0.18, green: 0.47, blue: 0.96, alpha: 1)
    }

    /// Colour is a secondary cue. Pins also change shape, symbol, and text.
    static func pinUIColor(for availability: SpaceAvailability) -> UIColor {
        switch availability {
        case .available:
            UIColor(red: 0.20, green: 0.70, blue: 0.40, alpha: 1)
        case .noSpace:
            UIColor(red: 0.62, green: 0.32, blue: 0.16, alpha: 1)
        case .unknown:
            UIColor(red: 0.42, green: 0.45, blue: 0.48, alpha: 1)
        }
    }

    static func color(for availability: SpaceAvailability) -> Color {
        Color(uiColor: pinUIColor(for: availability))
    }

    static func symbolName(for availability: SpaceAvailability) -> String {
        switch availability {
        case .available: "checkmark.circle.fill"
        case .noSpace: "xmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

enum MapPinPresentation {
    static func containerCount(for location: Ecoponto) -> Int {
        location.containers.count
    }

    static func status(for location: Ecoponto, filter: LocationFilter, at now: Date) -> LocationSpaceStatus {
        filter.spaceStatus(of: location, at: now)
    }

    static func accessibilityLabel(for location: Ecoponto, status: LocationSpaceStatus) -> String {
        let count = containerCount(for: location)
        let containers = count == 1 ? "1 contentor" : "\(count) contentores"
        return "\(location.displayName). \(status.accessibilityLabel). \(containers)."
    }
}

enum MapLoadCopy {
    static func title(_ reason: MapEmptyReason) -> String {
        switch reason {
        case .zoomIn: "Aproxima o mapa para ver ecopontos"
        case .noLocations: "Sem ecopontos nesta zona"
        case .loading: "A carregar ecopontos"
        case .noCachedData: "Esta zona ainda não está guardada"
        case .failedRefresh: "Não foi possível carregar"
        case .noMatches: "Nenhum ecoponto corresponde aos filtros"
        }
    }

    static func detail(_ reason: MapEmptyReason, error: String?) -> String {
        switch reason {
        case .zoomIn:
            "Carregamos os ecopontos da zona que estás a ver."
        case .noLocations:
            "Esta zona foi carregada e a fonte não tem ecopontos aqui. A cobertura disponível é limitada."
        case .loading:
            "A carregar esta zona. Podes continuar a usar o mapa."
        case .noCachedData:
            "Isto não significa que não existam ecopontos. Tenta atualizar."
        case .failedRefresh:
            error ?? "Não foi possível obter os ecopontos desta zona."
        case .noMatches:
            "Os filtros pedem locais que aceitem todas as categorias escolhidas."
        }
    }

    static func symbol(_ reason: MapEmptyReason) -> String {
        switch reason {
        case .zoomIn: "plus.magnifyingglass"
        case .noLocations: "mappin.slash"
        case .loading: "map"
        case .noCachedData: "arrow.down.circle"
        case .failedRefresh: "exclamationmark.triangle"
        case .noMatches: "line.3.horizontal.decrease.circle"
        }
    }

    static func offersRetry(_ reason: MapEmptyReason) -> Bool {
        reason == .failedRefresh || reason == .noCachedData
    }
}

struct MapCircleButton: View {
    @ScaledMetric(relativeTo: .body) private var size = 44.0
    let systemImage: String
    let accessibilityLabel: String
    var accessibilityHint: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: resolvedSize, height: resolvedSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .disabled(disabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHintIfPresent(accessibilityHint)
    }

    private var resolvedSize: CGFloat { min(max(size, 44), 56) }
}

struct MapSquareButton: View {
    @ScaledMetric(relativeTo: .body) private var size = 44.0
    let systemImage: String
    let accessibilityLabel: String
    var accessibilityHint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: resolvedSize, height: resolvedSize)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHintIfPresent(accessibilityHint)
    }

    private var resolvedSize: CGFloat { min(max(size, 44), 56) }
}

struct MapFilterChip: View {
    let title: String
    var systemImage: String?
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(MapPalette.pin).interactive() : .regular.interactive(),
            in: Capsule()
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct NoReadingLegend: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(MapPalette.color(for: .unknown))
                .overlay {
                    Circle()
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                        .padding(1)
                }
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            Text(LocationSpaceStatus.missingReadingExplanation)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legenda: pontos cinzentos tracejados, \(LocationSpaceStatus.missingReadingExplanation).")
    }
}

struct MapToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
            .accessibilityAddTraits(.updatesFrequently)
    }
}

extension View {
    @ViewBuilder
    func accessibilityHintIfPresent(_ hint: String?) -> some View {
        if let hint, !hint.isEmpty {
            accessibilityHint(hint)
        } else {
            self
        }
    }
}
