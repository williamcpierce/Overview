/*
 Profile/Settings/ProfileSettingsKeys.swift
 Overview

 Created by William Pierce on 2/24/25.
*/

import Foundation

enum ProfileSettingsKeys {
    static let profiles: String = "storedProfiles"
    static let activeProfileId: String = "activeProfileId"
    static let applyProfileOnLaunch: String = "applyProfileOnLaunch"

    static let defaults = Defaults()

    struct Defaults {
        let applyProfileOnLaunch: Bool = false
    }
}
