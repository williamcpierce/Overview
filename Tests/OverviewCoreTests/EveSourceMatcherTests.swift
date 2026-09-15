/* EveSourceMatcherTests.swift — EVE-only picker matching without constructing SCWindow. */
import Testing
@testable import OverviewCore

@Suite struct EveSourceMatcherTests {
    @Test func acceptsCCPBundleIDs() {
        #expect(EveSourceMatcher.isAllowed(bundleID: "com.ccpgames.evelauncher", applicationName: nil))
        #expect(EveSourceMatcher.isAllowed(bundleID: "com.ccpgames.something", applicationName: "Other"))
        #expect(EveSourceMatcher.isAllowed(bundleID: "COM.CCPGAMES.EVEONLINE", applicationName: nil))
    }

    @Test func acceptsKnownApplicationNamesWithoutBundle() {
        #expect(EveSourceMatcher.isAllowed(bundleID: nil, applicationName: "EVE Online"))
        #expect(EveSourceMatcher.isAllowed(bundleID: "com.unknown.app", applicationName: "EVE Launcher"))
        #expect(EveSourceMatcher.isAllowed(bundleID: nil, applicationName: "  eve online  "))
    }

    @Test func rejectsUnrelatedApps() {
        #expect(!EveSourceMatcher.isAllowed(bundleID: "com.apple.Safari", applicationName: "Safari"))
        #expect(!EveSourceMatcher.isAllowed(bundleID: "com.microsoft.VSCode", applicationName: "Code"))
        #expect(!EveSourceMatcher.isAllowed(bundleID: nil, applicationName: "Finder"))
        #expect(!EveSourceMatcher.isAllowed(bundleID: nil, applicationName: nil))
        #expect(!EveSourceMatcher.isAllowed(bundleID: "com.example.evehelper", applicationName: "Eve Helper"))
    }
}
