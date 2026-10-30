import Foundation
import ReciclarCore

func runReportChecks() async -> [String] {
    var failures: [String] = []
    func check(_ value: Bool, _ message: String) {
        if !value { failures.append(message) }
    }

    let wire = CommunityIssueKind.allCases.map(\.wireValue)
    check(wire == ["litter_outside_containers", "vandalized"], "server accepts exactly two issue names")
    check(Set(wire) == IssueReportPolicy.serverWireValues, "wire values match the server catalog")
    check(
        CommunityIssueKind.allCases.map(\.portugueseLabel) == ["Lixo fora dos contentores", "Vandalizado"],
        "issue choices use the pt-PT labels"
    )
    check(CommunityIssueKind(wireValue: "full") == nil, "full is not a reportable issue")
    check(CommunityIssueKind(wireValue: "empty") == nil, "empty is not a reportable issue")
    check(CommunityIssueKind.allCases.allSatisfy { !$0.reportChoiceAccessibilityHint.isEmpty }, "choices have VoiceOver hints")

    let now = Date(timeIntervalSince1970: 1_789_000_000)
    let origin = Coordinate(latitude: 41.15, longitude: -8.61)
    let metersPerDegree = 6_371_000.0 * Double.pi / 180
    let onSite = Coordinate(latitude: origin.latitude + (50 / metersPerDegree), longitude: origin.longitude)
    let beyond = Coordinate(latitude: origin.latitude + (150 / metersPerDegree), longitude: origin.longitude)
    func fix(at coordinate: Coordinate, accuracy: Double = 10, age: TimeInterval = 0) -> LocationFix {
        LocationFix(coordinate: coordinate, horizontalAccuracy: accuracy, timestamp: now.addingTimeInterval(-age))
    }

    let ready = IssueReportPolicy.availability(
        destination: origin, fix: fix(at: onSite), access: .authorized,
        isSubmitting: false, isCheckingPosition: false, now: now
    )
    check(ready.isEnabled && ready.explanation == nil, "a fix inside 100 m enables the report button")
    check(ready.accessibilityLabel == "Reportar problema", "VoiceOver names the report button")
    check(ready.accessibilityHint.contains("vandalizado"), "VoiceOver names the two issue types")
    check(Geodesy.distanceInMeters(from: origin, to: onSite) < 100, "the inside fixture is within 100 m")
    check(Geodesy.distanceInMeters(from: origin, to: beyond) > 100, "the outside fixture is beyond 100 m")

    let samePoint = IssueReportPolicy.availability(
        destination: origin, fix: fix(at: origin), access: .authorized,
        isSubmitting: false, isCheckingPosition: false, now: now
    )
    check(samePoint.isEnabled, "standing on the ecoponto enables the report button")

    let far = IssueReportPolicy.availability(
        destination: origin, fix: fix(at: beyond), access: .authorized,
        isSubmitting: false, isCheckingPosition: false, now: now
    )
    check(!far.isEnabled, "beyond 100 m disables the report button")
    check(far.explanation?.contains("100 metros") == true, "distance explanation states the 100 m limit")
    check(far.accessibilityHint == far.explanation, "VoiceOver reads why the button is disabled")
    check(far.canRequestPosition, "a far fix can be checked again")

    let stale = IssueReportPolicy.availability(
        destination: origin, fix: fix(at: origin, age: 61), access: .authorized,
        isSubmitting: false, isCheckingPosition: false, now: now
    )
    check(!stale.isEnabled && stale.explanation?.contains("desatualizada") == true, "a fix older than 60 s stays disabled")

    let freshEnough = IssueReportPolicy.availability(
        destination: origin, fix: fix(at: origin, age: 60), access: .authorized,
        isSubmitting: false, isCheckingPosition: false, now: now
    )
    check(freshEnough.isEnabled, "a fix aged exactly 60 s is still usable")

    let coarse = IssueReportPolicy.availability(
        destination: origin, fix: fix(at: origin, accuracy: 50.1), access: .authorized,
        isSubmitting: false, isCheckingPosition: false, now: now
    )
    check(!coarse.isEnabled && coarse.explanation?.contains("precisão") == true, "accuracy above 50 m stays disabled")

    let precise = IssueReportPolicy.availability(
        destination: origin, fix: fix(at: origin, accuracy: 50), access: .authorized,
        isSubmitting: false, isCheckingPosition: false, now: now
    )
    check(precise.isEnabled, "accuracy of exactly 50 m is usable")

    let denied = IssueReportPolicy.availability(
        destination: origin, fix: fix(at: origin), access: .denied,
        isSubmitting: false, isCheckingPosition: false, now: now
    )
    check(!denied.isEnabled && denied.canRequestPosition == false, "denied location stays disabled")
    check(denied.explanation?.contains("Definições") == true, "denied location explains how to turn it on")

    let unknown = IssueReportPolicy.availability(
        destination: origin, fix: nil, access: .notDetermined,
        isSubmitting: false, isCheckingPosition: false, now: now
    )
    check(!unknown.isEnabled && unknown.canRequestPosition, "missing permission offers a location check")

    let checking = IssueReportPolicy.availability(
        destination: origin, fix: nil, access: .authorized,
        isSubmitting: false, isCheckingPosition: true, now: now
    )
    check(!checking.isEnabled && checking.canRequestPosition == false, "a position check does not stack another request")
    check(checking.explanation?.contains("A obter") == true, "a position check explains the wait")

    let sending = IssueReportPolicy.availability(
        destination: origin, fix: fix(at: origin), access: .authorized,
        isSubmitting: true, isCheckingPosition: false, now: now
    )
    check(!sending.isEnabled && sending.accessibilityHint.contains("Aguarda"), "sending disables the button and says so")

    var draft = IssueReportDraft()
    draft.select(.vandalised, for: "eco-1")
    check(draft.beginSending(for: "eco-1") == .vandalised, "selected issue can be sent")
    check(draft.isSubmitting && draft.beginSending(for: "eco-1") == nil, "a second send is ignored while the first is in flight")
    check(draft.selectedIssue == .vandalised, "the choice stays put while sending")
    draft.select(.rubbishOutsideContainers, for: "eco-1")
    check(draft.selectedIssue == .vandalised, "the choice cannot change while sending")
    draft.finishFailure(IssueReportPolicy.failureFallback)
    check(!draft.isSubmitting && draft.selectedIssue == .vandalised, "failure keeps the selected issue")
    check(draft.failureMessage == IssueReportPolicy.failureFallback, "failure keeps a retry message")
    check(draft.sendButtonTitle == "Tentar novamente", "failure offers retry")
    check(draft.sendButtonAccessibilityHint.contains("mesma escolha"), "VoiceOver describes the retry")
    check(draft.beginSending(for: "eco-1") == .vandalised, "retry uses the same choice")
    draft.finishSuccess()
    check(draft.selectedIssue == nil && !draft.isSubmitting, "success clears the draft")

    var other = IssueReportDraft()
    other.select(.rubbishOutsideContainers, for: "eco-2")
    check(other.beginSending(for: "eco-1") == nil, "a choice for another ecoponto is not sent")
    check(other.sendButtonAccessibilityHint.contains("Escolhe primeiro") == false, "a selected choice is not described as empty")
    let empty = IssueReportDraft()
    check(empty.sendButtonAccessibilityHint.contains("Escolhe primeiro"), "VoiceOver asks for a choice before sending")

    let gate = IssueReportGate()
    let request = IssueSubmissionRequest(ecopontoID: "eco-1", issue: .vandalised)
    let event = CommunityEvent(id: "event-1", ecopontoID: "eco-1", issue: .vandalised, kind: .report, serverTimestamp: now)
    let hold = ReportSendHold()
    let key = IssueReportKey(ecopontoID: "eco-1", issue: .vandalised)

    async let first = gate.submit(request) { _ in
        await hold.enter()
        return event
    }
    await hold.waitUntilEntered()
    check(await gate.inflightWaiters(for: key) == 1, "the first send occupies the ecoponto and issue")
    async let second = gate.submit(request) { _ in
        await hold.markExtra()
        return CommunityEvent(id: "event-2", ecopontoID: "eco-1", issue: .vandalised, kind: .report, serverTimestamp: now)
    }
    let joined = await waitUntil { await gate.inflightWaiters(for: key) == 2 }
    check(joined, "the overlapping send waits on the same ecoponto and issue")
    await hold.release()
    do {
        let (left, right) = try await (first, second)
        check(left.id == event.id && right.id == event.id, "overlapping sends share one confirmed event")
        check(await hold.extraSends == 0, "the overlapping send does not post again")
        check(await gate.inflightWaiters(for: key) == 0, "a finished send leaves the gate clear")
    } catch {
        failures.append("overlapping send: \(error)")
    }

    let otherIssue = IssueSubmissionRequest(ecopontoID: "eco-1", issue: .rubbishOutsideContainers)
    let counter = ReportSendCounter()
    async let glass = gate.submit(request) { _ in
        await counter.bump()
        return event
    }
    async let litter = gate.submit(otherIssue) { _ in
        await counter.bump()
        return CommunityEvent(id: "event-3", ecopontoID: "eco-1", issue: .rubbishOutsideContainers, kind: .report, serverTimestamp: now)
    }
    _ = try? await (glass, litter)
    check(await counter.value == 2, "a different issue on the same ecoponto is its own report")

    let failing = IssueReportGate()
    do {
        _ = try await failing.submit(request) { _ in throw ReciclarAPIError.unavailable }
        failures.append("a failed send should throw")
    } catch {
        check((error as? ReciclarAPIError) == .unavailable, "a failed send surfaces the error")
    }
    check(await failing.inflightWaiters(for: key) == 0, "failure clears the gate so retry can post")
    do {
        let retried = try await failing.submit(request) { _ in event }
        check(retried.id == event.id, "retry after failure posts again")
    } catch {
        failures.append("retry after failure: \(error)")
    }

    let client = MockReciclarClient(clock: { now })
    let repo = AreaRepository(client: client, store: InMemorySnapshotStore())
    let slow = ReportSendHold()
    await client.setSubmitDelay { await slow.enter() }
    let repoRequest = IssueSubmissionRequest(ecopontoID: "one", issue: .vandalised)
    async let repoFirst = repo.submitReport(repoRequest)
    await slow.waitUntilEntered()
    async let repoSecond = repo.submitReport(repoRequest)
    let repoJoined = await waitUntil { await repo.inflightReportWaiters(repoRequest) == 2 }
    let submitCalls = await client.submitCalls
    check(repoJoined && submitCalls == 1, "the repository posts one report for one ecoponto and issue")
    await slow.release()
    do {
        _ = try await (repoFirst, repoSecond)
        let stored = await repo.currentSnapshot().communityEvents.filter { $0.issue == .vandalised && $0.kind == .report }
        check(stored.count == 1, "overlapping repository sends store one event")
    } catch {
        failures.append("repository dedupe: \(error)")
    }

    return failures
}

private func waitUntil(_ condition: () async -> Bool) async -> Bool {
    for _ in 0..<200 {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return false
}

private actor ReportSendHold {
    private var entered = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
    private var released = false
    private(set) var extraSends = 0

    func enter() async {
        entered = true
        let waiting = entryWaiters
        entryWaiters.removeAll()
        waiting.forEach { $0.resume() }
        if released { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func release() {
        released = true
        let waiting = releaseWaiters
        releaseWaiters.removeAll()
        waiting.forEach { $0.resume() }
    }

    func markExtra() {
        extraSends += 1
    }
}

private actor ReportSendCounter {
    private(set) var value = 0
    func bump() { value += 1 }
}
