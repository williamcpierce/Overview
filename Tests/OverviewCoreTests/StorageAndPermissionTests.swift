/* StorageAndPermissionTests.swift — Persistent identities, migration, geometry, groups, and permission coverage. */
import Foundation
import Testing
@testable import OverviewCore

@Suite struct StorageTests {
    @Test func uniqueMissingDuplicateAndRenamedMatches() {
        let identity = SourceIdentity(bundleIdentifier: "eve", windowTitle: "EVE - Pilot")
        #expect(SourceResolver.resolve(identity, among: []) == .missing)
        #expect(SourceResolver.resolve(identity, among: [identity]) == .unique(0))
        #expect(SourceResolver.resolve(identity, among: [identity, identity]) == .ambiguous)
        #expect(SourceResolver.resolve(identity, among: [.init(bundleIdentifier: "eve", windowTitle: "EVE - Other")]) == .missing)
        #expect(SourceResolver.resolve(identity, among: [.init(bundleIdentifier: "other", windowTitle: identity.windowTitle)]) == .missing)
    }
    @Test func labelDoesNotChangeIdentityMatch() {
        let identity = SourceIdentity(bundleIdentifier: "eve", windowTitle: "Pilot", label: "Scout")
        #expect(SourceResolver.resolve(identity, among: [.init(bundleIdentifier: "eve", windowTitle: "Pilot")]) == .unique(0))
    }
    @Test func cyclingWrapsAndIncludesEveryCandidateOnce() {
        #expect(SourceResolver.cycle(["a", "b", "c"], after: "b") == ["c", "a", "b"])
        #expect(SourceResolver.cycle(["a"], after: "a") == ["a"])
        #expect(SourceResolver.cycle([String](), after: nil).isEmpty)
        let available: Set<String> = ["a"]
        #expect(SourceResolver.cycle(["a", "b", "c"], after: "a").first(where: available.contains) == "a")
    }
    @Test func legacyGeometrySurvivesMigrationAndIDsStayStable() throws {
        let data = Data("[{\"x\":10,\"y\":20,\"width\":300,\"height\":200}]".utf8)
        let result = try SavedCollection<Window>.decode(data)
        #expect(result.legacy)
        #expect(result.items[0].frame == CGRect(x: 10, y: 20, width: 300, height: 200))
        #expect(result.items[0].sources.isEmpty)
        #expect(result.items[0].source == nil)
        let encoded = try JSONEncoder().encode(SavedCollection(result.items))
        let restored = try SavedCollection<Window>.decode(encoded)
        #expect(!restored.legacy)
        #expect(restored.items == result.items)
    }
    @Test func legacySingularSourceBecomesOneMemberGroup() throws {
        let data = Data("""
        {"version":1,"items":[{"id":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","x":1,"y":2,"width":300,"height":200,"source":{"bundleIdentifier":"eve","windowTitle":"Pilot","label":"Scout"},"displayIdentifier":"display"}]}
        """.utf8)
        let items = try SavedCollection<Window>.decode(data).items
        #expect(items[0].sources.count == 1)
        #expect(items[0].sources[0].windowTitle == "Pilot")
        #expect(items[0].hideWhenFocused == false)
    }
    @Test func sourceGroupAndHideWhenFocusedRoundTrip() throws {
        let main = SourceIdentity(bundleIdentifier: "eve", windowTitle: "Main")
        let scout = SourceIdentity(bundleIdentifier: "eve", windowTitle: "Scout", label: "Scout")
        let window = Window(
            frame: CGRect(x: 1, y: 2, width: 300, height: 200),
            sources: [main, scout],
            hideWhenFocused: true,
            displayIdentifier: "display"
        )
        let data = try JSONEncoder().encode(SavedCollection([window]))
        #expect(try SavedCollection<Window>.decode(data).items == [window])
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("sources"))
        #expect(json.contains("hideWhenFocused"))
        #expect(!json.contains("processID"))
        #expect(!json.contains("windowID"))
    }
    @Test func sourceAssignmentAndDisplayRoundTrip() throws {
        let window = Window(
            frame: CGRect(x: 1, y: 2, width: 300, height: 200),
            displayIdentifier: "display",
            source: .init(bundleIdentifier: "eve", windowTitle: "Pilot", label: "Scout")
        )
        let data = try JSONEncoder().encode(SavedCollection([window]))
        #expect(try SavedCollection<Window>.decode(data).items == [window])
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("processID"))
        #expect(!json.contains("windowID"))
    }
    @Test func corruptInvalidAndFutureDataAreRejected() {
        for value in ["broken", "[{\"x\":0,\"y\":0,\"width\":-1,\"height\":20}]", "{\"version\":99,\"items\":[]}"] {
            #expect(throws: (any Error).self) { try SavedCollection<Window>.decode(Data(value.utf8)) }
        }
    }
    @Test func disconnectedDisplayClampsEntirePreview() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let clamped = PreviewGeometry.clamp(CGRect(x: 3000, y: -500, width: 1900, height: 1200), to: visible)
        #expect(clamped == visible)
        let negativeScreen = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        #expect(negativeScreen.contains(PreviewGeometry.clamp(CGRect(x: -50, y: 900, width: 400, height: 300), to: negativeScreen)))
    }
    @Test func captureUsesBackingPixelsWithoutUpscalingSource() {
        #expect(PreviewGeometry.captureSize(source: CGSize(width: 1920, height: 1080), scale: 2,
                                           preview: CGSize(width: 640, height: 360)) == CGSize(width: 640, height: 360))
        #expect(PreviewGeometry.captureSize(source: CGSize(width: 100, height: 50), scale: 2,
                                           preview: CGSize(width: 1000, height: 500)) == CGSize(width: 200, height: 100))
    }
    @Test func groupShowsInactiveMemberAndHidesWhenOnlyFocusedRemains() {
        let main = SourceIdentity(bundleIdentifier: "eve", windowTitle: "Main")
        let scout = SourceIdentity(bundleIdentifier: "eve", windowTitle: "Scout")
        let titan = SourceIdentity(bundleIdentifier: "eve", windowTitle: "Titan")

        #expect(SourceGroupSelection.displayCandidate(sources: [main, scout], focused: main, hideWhenFocused: false) == scout)
        #expect(SourceGroupSelection.displayCandidate(sources: [main, scout], focused: scout, hideWhenFocused: false) == main)
        #expect(SourceGroupSelection.displayCandidate(sources: [main], focused: main, hideWhenFocused: true) == nil)
        #expect(SourceGroupSelection.displayCandidate(sources: [titan], focused: main, hideWhenFocused: false) == titan)
        #expect(SourceGroupSelection.displayCandidate(sources: [main, scout], focused: nil, hideWhenFocused: false) == main)
        #expect(SourceGroupSelection.swapsWhenFocused(sourceCount: 2, hideWhenFocused: false))
        #expect(!SourceGroupSelection.swapsWhenFocused(sourceCount: 1, hideWhenFocused: false))
        #expect(SourceGroupSelection.swapsWhenFocused(sourceCount: 1, hideWhenFocused: true))
        // Optimistic local focus still selects the other member even when OS focus is missing.
        #expect(SourceGroupSelection.displayCandidate(sources: [main, scout], focused: main, hideWhenFocused: true)?.windowTitle == "Scout")
    }
}

@Suite @MainActor struct PermissionTests {
    @Test func concurrentCallersWaitForSameGrant() async {
        var granted = false
        var requests = 0
        var continuation: CheckedContinuation<Void, Never>?
        let gate = PermissionGate(check: { granted }, request: {
            requests += 1
            await withCheckedContinuation { continuation = $0 }
        })
        let first = Task { await gate.ensure() }
        let second = Task { await gate.ensure() }
        while continuation == nil { await Task.yield() }
        #expect(requests == 1)
        granted = true
        continuation?.resume()
        let firstResult = await first.value
        let secondResult = await second.value
        #expect(firstResult && secondResult)
    }
    @Test func denialAndRevocationAreRechecked() async {
        var granted = true
        var requests = 0
        let gate = PermissionGate(check: { granted }, request: { requests += 1 })
        let initial = await gate.ensure()
        #expect(initial && requests == 0)
        granted = false
        let revoked = await gate.ensure()
        #expect(!revoked && requests == 1)
        granted = true
        let restored = await gate.ensure()
        #expect(restored && requests == 1)
    }
}
