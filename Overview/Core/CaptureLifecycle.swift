/*
 Core/CaptureLifecycle.swift
 Overview Dev

 Serializes capture ownership across cancellation, recovery, and source changes.
*/
import Combine
import Foundation

enum CaptureState: Equatable {
    case idle, starting, running, paused, reconnecting, permissionRequired
    case failed(String)

    var label: String {
        switch self {
        case .idle: return "Select a source"
        case .starting: return "Starting preview…"
        case .running: return "Live"
        case .paused: return "Paused"
        case .reconnecting: return "Reconnecting…"
        case .permissionRequired: return "Screen Recording permission required"
        case .failed(let reason): return reason
        }
    }
}

enum SessionEvent<Frame: Sendable>: Sendable {
    case frame(Frame), active, inactive
}

enum CaptureFailureKind { case transient, permission, terminal }

@MainActor
protocol CaptureSession: AnyObject {
    associatedtype Request
    associatedtype Frame: Sendable
    func start(_ request: Request) async throws -> AsyncThrowingStream<SessionEvent<Frame>, Error>
    func stop() async
    func update(_ request: Request) async throws
}

@MainActor
final class CaptureLifecycle<Session: CaptureSession>: ObservableObject {
    @Published private(set) var state: CaptureState = .idle
    @Published private(set) var frame: Session.Frame?
    private let session: Session
    private let classify: (Error) -> CaptureFailureKind
    private let sleep: (UInt64) async throws -> Void
    private var worker: Task<Void, Never>?
    private var generation = 0
    private var request: Session.Request?
    private var desired = false
    private var suspended = false

    init(session: Session,
         classify: @escaping (Error) -> CaptureFailureKind,
         sleep: @escaping (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }) {
        self.session = session
        self.classify = classify
        self.sleep = sleep
    }

    func start(_ request: Session.Request) {
        self.request = request
        desired = true
        replaceWorker()
    }

    func retry() {
        guard request != nil else { return }
        desired = true
        replaceWorker()
    }

    func stop() async {
        desired = false
        frame = nil
        state = .idle
        replaceWorker()
        await worker?.value
    }

    func setSuspended(_ value: Bool) {
        guard suspended != value else { return }
        suspended = value
        replaceWorker()
    }

    func update(_ request: Session.Request) async {
        self.request = request
        guard desired, !suspended, state == .running || state == .paused else { return }
        let token = generation
        do {
            try await session.update(request)
        } catch {
            guard token == generation else { return }
            replaceWorker()
        }
    }

    private func replaceWorker() {
        generation += 1
        let token = generation
        let previous = worker
        previous?.cancel()
        // Keep the last frame during start/reconnect so previews do not flash a blank material panel.
        state = desired ? (suspended ? .paused : .starting) : .idle
        if !desired { frame = nil }
        worker = Task { [weak self] in
            await previous?.value
            guard let self, token == self.generation else { return }
            await self.session.stop()
            guard !Task.isCancelled, token == self.generation,
                  self.desired, !self.suspended, let request = self.request else { return }
            await self.run(request, token: token)
        }
    }

    private func run(_ request: Session.Request, token: Int) async {
        var failures = 0
        while !Task.isCancelled, token == generation {
            do {
                let events = try await session.start(request)
                try Task.checkCancellation()
                guard token == generation else { break }
                state = .running
                for try await event in events {
                    try Task.checkCancellation()
                    guard token == generation else { break }
                    switch event {
                    case .frame(let value): frame = value; state = .running
                    case .active: state = .running
                    case .inactive: frame = nil; state = .paused
                    }
                }
                try Task.checkCancellation()
                // Unexpected EOF is a failure, not a successful live preview.
                throw SessionEnded()
            } catch {
                await session.stop()
                guard !Task.isCancelled, token == generation else { return }
                frame = nil
                switch classify(error) {
                case .permission: state = .permissionRequired; return
                case .terminal: state = .failed(error.localizedDescription); return
                case .transient:
                    guard failures < 3 else {
                        state = .failed("Preview disconnected. Retry to reconnect.")
                        return
                    }
                    state = .reconnecting
                    do { try await sleep(UInt64(1 << failures) * 1_000_000_000) }
                    catch { return }
                    failures += 1
                }
            }
        }
        await session.stop()
    }

    private struct SessionEnded: Error {}
}

/// Keeps framework operations ordered even when their async calls yield the main actor.
@MainActor
final class SessionOperationQueue {
    private var tail: Task<Void, Never>?

    func perform<T: Sendable>(_ operation: @escaping @MainActor () async throws -> T) async throws -> T {
        let previous = tail
        let task = Task { @MainActor in
            await previous?.value
            return try await operation()
        }
        tail = Task { _ = try? await task.value }
        return try await task.value
    }
}
