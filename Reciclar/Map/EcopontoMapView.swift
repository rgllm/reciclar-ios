import ReciclarCore
import MapKit
import SwiftUI
import UIKit

struct EcopontoMapView: UIViewRepresentable {
    var index: SpatialIndex
    var revision: Int
    var filter: LocationFilter
    @Binding var selectedID: Ecoponto.ID?
    @Binding var region: MKCoordinateRegion
    var showsUserLocation: Bool
    var reduceMotion: Bool
    var now: Date
    var onUserInteraction: () -> Void
    var attributionBottomInset: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        let configuration = MKStandardMapConfiguration()
        configuration.pointOfInterestFilter = .includingAll
        map.preferredConfiguration = configuration
        map.showsCompass = false
        map.showsUserLocation = showsUserLocation
        map.insetsLayoutMarginsFromSafeArea = false
        map.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: 16,
            bottom: attributionBottomInset,
            trailing: 16
        )
        map.register(EcopontoMarkerView.self, forAnnotationViewWithReuseIdentifier: EcopontoMarkerView.reuseID)
        map.register(EcopontoClusterView.self, forAnnotationViewWithReuseIdentifier: EcopontoClusterView.reuseID)
        map.register(EcopontoClusterView.self, forAnnotationViewWithReuseIdentifier: ViewportClusterAnnotation.reuseID)
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        map.showsUserLocation = showsUserLocation
        map.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: 16,
            bottom: attributionBottomInset,
            trailing: 16
        )
        // Only apply a new requested region. SwiftUI updates during a gesture must
        // not send the map back to the last completed viewport.
        if !context.coordinator.matchesLastRegion(region) {
            context.coordinator.lastRegion = region
            map.setRegion(region, animated: !reduceMotion)
        }
        context.coordinator.syncVisibleAnnotations(on: map)
        syncSelection(on: map)
    }

    private func syncSelection(on map: MKMapView) {
        if let selectedID,
           let annotation = map.annotations.compactMap({ $0 as? EcopontoAnnotation }).first(where: { $0.ecoponto.id == selectedID }) {
            if map.selectedAnnotations.first as? EcopontoAnnotation !== annotation {
                map.selectAnnotation(annotation, animated: !reduceMotion)
            }
        } else if !map.selectedAnnotations.isEmpty, selectedID == nil {
            map.deselectAnnotation(map.selectedAnnotations.first, animated: !reduceMotion)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: EcopontoMapView
        var lastRegion: MKCoordinateRegion

        func matchesLastRegion(_ region: MKCoordinateRegion) -> Bool {
            region.center.latitude == lastRegion.center.latitude
                && region.center.longitude == lastRegion.center.longitude
                && region.span.latitudeDelta == lastRegion.span.latitudeDelta
                && region.span.longitudeDelta == lastRegion.span.longitudeDelta
        }

        var index = SpatialIndex()
        var revision = -1
        var filter = LocationFilter()
        private let worker = MapPreparationWorker()
        private var renderTask: Task<Void, Never>?
        private var renderBounds: GeographicBounds?
        private var renderRevision = -1
        private var renderMinute = -1
        private var renderRevisionForExpiry = -1
        private var nextExpiry = Date.distantPast
        private var expiryPending = false
        private var generation = 0

        init(parent: EcopontoMapView) {
            self.parent = parent
            self.lastRegion = parent.region
        }

        func syncVisibleAnnotations(on map: MKMapView) {
            if parent.revision != revision {
                index = parent.index
                revision = parent.revision
            }
            let filterChanged = filter != parent.filter
            filter = parent.filter

            let bounds = GeographicBounds(
                center: Coordinate(latitude: map.region.center.latitude, longitude: map.region.center.longitude),
                latitudeDelta: map.region.span.latitudeDelta,
                longitudeDelta: map.region.span.longitudeDelta
            )
            let minute = Int(parent.now.timeIntervalSince1970 / 60)
            let boundsChanged = bounds != renderBounds
            let revisionChanged = revision != renderRevision
            let minuteChanged = minute != renderMinute
            // A compute already in flight owns the next boundary. Don't walk again
            // and don't treat the placeholder expiry as due.
            let expiryDue = !expiryPending && (revision != renderRevisionForExpiry || parent.now > nextExpiry)
            guard filterChanged || boundsChanged || revisionChanged || minuteChanged || expiryDue else { return }
            renderBounds = bounds
            renderRevision = revision
            renderMinute = minute
            let recomputeExpiry = expiryDue || expiryPending
            if recomputeExpiry {
                renderRevisionForExpiry = revision
                expiryPending = true
                nextExpiry = .distantFuture
            }
            let now = parent.now
            renderTask?.cancel()
            generation += 1
            let currentGeneration = generation
            let currentIndex = index
            let currentFilter = filter
            let span = map.region.span.latitudeDelta
            renderTask = Task { [weak self, weak map] in
                guard let self else { return }
                let boundary = recomputeExpiry
                    ? await self.worker.nextFillBoundary(in: currentIndex.locations, now: now)
                    : nil
                let items = await self.worker.items(
                    index: currentIndex,
                    bounds: bounds,
                    latitudeSpan: span,
                    filter: currentFilter,
                    now: now
                )
                guard !Task.isCancelled, currentGeneration == self.generation, let map else { return }
                if let boundary {
                    self.nextExpiry = boundary
                    self.expiryPending = false
                }
                self.apply(items, on: map)
            }
        }

        private func apply(_ items: [MapPresentationItem], on map: MKMapView) {
            let existingPins = map.annotations.compactMap { $0 as? EcopontoAnnotation }
            let existingClusters = map.annotations.compactMap { $0 as? ViewportClusterAnnotation }
            let pinsByID = Dictionary(existingPins.map { ($0.ecoponto.id, $0) }, uniquingKeysWith: { _, last in last })
            let clustersByID = Dictionary(existingClusters.map { ($0.clusterID, $0) }, uniquingKeysWith: { _, last in last })
            var nextPinIDs = Set<String>()
            var nextClusterIDs = Set<String>()
            var pinsToAdd: [EcopontoAnnotation] = []
            var clustersToAdd: [ViewportClusterAnnotation] = []

            for item in items {
                switch item {
                case .pin(let location):
                    nextPinIDs.insert(location.id)
                    if let existing = pinsByID[location.id] {
                        if existing.ecoponto != location { existing.ecoponto = location }
                        if let view = map.view(for: existing) as? EcopontoMarkerView {
                            view.apply(location: location, filter: parent.filter, now: parent.now)
                        }
                    } else {
                        pinsToAdd.append(EcopontoAnnotation(ecoponto: location))
                    }
                case .cluster(let id, let coordinate, let count):
                    nextClusterIDs.insert(id)
                    if let existing = clustersByID[id] {
                        existing.coordinate = CLLocationCoordinate2D(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude
                        )
                        existing.count = count
                        if let view = map.view(for: existing) as? EcopontoClusterView {
                            view.applyCount(count)
                        }
                    } else {
                        clustersToAdd.append(ViewportClusterAnnotation(id: id, coordinate: coordinate, count: count))
                    }
                }
            }

            let pinsToRemove = existingPins.filter { !nextPinIDs.contains($0.ecoponto.id) }
            let clustersToRemove = existingClusters.filter { !nextClusterIDs.contains($0.clusterID) }
            if !pinsToRemove.isEmpty || !clustersToRemove.isEmpty {
                map.removeAnnotations(pinsToRemove + clustersToRemove)
            }
            if !pinsToAdd.isEmpty {
                map.addAnnotations(pinsToAdd)
            }
            if !clustersToAdd.isEmpty {
                map.addAnnotations(clustersToAdd)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if annotation is MKClusterAnnotation || annotation is ViewportClusterAnnotation {
                let identifier = annotation is ViewportClusterAnnotation
                    ? ViewportClusterAnnotation.reuseID
                    : EcopontoClusterView.reuseID
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: identifier,
                    for: annotation
                ) as? EcopontoClusterView
                view?.apply(annotation)
                return view
            }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: EcopontoMarkerView.reuseID,
                for: annotation
            ) as? EcopontoMarkerView
            if let pin = annotation as? EcopontoAnnotation {
                view?.apply(location: pin.ecoponto, filter: parent.filter, now: parent.now)
            }
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                let rect = boundingRect(for: cluster.memberAnnotations)
                mapView.setVisibleMapRect(
                    rect,
                    edgePadding: UIEdgeInsets(top: 90, left: 40, bottom: 140, right: 40),
                    animated: !parent.reduceMotion
                )
                return
            }
            if let cluster = view.annotation as? ViewportClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                let span = MKCoordinateSpan(
                    latitudeDelta: max(mapView.region.span.latitudeDelta / 3.2, 0.012),
                    longitudeDelta: max(mapView.region.span.longitudeDelta / 3.2, 0.012)
                )
                mapView.setRegion(MKCoordinateRegion(center: cluster.coordinate, span: span), animated: !parent.reduceMotion)
                return
            }
            if let pin = view.annotation as? EcopontoAnnotation {
                parent.selectedID = pin.ecoponto.id
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            if view.annotation is EcopontoAnnotation {
                parent.selectedID = nil
            }
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            let recognizers = (mapView.gestureRecognizers ?? []) + mapView.subviews.flatMap { $0.gestureRecognizers ?? [] }
            if recognizers.contains(where: { $0.state == .began || $0.state == .changed }) {
                parent.onUserInteraction()
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            lastRegion = mapView.region
            parent.region = mapView.region
            syncVisibleAnnotations(on: mapView)
        }

        private func boundingRect(for annotations: [MKAnnotation]) -> MKMapRect {
            annotations.reduce(MKMapRect.null) { rect, annotation in
                let point = MKMapPoint(annotation.coordinate)
                let item = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
                return rect.isNull ? item : rect.union(item)
            }
        }
    }
}

