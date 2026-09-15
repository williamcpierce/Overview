/* Core/EveSourceMatcher.swift
 Overview Dev hard-limits preview pickers to CCP EVE Online clients.
 Bundle ID prefix is preferred; known app names are a fallback.
*/
import Foundation

enum EveSourceMatcher {
    private static let ccpBundlePrefix = "com.ccpgames."
    private static let allowedApplicationNames: Set<String> = [
        "eve online",
        "eve launcher",
    ]

    /// Returns true when the process is an EVE Online / CCP launcher client.
    static func isAllowed(bundleID: String?, applicationName: String?) -> Bool {
        if let bundleID, bundleID.lowercased().hasPrefix(ccpBundlePrefix) {
            return true
        }
        if let applicationName,
            allowedApplicationNames.contains(applicationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        {
            return true
        }
        return false
    }
}
