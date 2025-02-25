/*
 Window/Settings/ProfileSettingsTab.swift
 Overview

 Created by William Pierce on 2/24/25.
*/

import SwiftUI

struct ProfileSettingsTab: View {
    // Dependencies
    @ObservedObject private var profileManager = ProfileManager.shared
    @StateObject private var windowManager: WindowManager
    private let logger = AppLogger.settings

    // Private State
    @State private var showingProfileInfo: Bool = false
    @State private var newProfileName: String = ""
    @State private var showingApplyAlert: Bool = false
    @State private var showingUpdateAlert: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var profileToModify: Profile? = nil

    // Selected profile dropdown state
    @State private var launchProfileId: UUID? = nil

    init(windowManager: WindowManager) {
        self._windowManager = StateObject(wrappedValue: windowManager)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Window Layout Profiles")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .windowProfiles,
                        isPresented: $showingProfileInfo
                    )
                }
                .padding(.bottom, 4)

                profileListView

                HStack {
                    TextField("Profile name", text: $newProfileName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        if !newProfileName.isEmpty {
                            _ = windowManager.saveCurrentLayoutAsProfile(name: newProfileName)
                            newProfileName = ""
                        }
                    }
                    .disabled(newProfileName.isEmpty)
                }

                // Simplified dropdown for apply profile on launch
                HStack {
                    Text("Apply profile on launch")
                    Spacer()
                    Picker("", selection: $launchProfileId) {
                        Text("None").tag(nil as UUID?)
                        ForEach(profileManager.profiles) { profile in
                            Text(profile.name).tag(profile.id as UUID?)
                        }
                    }
                    .frame(width: 120)
                    .onChange(of: launchProfileId) { newValue in
                        profileManager.setLaunchProfile(id: newValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // Initialize the selected profile when the view appears
            launchProfileId = profileManager.launchProfileId
        }
        .alert("Apply Profile", isPresented: $showingApplyAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Apply") {
                if let profile = profileToModify {
                    windowManager.applyProfile(profile)
                }
                profileToModify = nil
            }
        } message: {
            if let profile = profileToModify {
                Text("Apply profile '\(profile.name)'? This will close all current windows.")
            } else {
                Text("Select a profile to apply")
            }
        }
        .alert("Update Profile", isPresented: $showingUpdateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Update") {
                if let profile = profileToModify {
                    profileManager.updateProfile(id: profile.id)
                }
                profileToModify = nil
            }
        } message: {
            if let profile = profileToModify {
                Text("Update profile '\(profile.name)' with current window layout?")
            } else {
                Text("Select a profile to update")
            }
        }
        .alert("Delete Profile", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let profile = profileToModify {
                    profileManager.deleteProfile(id: profile.id)
                }
                profileToModify = nil
            }
        } message: {
            if let profile = profileToModify {
                Text("Delete profile '\(profile.name)'? This cannot be undone.")
            } else {
                Text("Select a profile to delete")
            }
        }
    }

    private var profileListView: some View {
        VStack {
            List {
                if profileManager.profiles.isEmpty {
                    Text("No profiles saved")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(profileManager.profiles) { profile in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(profile.name)
                                }

                                Text("\(profile.windows.count) windows")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button {
                                profileToModify = profile
                                showingApplyAlert = true
                            } label: {
                                Image(systemName: "checkmark.arrow.trianglehead.counterclockwise")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Apply profile")

                            Button {
                                profileToModify = profile
                                showingUpdateAlert = true
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Update profile")

                            Button {
                                profileToModify = profile
                                showingDeleteAlert = true
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Delete profile")
                        }
                    }
                }
            }
        }
    }
}
