import Foundation
#if canImport(FoundationNetworking)
@preconcurrency import FoundationNetworking
#endif

/// Marketing version and build from the app bundle, formatted `1.1.0 (6)`.
public enum ReciclarAppVersion {
    public static let headerField = "X-Reciclar-Version"

    public static func headerValue(marketing: String, build: String) -> String {
        "\(marketing) (\(build))"
    }

    /// Reads `CFBundleShortVersionString` and `CFBundleVersion`. Nil when either is missing.
    public static func headerValue(in bundle: Bundle) -> String? {
        guard
            let marketing = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        else { return nil }
        let trimmedMarketing = marketing.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBuild = build.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMarketing.isEmpty, !trimmedBuild.isEmpty else { return nil }
        return headerValue(marketing: trimmedMarketing, build: trimmedBuild)
    }
}

public struct ReciclarAPIConfiguration: Sendable {
    public var baseURL: URL
    public var session: URLSession
    /// Single slippy-map zoom the map asks for. The API rejects every other z.
    public var tileZoom: Int

    public init(
        baseURL: URL,
        session: URLSession = ReciclarAPIConfiguration.makeSession(),
        tileZoom: Int = MapTilePolicy.zoom
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tileZoom = tileZoom
    }

    public static let productionBaseURL = URL(string: "https://ecopontos-api.rgllm.workers.dev")!

    public static var production: ReciclarAPIConfiguration {
        ReciclarAPIConfiguration(baseURL: productionBaseURL)
    }

    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 180
        #if canImport(Darwin)
        configuration.waitsForConnectivity = false
        #endif
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Accept-Language": "pt-PT",
        ]
        #if canImport(Darwin)
        configuration.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 20 * 1024 * 1024)
        #else
        configuration.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 20 * 1024 * 1024, diskPath: nil)
        #endif
        return URLSession(configuration: configuration)
    }
}