final class ViewportClusterAnnotation: NSObject, MKAnnotation {
    static let reuseID = "ecoponto-viewport-cluster"
    let clusterID: String
    var count: Int
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { "\(count) ecopontos" }

    init(id: String, coordinate: Coordinate, count: Int) {
        self.clusterID = id
        self.count = count
        self.coordinate = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

final class EcopontoAnnotation: NSObject, MKAnnotation {
    var ecoponto: Ecoponto {
        didSet { coordinate = CLLocationCoordinate2D(latitude: ecoponto.coordinate.latitude, longitude: ecoponto.coordinate.longitude) }
    }
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { ecoponto.displayName }
    var subtitle: String? { ecoponto.placeLine }

    init(ecoponto: Ecoponto) {
        self.ecoponto = ecoponto
        self.coordinate = CLLocationCoordinate2D(latitude: ecoponto.coordinate.latitude, longitude: ecoponto.coordinate.longitude)
    }
}

final class EcopontoMarkerView: MKAnnotationView {
    static let reuseID = "ecoponto-marker"
    private let captionLabel = UILabel()
    private let captionContainer = UIView()
    private let symbolView = UIImageView()
    private let pinView = UIView()
    private let countLabel = UILabel()
    private let statusRing = CAShapeLayer()
    private var lastLocation: Ecoponto?
    private var lastStatus: LocationSpaceStatus?
    private var appliedNow = Date()
    private var appliedFilter = LocationFilter()
    private let pinSize: CGFloat = 34

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "ecoponto"
        collisionMode = .circle
        displayPriority = .defaultHigh
        canShowCallout = false
        isAccessibilityElement = true
        accessibilityTraits = [.button]
        build()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var annotation: MKAnnotation? {
        didSet { clusteringIdentifier = "ecoponto" }
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        if let pin = annotation as? EcopontoAnnotation {
            apply(location: pin.ecoponto, filter: appliedFilter, now: appliedNow)
        }
    }

    func apply(location: Ecoponto, filter: LocationFilter, now: Date) {
        appliedNow = now
        appliedFilter = filter
        let status = MapPinPresentation.status(for: location, filter: filter, at: now)
        guard lastLocation != location || lastStatus != status else { return }
        lastLocation = location
        lastStatus = status
        countLabel.text = "\(MapPinPresentation.containerCount(for: location))"
        captionContainer.isHidden = !status.showsMapCaption
        if status.showsMapCaption {
            captionLabel.text = status.portugueseLabel
        }
        accessibilityLabel = MapPinPresentation.accessibilityLabel(for: location, status: status)
        accessibilityValue = nil
        refreshSymbol()
        layoutChrome()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        let transform = selected ? CGAffineTransform(scaleX: 1.12, y: 1.12) : .identity
        if animated, !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.18) {
                self.pinView.transform = transform
            }
        } else {
            pinView.transform = transform
        }
    }

