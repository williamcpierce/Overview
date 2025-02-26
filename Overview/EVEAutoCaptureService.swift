/*
 EVE/EveAutoCaptureService.swift
 Overview

 Created by William Pierce on 2/25/25.

 Provides automatic window creation and management for EVE Online client windows.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class EveAutoCaptureService {
    // Dependencies
    private let windowManager: WindowManager
    private let sourceManager: SourceManager
    private let logger = AppLogger.interface
    
    // Constants
    private let eveApplicationNames = ["EVE Online", "EVE", "eveonline"]
    private let eveBundleIds = ["com.ccpgames.eveonline", "com.ccpgames.eve-online"]
    private let eveTitlePrefixes = ["EVE - ", "EVE Online - "]
    private let storageKey = "EVECharacterWindowStates"
    
    // State
    private var observerId = UUID()
    private var activeCharacters: Set<String> = []
    private var characterStates: [String: WindowState] = [:]
    
    init(windowManager: WindowManager, sourceManager: SourceManager) {
        self.windowManager = windowManager
        self.sourceManager = sourceManager
        loadCharacterStates()
        setupObservers()
        logger.debug("EVE Auto Capture service initialized")
    }
    
    deinit {
        // Use Task to dispatch to the main actor for cleanup
        Task { @MainActor in
            SourceServices.shared.removeObserver(id: observerId)
        }
    }
    
    // MARK: - Observer Setup
    
    private func setupObservers() {
        logger.debug("Setting up EVE window observers")
        
        // Observe both focus and title changes to increase detection chances
        SourceServices.shared.addObserver(
            id: observerId,
            onFocusChanged: { [weak self] in
                Task { @MainActor in
                    await self?.handleSourceChanges()
                }
            },
            onTitleChanged: { [weak self] in
                Task { @MainActor in
                    await self?.handleSourceChanges()
                }
            }
        )
        
        // Also observe window closures to update our state
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.handleWindowWillClose(window)
        }
        
        // Perform an initial check for EVE windows
        Task { @MainActor in
            await handleSourceChanges()
        }
    }
    
    // Combined handler for focus and title changes
    private func handleSourceChanges() async {
        logger.debug("Handling EVE window source changes")
        await handleTitleChanged()
    }
    
    // MARK: - Window Title Handling
    
    private func handleTitleChanged() async {
        do {
            // Get all windows
            let allSources = try await sourceManager.getAvailableSources()
            
            // Find EVE Online windows by app name or bundle ID
            let eveWindows = allSources.filter { window in
                guard let app = window.owningApplication else { return false }
                
                let matchesAppName = eveApplicationNames.contains(where: {
                    app.applicationName.lowercased().contains($0.lowercased())
                })
                
                let matchesBundleId = eveBundleIds.contains(where: {
                    app.bundleIdentifier.lowercased() == $0.lowercased()
                })
                
                return matchesAppName || matchesBundleId
            }
            
            logger.debug("Found \(eveWindows.count) potential EVE windows")
            for window in eveWindows {
                logger.debug("Processing EVE window: \(window.title ?? "Untitled") from \(window.owningApplication?.applicationName ?? "Unknown")")
            }
            
            // Process each EVE window
            for window in eveWindows {
                guard let title = window.title else {
                    logger.debug("Skipping EVE window with no title")
                    continue
                }
                
                // Find the matching prefix, if any
                var characterName: String?
                for prefix in eveTitlePrefixes {
                    if title.hasPrefix(prefix) {
                        characterName = String(title.dropFirst(prefix.count))
                        break
                    }
                }
                
                // If no matching prefix, try other approaches
                if characterName == nil && title.contains(" - ") {
                    // Try to extract name from formats like "Character Name - EVE Online"
                    let components = title.components(separatedBy: " - ")
                    if components.count > 1 && !components[0].lowercased().contains("eve") {
                        characterName = components[0]
                    }
                }
                
                // Skip if we couldn't extract a character name
                guard let characterName = characterName, !characterName.isEmpty else {
                    logger.debug("Skipping EVE window: could not extract character name from title: \"\(title)\"")
                    continue
                }
                if !characterName.isEmpty && !activeCharacters.contains(characterName) {
                    // Create a preview window for this character
                    try createPreviewForCharacter(characterName: characterName)
                    activeCharacters.insert(characterName)
                    logger.info("Created auto-capture preview for EVE character: \(characterName)")
                }
            }
            
            // Check for removed windows with more robust title parsing
            let currentCharacterNames = Set(eveWindows.compactMap { window -> String? in
                guard let title = window.title else { return nil }
                
                // Try all title prefixes first
                for prefix in eveTitlePrefixes {
                    if title.hasPrefix(prefix) {
                        return String(title.dropFirst(prefix.count))
                    }
                }
                
                // Try alternative format (Character Name - EVE Online)
                if title.contains(" - ") {
                    let components = title.components(separatedBy: " - ")
                    if components.count > 1 && !components[0].lowercased().contains("eve") {
                        return components[0]
                    }
                }
                
                return nil
            })
            
            // Remove tracking for characters that no longer have windows
            let removedCharacters = activeCharacters.subtracting(currentCharacterNames)
            for characterName in removedCharacters {
                activeCharacters.remove(characterName)
                logger.debug("Removed tracking for EVE character: \(characterName)")
            }
        } catch {
            logger.logError(error, context: "Failed to process EVE windows")
        }
    }
    
    // MARK: - Preview Creation
    
    private func createPreviewForCharacter(characterName: String) throws {
        logger.debug("Creating preview for EVE character: \(characterName)")
        
        // Determine the frame to use
        let frame: NSRect?
        if let state = characterStates[characterName] {
            frame = state.frame
            logger.debug("Using saved frame for character \(characterName): x=\(state.x), y=\(state.y), width=\(state.width), height=\(state.height)")
        } else {
            frame = nil // Use default position
            logger.debug("No saved frame found for character \(characterName), using default position")
        }
        
        // Create the window
        try windowManager.createWindow(at: frame)
        
        logger.info("Created auto-capture preview for EVE character: \(characterName)")
        
        // TODO: In the future, automatically select the EVE window as the source
        // For now, this is manually done by the user
    }
    
    // MARK: - Window Closure Handling
    
    private func handleWindowWillClose(_ window: NSWindow) {
        // This is a basic implementation for the MVP
        // In the future, we'll need a more robust way to associate preview windows with EVE character windows
        
        // For now, we'll try to save window positions on app quit through the existing mechanism
        // The WindowManager's handleWindowsOnQuit() method will be called when the app terminates
    }
    
    // Helper method to save a window state for a character
    func saveWindowState(for characterName: String, frame: NSRect) {
        logger.debug("Saving window state for EVE character: \(characterName)")
        let state = WindowState(frame: frame)
        characterStates[characterName] = state
        saveCharacterStates()
    }
    
    // MARK: - State Persistence
    
    private func loadCharacterStates() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        
        do {
            let states = try JSONDecoder().decode([String: WindowState].self, from: data)
            characterStates = states
            logger.debug("Loaded \(states.count) EVE character window states")
        } catch {
            logger.logError(error, context: "Failed to load EVE character window states")
        }
    }
    
    private func saveCharacterStates() {
        do {
            let data = try JSONEncoder().encode(characterStates)
            UserDefaults.standard.set(data, forKey: storageKey)
            logger.debug("Saved \(characterStates.count) EVE character window states")
        } catch {
            logger.logError(error, context: "Failed to save EVE character window states")
        }
    }
}
