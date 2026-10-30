import Foundation

/// Pair the server uses as one community-issue category on one ecoponto.
/// Concurrent posts of the same pair would insert two rows and each counts toward the hourly limit.
public struct IssueReportKey: Hashable, Sendable {
    public var ecopontoID: String
    public var issue: CommunityIssueKind

    public init(ecopontoID: String, issue: CommunityIssueKind) {
        self.ecopontoID = ecopontoID
        self.issue = issue
    }
}

public enum ReportLocationAccess: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

public struct IssueReportAvailability: Equatable, Sendable {
    public var isEnabled: Bool
    /// Visible reason the report action cannot be used. Nil when the user may choose an issue.
    public var explanation: String?
    /// A newer fix could change the result, so the interface may offer a location check.
    public var canRequestPosition: Bool
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        isEnabled: Bool,
        explanation: String?,
        canRequestPosition: Bool,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.isEnabled = isEnabled
        self.explanation = explanation
        self.canRequestPosition = canRequestPosition
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }
}

/// Client rules for `POST /v1/locations/{id}/reports`.
/// The 100 m check runs on the device. The request does not include the fix.
/// The server accepts only `litter_outside_containers` and `vandalized`.
public enum IssueReportPolicy {
    public static let buttonTitle = "Reportar problema"
    public static let sendTitle = "Enviar reporte"
    public static let retryTitle = "Tentar novamente"
    public static let sendingTitle = "A enviar…"
    public static let positionCheckTitle = "Verificar a minha posição"
    public static let positionCheckAccessibilityHint = "Pede a localização para confirmar que estás a menos de 100 metros deste ecoponto."
    public static let successMessage = "O reporte foi partilhado."
    public static let failureFallback = "Não foi possível partilhar o reporte. Tenta outra vez."
    /// Shown for HTTP 429 on a report or a resolution. The server message is not used.
    public static let rateLimitMessage = "Fizeste muitos reportes. Tenta mais tarde."

    /// Wire values `POST /v1/locations/{id}/reports` accepts. Aliases stay off this list.
    public static let serverWireValues: Set<String> = ["litter_outside_containers", "vandalized"]

    public static func availability(
        destination: Coordinate,
        fix: LocationFix?,
        access: ReportLocationAccess,
        isSubmitting: Bool,
        isCheckingPosition: Bool,
        now: Date,
        policy: ProximityPolicy = .approved
    ) -> IssueReportAvailability {
        if isSubmitting {
            return IssueReportAvailability(
                isEnabled: false,
                explanation: sendingTitle,
                canRequestPosition: false,
                accessibilityLabel: buttonTitle,
                accessibilityHint: "A enviar o reporte. Aguarda a confirmação."
            )
        }

        switch access {
        case .denied:
            return disabled(
                "Sem acesso à localização, não é possível confirmar que estás junto ao ecoponto. Ativa a localização nas Definições.",
                canRequestPosition: false
            )
        case .notDetermined:
            return disabled(
                "Para reportar um problema, confirma que estás a menos de 100 metros do ecoponto.",
                canRequestPosition: true
            )
        case .authorized:
            break
        }

        switch Geodesy.evaluate(destination: destination, fix: fix, now: now, policy: policy) {
        case .withinRange:
            return IssueReportAvailability(
                isEnabled: true,
                explanation: nil,
                canRequestPosition: false,
                accessibilityLabel: buttonTitle,
                accessibilityHint: "Escolhe lixo fora dos contentores ou vandalizado."
            )
        case .tooFar:
            return disabled(
                "Estás demasiado longe. Só podes reportar um problema a menos de 100 metros deste ecoponto.",
                canRequestPosition: !isCheckingPosition
            )
        case .fixTooOld:
            return disabled(
                isCheckingPosition
                    ? checkingExplanation
                    : "A posição está desatualizada. Atualiza-a junto ao ecoponto, a menos de 100 metros.",
                canRequestPosition: !isCheckingPosition
            )
        case .fixTooInaccurate:
            return disabled(
                isCheckingPosition
                    ? checkingExplanation
                    : "A precisão da posição não chega para confirmar que estás a menos de 100 metros do ecoponto.",
                canRequestPosition: !isCheckingPosition
            )
        case .noFix:
            return disabled(
                isCheckingPosition
                    ? checkingExplanation
                    : "Não foi possível obter a tua posição. Tens de estar a menos de 100 metros do ecoponto.",
                canRequestPosition: !isCheckingPosition
            )
        }
    }