    private func build() {
        captionContainer.backgroundColor = .secondarySystemGroupedBackground
        captionContainer.layer.cornerRadius = 6
        captionContainer.layer.borderWidth = 1 / max(traitCollection.displayScale, 1)
        captionContainer.layer.borderColor = UIColor.separator.cgColor
        captionContainer.layer.shadowColor = UIColor.black.cgColor
        captionContainer.layer.shadowOpacity = 0.12
        captionContainer.layer.shadowRadius = 3
        captionContainer.layer.shadowOffset = CGSize(width: 0, height: 1)

        captionLabel.font = Self.captionFont
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.textColor = .label
        captionLabel.textAlignment = .center
        captionLabel.isAccessibilityElement = false

        symbolView.contentMode = .scaleAspectFit
        symbolView.tintColor = .label
        symbolView.isAccessibilityElement = false

        pinView.backgroundColor = MapPalette.pinUIColor
        pinView.layer.cornerRadius = pinSize / 2
        pinView.layer.borderWidth = 2
        pinView.layer.borderColor = UIColor.systemBackground.cgColor
        pinView.layer.shadowColor = UIColor.black.cgColor
        pinView.layer.shadowOpacity = 0.22
        pinView.layer.shadowRadius = 4
        pinView.layer.shadowOffset = CGSize(width: 0, height: 2)
        statusRing.fillColor = UIColor.clear.cgColor
        statusRing.lineWidth = 2
        statusRing.lineDashPattern = [NSNumber(value: 3), NSNumber(value: 2)]
        statusRing.isHidden = true
        pinView.layer.addSublayer(statusRing)

        countLabel.font = Self.countFont
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = .white
        countLabel.textAlignment = .center
        countLabel.adjustsFontSizeToFitWidth = true
        countLabel.minimumScaleFactor = 0.7
        countLabel.isAccessibilityElement = false

        addSubview(captionContainer)
        captionContainer.addSubview(symbolView)
        captionContainer.addSubview(captionLabel)
        addSubview(pinView)
        pinView.addSubview(countLabel)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        captionLabel.font = Self.captionFont
        countLabel.font = Self.countFont
        captionContainer.layer.borderWidth = 1 / max(traitCollection.displayScale, 1)
        pinView.layer.borderColor = UIColor.systemBackground.cgColor
        refreshSymbol()
        layoutChrome()
    }

