/* Core/PermissionGate.swift — Concurrent callers share one completed permission request. */
import Foundation

@MainActor
final class PermissionGate {
    private var pending: Task<Bool, Never>?
    private let check: () -> Bool
    private let request: () async -> Void

    init(check: @escaping () -> Bool, request: @escaping () async -> Void) {
        self.check = check
        self.request = request
    }

    func ensure() async -> Bool {
        if let pending { return await pending.value }
        if check() { return true }
        let task = Task { @MainActor in
            await request()
            return check()
        }
        pending = task
        let result = await task.value
        pending = nil
        return result
    }
}