public actor HTTPReciclarClient: ReciclarAPIClient {
    private let configuration: ReciclarAPIConfiguration
    private let versionHeader: String?
    private let decoder = APIJSONCoding.decoder()
    private let encoder = APIJSONCoding.encoder()

    public init(
        configuration: ReciclarAPIConfiguration = .production,
        versionHeader: String? = ReciclarAppVersion.headerValue(in: .main)
    ) {
        self.configuration = configuration
        self.versionHeader = versionHeader
    }

    public func fetchStats() async throws -> CatalogStatistics {
        let dto: APICatalogStatsDTO = try await get(path: "/v1/stats", cachePolicy: .useProtocolCachePolicy)
        return APILocationMapper.statistics(from: dto)
    }

    public func fetchArea(bounds: GeographicBounds, cursor: String?) async throws -> AreaPage {
        var query = [URLQueryItem(name: "bbox", value: bounds.queryValue)]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        let dto: APILocationsPageDTO = try await get(path: "/v1/locations", query: query)
        guard let scope = dto.scope, scope.kind == "area", scope.bbox.count == 4 else {
            throw ReciclarAPIError.invalidResponse
        }
        let returned = GeographicBounds(minLatitude: scope.bbox[1], maxLatitude: scope.bbox[3],
                                        minLongitude: scope.bbox[0], maxLongitude: scope.bbox[2])
        let page = APILocationMapper.page(from: dto)
        guard page.locations.count == dto.locations.count else { throw ReciclarAPIError.invalidResponse }
        return AreaPage(bounds: returned, page: page)
    }

    public func fetchTile(_ tile: SlippyTileCoordinate, cursor: String?) async throws -> TilePage {
        var query: [URLQueryItem] = []
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        let dto: APITileResponseDTO = try await get(path: "/v1/tiles/\(tile.z)/\(tile.x)/\(tile.y)", query: query)
        guard let page = APILocationMapper.tilePage(from: dto), page.tile == tile else {
            throw ReciclarAPIError.invalidResponse
        }
        return page
    }

    public func fetchCommunityEvents(bounds: GeographicBounds) async throws -> CommunityEventsPage {
        let dto: APICommunityEventsDTO = try await get(
            path: "/v1/community-events",
            query: [URLQueryItem(name: "bbox", value: bounds.queryValue)]
        )
        return APILocationMapper.events(from: dto)
    }

    public func fetchLocations(ids: [String]) async throws -> LocationIDBatch {
        let ordered = ids.sorted()
        guard !ordered.isEmpty, ordered.count <= MapTilePolicy.favouriteBatchLimit else {
            throw ReciclarAPIError.invalidResponse
        }
        let dto: APILocationIDBatchDTO = try await get(
            path: "/v1/locations",
            query: [URLQueryItem(name: "ids", value: ordered.joined(separator: ","))]
        )
        guard let batch = APILocationMapper.idBatch(from: dto) else { throw ReciclarAPIError.invalidResponse }
        return batch
    }

    public func fetchLocation(id: String) async throws -> LocationDetailResponse {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let dto: APILocationDetailDTO = try await get(
            path: "/v1/locations/\(encoded)",
            cachePolicy: .useProtocolCachePolicy
        )
        return try APILocationMapper.detail(from: dto)
    }

    public func submitReport(_ request: IssueSubmissionRequest) async throws -> CommunityEvent {
        let encoded = request.ecopontoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? request.ecopontoID
        return try await post(
            path: "/v1/locations/\(encoded)/reports",
            body: writeBody(ecopontoID: request.ecopontoID, issue: request.issue, kind: .report)
        )
    }

    public func submitResolution(_ request: IssueResolutionRequest) async throws -> CommunityEvent {
        let encodedID = request.ecopontoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? request.ecopontoID
        let encodedIssue = request.issue.wireValue
        return try await post(
            path: "/v1/locations/\(encodedID)/reports/\(encodedIssue)/resolve",
            body: writeBody(ecopontoID: request.ecopontoID, issue: request.issue, kind: .resolution)
        )
    }

    /// The on-device proximity check is the only use of the user's fix.
    /// This body is the collection point, the category, and the type.
    private func writeBody(
        ecopontoID: String,
        issue: CommunityIssueKind,
        kind: CommunityEventKind
    ) -> APICommunityWriteBody {
        APICommunityWriteBody(ecoponto_id: ecopontoID, issue: issue.wireValue, kind: kind.rawValue)
    }

    private func get<T: Decodable>(
        path: String,
        query: [URLQueryItem] = [],
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) async throws -> T {
        let request = try makeRequest(path: path, query: query, method: "GET", cachePolicy: cachePolicy)
        return try await send(request)
    }

    private func post<Body: Encodable>(path: String, body: Body) async throws -> CommunityEvent {
        var request = try makeRequest(
            path: path,
            method: "POST"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        let dto: APICommunityEventDTO = try await send(request, submission: true)
        guard let event = APILocationMapper.event(from: dto) else {
            throw ReciclarAPIError.invalidResponse
        }
        return event
    }

    private func makeRequest(
        path: String,
        query: [URLQueryItem] = [],
        method: String,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) throws -> URLRequest {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw ReciclarAPIError.invalidResponse
        }
        let basePath = configuration.baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = path.hasPrefix("/") ? path : "/\(path)"
        components.path = basePath.isEmpty ? suffix : "/\(basePath)\(suffix)"
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw ReciclarAPIError.invalidResponse
        }
        var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: 45)
        request.httpMethod = method
        if let versionHeader {
            request.setValue(versionHeader, forHTTPHeaderField: ReciclarAppVersion.headerField)
        }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, submission: Bool = false) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await configuration.session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw ReciclarAPIError.unavailable
        }
        guard let http = response as? HTTPURLResponse else {
            throw ReciclarAPIError.invalidResponse
        }
        if submission, http.statusCode == 429 {
            throw ReciclarAPIError.rateLimited(
                IssueReportPolicy.rateLimitMessage,
                retryAfter: RetryAfterParser.delay(from: http)
            )
        }
        if http.statusCode == 304 {
            guard let cached = configuration.session.configuration.urlCache?.cachedResponse(for: request)?.data else {
                throw ReciclarAPIError.invalidResponse
            }
            return try decode(T.self, from: cached)
        }
        if (200..<300).contains(http.statusCode) {
            return try decode(T.self, from: data)
        }
        throw mapError(response: http, data: data)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw ReciclarAPIError.invalidResponse
        }
    }

    private func mapError(response: HTTPURLResponse, data: Data) -> ReciclarAPIError {
        let dto = try? decoder.decode(APIErrorDTO.self, from: data)
        let code = dto?.error ?? ""
        let message = dto?.message ?? ""
        let retryAfter = RetryAfterParser.delay(from: response)
        switch (response.statusCode, code) {
        case (400, "invalid_sync_token"):
            return .invalidSyncToken
        case (403, _):
            return .proximity(message.isEmpty ? "É preciso estar junto ao ecoponto para reportar ou resolver um problema." : message)
        case (404, _):
            return .notFound
        case (410, _):
            return .gone
        case (429, _):
            return .rateLimited(
                message.isEmpty ? "Demasiados reportes neste momento. Tente mais tarde." : message,
                retryAfter: retryAfter
            )
        case (503, _):
            return .serviceUnavailable(
                message.isEmpty ? "Não foi possível carregar esta zona. Tenta novamente." : message,
                retryAfter: retryAfter
            )
        default:
            if !message.isEmpty {
                return .server(status: response.statusCode, code: code, message: message)
            }
            return .unavailable
        }
    }
}

enum RetryAfterParser {
    static func delay(from response: HTTPURLResponse, now: Date = Date()) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        if let seconds = TimeInterval(raw), seconds >= 0, seconds.isFinite, seconds <= 24 * 60 * 60 {
            return seconds
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: raw) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}

public func decodeAPILocationPage(from data: Data) throws -> LocationSyncPage {
    let dto = try APIJSONCoding.decoder().decode(APILocationsPageDTO.self, from: data)
    return APILocationMapper.page(from: dto)
}

public func decodeAPILocationDetail(from data: Data) throws -> LocationDetailResponse {
    let dto = try APIJSONCoding.decoder().decode(APILocationDetailDTO.self, from: data)
    return try APILocationMapper.detail(from: dto)
}

public func decodeAPIStats(from data: Data) throws -> CatalogStatistics {
    let dto = try APIJSONCoding.decoder().decode(APICatalogStatsDTO.self, from: data)
    return APILocationMapper.statistics(from: dto)
}
