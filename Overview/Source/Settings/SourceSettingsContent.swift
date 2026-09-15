/*
 Source/Settings/SourceSettingsContent.swift
 Overview

 Info copy for the Sources settings tab (EVE-only picker policy).
*/

extension InfoPopoverContent {
    static let sourceFilter = InfoPopoverContent(
        title: "EVE Online Sources",
        sections: [
            Section(
                title: "Summary",
                text:
                    "Overview Dev only lists EVE Online client windows. Matching uses CCP bundle identifiers (com.ccpgames.*) with EVE Online / EVE Launcher application names as a fallback."
            ),
            Section(
                title: "Why",
                text:
                    "This personal build is an EVE multi-client companion. Generic application filters are not used."
            ),
        ],
        isWarning: false
    )
}
