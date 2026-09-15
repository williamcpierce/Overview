/* CaptureTests.swift — Capture ownership, retry, suspension, and frame-state coverage. */
import Foundation
import Testing
@testable import OverviewCore

@MainActor
private final class FakeSession: CaptureSession {
    typealias Request = Int
    typealias Frame = Int
    enum Failure: Error { case startup, denied, terminal }
    var starts: [Int] = []
    var stops = 0
    var updates: [Int] = []
    var failure: Failure?
    var startupGate: CheckedContinuation<Void, Never>?
    var blockStartup = false
    var continuation: AsyncThrowingStream<SessionEvent<Int>, Error>.Continuation?
    var active = 0
    var maxActive = 0
    func start(_ request: Int) async throws -> AsyncThrowingStream<SessionEvent<Int>, Error> {
        starts.append(request)
        if blockStartup { await withCheckedContinuation { startupGate = $0 } }
        if let failure { throw failure }
        active += 1; maxActive = max(maxActive, active)
        let pair = AsyncThrowingStream<SessionEvent<Int>, Error>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation = pair.continuation
        return pair.stream
    }
    func stop() async { stops += 1; active = 0; continuation?.finish(); continuation = nil }
    func update(_ request: Int) async throws { updates.append(request) }
}

@Suite @MainActor
struct CaptureTests {
    private func wait(_ condition: () -> Bool) async {
        for _ in 0..<1000 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        Issue.record("Timed out waiting for capture state")
    }
    private func classify(_ error: Error) -> CaptureFailureKind {
        switch error {
        case FakeSession.Failure.denied: return .permission
        case FakeSession.Failure.terminal: return .terminal
        default: return .transient
        }
    }

    @Test func startupIsAwaitedAndStopDuringStartupCleansUp() async {
        let session = FakeSession(); session.blockStartup = true
        let life = CaptureLifecycle(session: session, classify: classify)
        life.start(1)
        await wait { session.startupGate != nil }
        #expect(life.state == .starting)
        let stopping = Task { await life.stop() }
        await Task.yield()
        session.startupGate?.resume(); session.startupGate = nil
        await stopping.value
        #expect(life.state == .idle)
        #expect(session.active == 0)
        #expect(life.frame == nil)
    }

    @Test func concurrentReplacementNeverOverlapsStreams() async {
        let session = FakeSession()
        let life = CaptureLifecycle(session: session, classify: classify)
        life.start(1); life.start(2); life.start(3)
        await wait { life.state == .running }
        #expect(session.starts.last == 3)
        #expect(session.maxActive == 1)
        await life.stop()
    }

    @Test func failureRetriesExactlyOneTwoFourSeconds() async {
        let session = FakeSession(); session.failure = .startup
        var delays: [UInt64] = []
        let life = CaptureLifecycle(session: session, classify: classify, sleep: { delays.append($0) })
        life.start(1)
        await wait { if case .failed = life.state { return true }; return false }
        #expect(session.starts.count == 4)
        #expect(delays == [1_000_000_000, 2_000_000_000, 4_000_000_000])
        #expect(session.active == 0)
        #expect(session.stops >= 4)
    }

    @Test func permissionAndTerminalFailuresDoNotRetry() async {
        for failure in [FakeSession.Failure.denied, .terminal] {
            let session = FakeSession(); session.failure = failure
            let life = CaptureLifecycle(session: session, classify: classify)
            life.start(1)
            await wait { life.state != .starting }
            #expect(session.starts.count == 1)
            if failure == .denied { #expect(life.state == .permissionRequired) }
            else { if case .failed = life.state {} else { Issue.record("Expected failure state") } }
        }
    }

    @Test func explicitStopCancelsPendingRecovery() async {
        let session = FakeSession(); session.failure = .startup
        let life = CaptureLifecycle(session: session, classify: classify)
        life.start(1)
        await wait { life.state == .reconnecting }
        await life.stop()
        #expect(session.starts.count == 1)
        #expect(life.state == .idle)
        life.setSuspended(true); life.setSuspended(false)
        await Task.yield()
        #expect(life.state == .idle)
    }

    @Test func inactiveFramesAreClearedAndActiveCanResume() async {
        let session = FakeSession()
        let life = CaptureLifecycle(session: session, classify: classify)
        life.start(1)
        await wait { life.state == .running }
        session.continuation?.yield(.frame(42))
        await wait { life.frame == 42 }
        session.continuation?.yield(.inactive)
        await wait { life.state == .paused }
        #expect(life.frame == nil)
        session.continuation?.yield(.frame(43))
        await wait { life.frame == 43 }
        await life.stop()
    }

    @Test func suspensionReleasesAndResumesOneStream() async {
        let session = FakeSession()
        let life = CaptureLifecycle(session: session, classify: classify)
        life.start(1)
        await wait { session.active == 1 }
        life.setSuspended(true)
        await wait { session.active == 0 }
        #expect(life.state == .paused)
        life.setSuspended(false)
        await wait { session.active == 1 }
        #expect(session.starts.count == 2)
        await life.stop()
    }

    @Test func configurationUpdatesUseCurrentRequest() async {
        let session = FakeSession()
        let life = CaptureLifecycle(session: session, classify: classify)
        life.start(1)
        await wait { life.state == .running }
        await life.update(2)
        #expect(session.updates == [2])
        life.setSuspended(true)
        await wait { session.active == 0 }
        life.setSuspended(false)
        await wait { life.state == .running }
        #expect(session.starts.last == 2)
        await life.stop()
    }

    @Test func recoveryActuallyRestartsAndCanReceiveFrames() async {
        let session = FakeSession()
        let life = CaptureLifecycle(session: session, classify: classify, sleep: { _ in })
        life.start(1)
        await wait { life.state == .running }
        session.continuation?.finish(throwing: FakeSession.Failure.startup)
        await wait { session.starts.count == 2 && life.state == .running }
        session.continuation?.yield(.frame(99))
        await wait { life.frame == 99 }
        #expect(session.maxActive == 1)
        await life.stop()
    }

    @Test func queueSerializesAcrossSuspension() async throws {
        let queue = SessionOperationQueue()
        var order: [Int] = []
        let first = Task { try await queue.perform {
            order.append(1); try await Task.sleep(nanoseconds: 10_000_000); order.append(2)
        } }
        await Task.yield()
        let second = Task { try await queue.perform { order.append(3) } }
        try await first.value; try await second.value
        #expect(order == [1, 2, 3])
    }
}