    private func refreshSymbol() {
        guard let status = lastStatus else { return }
        let configuration = UIImage.SymbolConfiguration(pointSize: max(10, captionLabel.font.pointSize), weight: .bold)
        symbolView.image = UIImage(systemName: MapPalette.symbolName(for: status.availability), withConfiguration: configuration)
        symbolView.tintColor = .label
        pinView.backgroundColor = MapPalette.pinUIColor(for: status.availability)
    }

    private static var captionFont: UIFont {
        UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .systemFont(ofSize: 11, weight: .semibold),
            maximumPointSize: 16
        )
    }

    private static var countFont: UIFont {
        UIFontMetrics(forTextStyle: .headline).scaledFont(
            for: .systemFont(ofSize: 15, weight: .bold),
            maximumPointSize: 20
        )
    }

    private var resolvedCaptionHeight: CGFloat {
        ceil(captionLabel.font.lineHeight) + 8
    }

    private func layoutChrome() {
        captionLabel.sizeToFit()
        let symbolSide = ceil(captionLabel.font.lineHeight)
        let captionWidth = max(6 + symbolSide + 4 + captionLabel.bounds.width + 6, 36)
        let captionHeight = resolvedCaptionHeight
        let width = max(captionWidth, pinSize)
        let height = captionContainer.isHidden ? pinSize : pinSize + 4 + captionHeight
        bounds = CGRect(x: 0, y: 0, width: width, height: height)
        centerOffset = CGPoint(x: 0, y: -height / 2)

        let availability = lastStatus?.availability
        let isUnknown = availability == .unknown
        let isNoSpace = availability == .noSpace
        pinView.layer.cornerRadius = isNoSpace ? 8 : pinSize / 2
        pinView.layer.borderWidth = isUnknown ? 0 : 2

        if captionContainer.isHidden {
            captionContainer.frame = .zero
            pinView.frame = CGRect(x: (width - pinSize) / 2, y: 0, width: pinSize, height: pinSize)
        } else {
            captionContainer.frame = CGRect(
                x: (width - captionWidth) / 2,
                y: 0,
                width: captionWidth,
                height: captionHeight
            )
            symbolView.frame = CGRect(
                x: 6,
                y: (captionHeight - symbolSide) / 2,
                width: symbolSide,
                height: symbolSide
            )
            captionLabel.frame = CGRect(
                x: 6 + symbolSide + 4,
                y: 0,
                width: captionLabel.bounds.width,
                height: captionHeight
            )
            pinView.frame = CGRect(x: (width - pinSize) / 2, y: captionHeight + 4, width: pinSize, height: pinSize)
        }
        countLabel.frame = pinView.bounds
        let ringRect = pinView.bounds.insetBy(dx: 1.5, dy: 1.5)
        statusRing.frame = pinView.bounds
        statusRing.path = UIBezierPath(ovalIn: ringRect).cgPath
        statusRing.strokeColor = UIColor.systemBackground.cgColor
        statusRing.isHidden = !isUnknown
    }
}

