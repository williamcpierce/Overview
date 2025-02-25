/*
 Profile/Settings/ProfileSettingsContent.swift
 Overview

 Created by William Pierce on 2/24/25.

 Provides help content for window profile-related settings.
*/

extension InfoPopoverContent {
    static let windowProfiles = InfoPopoverContent(
        title: "Window Layout Profiles",
        sections: [
            Section(
                title: "Overview",
                text: "Profiles allow you to save and restore different window arrangements"
            ),
            Section(
                title: "Create Profile",
                text: "Save your current window layout as a named profile"
            ),
            Section(
                title: "Apply Profile",
                text: "Load a saved profile, replacing the current window arrangement"
            ),
            Section(
                title: "Update Profile",
                text: "Update a profile with your current window layout"
            ),
            Section(
                title: "Auto-apply on Launch",
                text: "Automatically apply the selected profile when Overview starts"
            ),
        ],
        isWarning: false
    )
}
