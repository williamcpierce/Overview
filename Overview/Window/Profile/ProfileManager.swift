/*
 Window/Profile/ProfileManager.swift
 Overview

 Created by William Pierce on 2/24/25.

 Manages window layout profile storage, retrieval, and application.
*/

import SwiftUI

@MainActor
final class ProfileManager: ObservableObject {
    // Dependencies
    private let windowStorage: WindowStorage
    private let logger = AppLogger.interface
    private let defaults: UserDefaults

    // Published State
    @Published var profiles: [Profile] = []
    @Published var launchProfileId: UUID? = nil

    @AppStorage(ProfileSettingsKeys.applyProfileOnLaunch)
    private var applyProfileOnLaunch = ProfileSettingsKeys.defaults.applyProfileOnLaunch

    // Singleton
    static let shared = ProfileManager()

    private init(
        windowStorage: WindowStorage = WindowStorage.shared,
        defaults: UserDefaults = .standard
    ) {
        self.windowStorage = windowStorage
        self.defaults = defaults

        self.profiles = loadProfiles()

        if let launchProfileIdString = defaults.string(forKey: ProfileSettingsKeys.launchProfileId),
            let launchProfileId = UUID(uuidString: launchProfileIdString)
        {
            self.launchProfileId = launchProfileId
        }

        logger.debug("Profile manager initialized with \(profiles.count) profiles")
    }

    // MARK: - Profile Management

    func createProfile(name: String) -> Profile {
        let currentWindowStates = windowStorage.collectCurrentWindowStates()
        let profile = Profile(name: name, windows: currentWindowStates)

        profiles.append(profile)
        saveProfiles()

        logger.info("Created new profile '\(name)' with \(currentWindowStates.count) windows")
        return profile
    }

    func updateProfile(id: UUID, name: String? = nil) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            logger.warning("Attempted to update non-existent profile: \(id)")
            return
        }

        var profile = profiles[index]

        if let name = name {
            profile.update(name: name)
        } else {
            let currentWindowStates = windowStorage.collectCurrentWindowStates()
            profile.update(windows: currentWindowStates)
            logger.info(
                "Updated profile '\(profile.name)' with \(currentWindowStates.count) windows")
        }

        profiles[index] = profile
        saveProfiles()
    }

    func deleteProfile(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else {
            logger.warning("Attempted to delete non-existent profile: \(id)")
            return
        }

        let profileName = profiles.first(where: { $0.id == id })?.name ?? "Unknown"
        profiles.removeAll(where: { $0.id == id })

        if launchProfileId == id {
            launchProfileId = nil
            defaults.removeObject(forKey: ProfileSettingsKeys.launchProfileId)
        }

        saveProfiles()
        logger.info("Deleted profile '\(profileName)'")
    }

    func setLaunchProfile(id: UUID?) {
        launchProfileId = id

        if let id = id {
            defaults.set(id.uuidString, forKey: ProfileSettingsKeys.launchProfileId)
            logger.info("Set launch profile: \(id)")
        } else {
            defaults.removeObject(forKey: ProfileSettingsKeys.launchProfileId)
            logger.info("Cleared launch profile")
        }
    }

    func getActiveProfile() -> Profile? {
        guard let launchProfileId = launchProfileId else {
            return nil
        }

        return profiles.first(where: { $0.id == launchProfileId })
    }

    func applyProfile(_ profile: Profile, using handler: (WindowStorage.WindowState) -> Void)
    {
        logger.info("Applying profile '\(profile.name)' with \(profile.windows.count) windows")

        profile.windows.forEach { windowState in
            handler(windowState)
        }
    }

    func shouldApplyProfileOnLaunch() -> Bool {
        return applyProfileOnLaunch && launchProfileId != nil && getActiveProfile() != nil
    }

    // MARK: - Private Storage Methods

    private func saveProfiles() {
        do {
            let encodedProfiles = try JSONEncoder().encode(profiles)
            defaults.set(encodedProfiles, forKey: ProfileSettingsKeys.profiles)
            logger.debug("Saved \(profiles.count) profiles to user defaults")
        } catch {
            logger.logError(error, context: "Failed to encode profiles")
        }
    }

    private func loadProfiles() -> [Profile] {
        guard let data = defaults.data(forKey: ProfileSettingsKeys.profiles) else {
            logger.debug("No saved profiles found")
            return []
        }

        do {
            let decodedProfiles = try JSONDecoder().decode([Profile].self, from: data)
            logger.info("Loaded \(decodedProfiles.count) profiles")
            return decodedProfiles
        } catch {
            logger.logError(error, context: "Failed to decode profiles")
            return []
        }
    }
}
