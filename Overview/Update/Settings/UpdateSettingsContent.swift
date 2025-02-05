/*
 Update/Settings/UpdateSettingsContent.swift
 Overview

 Created by William Pierce on 2/4/25.

 Provides help content for update-related settings.
*/

extension InfoPopoverContent {
    static let updates = InfoPopoverContent(
        title: "Software Updates",
        sections: [
            Section(
                title: "Automatic Updates",
                text: "Automatically download and install application updates."
            ),
            Section(
                title: "Update Channel",
                text: "Choose between stable releases or beta versions."
            ),
        ],
        isWarning: false
    )
}
