/* Core/SourceIdentity.swift — Persistent matching never stores process or window IDs. */
import Foundation

struct SourceIdentity: Codable, Equatable, Hashable {
    var bundleIdentifier: String
    var windowTitle: String
    var label: String?

    /// Matching ignores optional user labels.
    func matchesClient(_ other: SourceIdentity) -> Bool {
        bundleIdentifier == other.bundleIdentifier && windowTitle == other.windowTitle
    }
}

enum SourceResolution: Equatable { case missing, unique(Int), ambiguous }

enum SourceResolver {
    static func resolve(_ identity: SourceIdentity, among candidates: [SourceIdentity]) -> SourceResolution {
        let matches = candidates.indices.filter { candidates[$0].matchesClient(identity) }
        if matches.count == 1 { return .unique(matches[0]) }
        return matches.isEmpty ? .missing : .ambiguous
    }

    static func cycle<T: Equatable>(_ items: [T], after current: T?) -> [T] {
        guard !items.isEmpty, let current, let index = items.firstIndex(of: current) else { return items }
        return Array(items.dropFirst(index + 1)) + Array(items.prefix(index + 1))
    }
}

/// Pure display rules for a preview source group.
enum SourceGroupSelection {
    /// Multi-source groups always swap; single-source windows honor the explicit hide flag.
    static func swapsWhenFocused(sourceCount: Int, hideWhenFocused: Bool) -> Bool {
        sourceCount > 1 || hideWhenFocused
    }

    /// Identity to capture/show, or `nil` when the preview should hide.
    static func displayCandidate(
        sources: [SourceIdentity],
        focused: SourceIdentity?,
        hideWhenFocused: Bool
    ) -> SourceIdentity? {
        guard !sources.isEmpty else { return nil }
        guard swapsWhenFocused(sourceCount: sources.count, hideWhenFocused: hideWhenFocused) else {
            return sources.first
        }
        guard let focused else { return sources.first }
        return sources.first { !$0.matchesClient(focused) }
    }
}
