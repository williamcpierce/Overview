/*
 Update/Settings/UpdateSettingsKeys.swift
 Overview

 Created by William Pierce on 2/4/25.

 Defines storage keys for update-related settings.
*/

enum UpdateSettingsKeys {
    static let automaticUpdateChecks: String = "SUEnableAutomaticChecks"
    static let automaticDownloads: String = "SUAutomaticallyUpdate"
    static let betaUpdates: String = "SUFeedURL"

    static let defaults = Defaults()

    struct Defaults {
        let automaticUpdateChecks: Bool = true
        let automaticDownloads: Bool = false
        let betaUpdates: Bool = false

        let stableUpdateURL: String = "https://williamcpierce.github.io/Overview/appcast.xml"
        let betaUpdateURL: String = "https://williamcpierce.github.io/Overview/appcast-beta.xml"
    }
}