    private static let checkingExplanation = "A obter a tua posição para confirmar que estás a menos de 100 metros."

    private static func disabled(_ explanation: String, canRequestPosition: Bool) -> IssueReportAvailability {
        IssueReportAvailability(
            isEnabled: false,
            explanation: explanation,
            canRequestPosition: canRequestPosition,
            accessibilityLabel: buttonTitle,
            accessibilityHint: explanation
        )
    }
}

extension CommunityIssueKind {
    public var reportChoiceAccessibilityHint: String {
        "Tipo de problema a reportar neste ecoponto."
    }
}

/// Selected issue for one ecoponto. A failed send keeps the choice so the user can retry.
public struct IssueReportDraft: Equatable, Sendable {
    public var ecopontoID: String?
    public var selectedIssue: CommunityIssueKind?
    public private(set) var isSubmitting: Bool
    public var failureMessage: String?

    public init(
        ecopontoID: String? = nil,
        selectedIssue: CommunityIssueKind? = nil,
        isSubmitting: Bool = false,
        failureMessage: String? = nil
    ) {
        self.ecopontoID = ecopontoID
        self.selectedIssue = selectedIssue
        self.isSubmitting = isSubmitting
        self.failureMessage = failureMessage
    }

    public var sendButtonTitle: String {
        if isSubmitting { return IssueReportPolicy.sendingTitle }
        if failureMessage != nil { return IssueReportPolicy.retryTitle }
        return IssueReportPolicy.sendTitle
    }

    public var sendButtonAccessibilityLabel: String { sendButtonTitle }

    public var sendButtonAccessibilityHint: String {
        if isSubmitting { return "Aguarda a confirmação do servidor." }
        if selectedIssue == nil { return "Escolhe primeiro o tipo de problema." }
        if failureMessage != nil { return "Tenta enviar outra vez a mesma escolha." }
        return "Envia o reporte para as outras pessoas verem."
    }

    public mutating func select(_ issue: CommunityIssueKind, for ecopontoID: String) {
        guard !isSubmitting else { return }
        if self.ecopontoID != ecopontoID {
            failureMessage = nil
        }
        self.ecopontoID = ecopontoID
        selectedIssue = issue
    }

    /// Begins a send. Returns nil when one is already in progress or this ecoponto has no choice.
    public mutating func beginSending(for ecopontoID: String) -> CommunityIssueKind? {
        guard !isSubmitting, self.ecopontoID == ecopontoID, let selectedIssue else { return nil }
        isSubmitting = true
        failureMessage = nil
        return selectedIssue
    }

    public mutating func finishFailure(_ message: String) {
        guard isSubmitting else { return }
        isSubmitting = false
        failureMessage = message
    }

    public mutating func finishSuccess() {
        isSubmitting = false
        failureMessage = nil
        selectedIssue = nil
        ecopontoID = nil
    }
}

/// Collapses overlapping submits of the same ecoponto and issue into one request.
public actor IssueReportGate {
    private struct Flight {
        var task: Task<CommunityEvent, Error>
        var waiters: Int
    }

    private var inFlight: [IssueReportKey: Flight] = [:]

    public init() {}

    public func inflightWaiters(for key: IssueReportKey) -> Int {
        inFlight[key]?.waiters ?? 0
    }

    public func submit(
        _ request: IssueSubmissionRequest,
        send: @escaping @Sendable (IssueSubmissionRequest) async throws -> CommunityEvent
    ) async throws -> CommunityEvent {
        let key = IssueReportKey(ecopontoID: request.ecopontoID, issue: request.issue)
        if var existing = inFlight[key] {
            existing.waiters += 1
            inFlight[key] = existing
            return try await existing.task.value
        }
        let task = Task { try await send(request) }
        inFlight[key] = Flight(task: task, waiters: 1)
        defer { inFlight[key] = nil }
        return try await task.value
    }
}