final class EcopontoClusterView: MKAnnotationView {
    static let reuseID = "ecoponto-cluster"
    private let pinView = UIView()
    private let countLabel = UILabel()
    private let pinSize: CGFloat = 38

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        displayPriority = .defaultHigh
        collisionMode = .circle
        canShowCallout = false
        build()
        bounds = CGRect(x: 0, y: 0, width: pinSize, height: pinSize)
        centerOffset = CGPoint(x: 0, y: -pinSize / 2)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        apply(annotation)
    }

    func apply(_ annotation: MKAnnotation?) {
        if let cluster = annotation as? ViewportClusterAnnotation {
            applyCount(cluster.count)
            return
        }
        let count = (annotation as? MKClusterAnnotation)?.memberAnnotations.count ?? 0
        applyCount(count)
    }

    func applyCount(_ count: Int) {
        countLabel.text = "\(count)"
        accessibilityLabel = "Grupo de \(count) ecopontos"
    }

    private func build() {
        pinView.backgroundColor = MapPalette.clusterUIColor
        pinView.layer.cornerRadius = pinSize / 2
        pinView.layer.borderWidth = 2
        pinView.layer.borderColor = UIColor.systemBackground.cgColor
        pinView.layer.shadowColor = UIColor.black.cgColor
        pinView.layer.shadowOpacity = 0.22
        pinView.layer.shadowRadius = 4
        pinView.layer.shadowOffset = CGSize(width: 0, height: 2)
        pinView.frame = CGRect(x: 0, y: 0, width: pinSize, height: pinSize)

        countLabel.font = UIFontMetrics(forTextStyle: .headline).scaledFont(
            for: .systemFont(ofSize: 16, weight: .bold),
            maximumPointSize: 22
        )
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = .white
        countLabel.textAlignment = .center
        countLabel.adjustsFontSizeToFitWidth = true
        countLabel.minimumScaleFactor = 0.7
        countLabel.frame = pinView.bounds

        addSubview(pinView)
        pinView.addSubview(countLabel)
    }
}

@MainActor
enum WasteStreamSymbol {
    static func image(for stream: RecyclingStream?) -> UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        return UIImage(systemName: symbolName(for: stream), withConfiguration: configuration)
            ?? UIImage(systemName: "arrow.3.trianglepath", withConfiguration: configuration)!
    }

    static func color(for stream: RecyclingStream?) -> UIColor {
        switch stream {
        case .glass: .systemGreen
        case .paper: .systemBlue
        case .packaging: .systemOrange
        case nil: .secondaryLabel
        }
    }

    private static func symbolName(for stream: RecyclingStream?) -> String {
        switch stream {
        case .glass: "wineglass"
        case .paper: "newspaper.fill"
        case .packaging: "shippingbox.fill"
        case nil: "arrow.3.trianglepath"
        }
    }
}
