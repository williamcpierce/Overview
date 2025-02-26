/*
 AutoCapture/AutoCaptureService.swift
 Overview

 Created by William Pierce on 2/25/25.

 Manages automatic window capture for applications like EVE Online,
 creating preview windows for specific characters and remembering their positions.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class AutoCaptureService: ObservableObject {
    // Dependencies
    private var windowManager: WindowManager?
    private let sourceManager: SourceManager
    private let sourceObserver: SourceObserverService
    private let logger = AppLogger.interface
    
    // Private State
    private var characterPositions: [String: WindowState] = [:]
    private var activeCharacters: Set<String> = []
    private var observerId = UUID()

    // Auto-Capture Settings
    @AppStorage(AutoCaptureSettingsKeys.enabled)
    private var autoCaptureEnabled = AutoCaptureSettingsKeys.defaults.enabled
    
    private var autoCaptureApplications: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: AutoCaptureSettingsKeys.applications) else {
                return AutoCaptureSettingsKeys.defaults.applications
            }
            
            do {
                return try JSONDecoder().decode([String].self, from: data)
            } catch {
                logger.logError(error, context: "Failed to decode auto-capture applications")
                return AutoCaptureSettingsKeys.defaults.applications
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: AutoCaptureSettingsKeys.applications)
            } catch {
                logger.logError(error, context: "Failed to encode auto-capture applications")
            }
        }
    }
    
    init(sourceManager: SourceManager, sourceObserver: SourceObserverService) {
        self.sourceManager = sourceManager
        self.sourceObserver = sourceObserver
        
        loadCharacterPositions()
        logger.debug("AutoCaptureService initialized")
    }
    
    // MARK: - Public Methods
    
    func setWindowManager(_ windowManager: WindowManager) {
        self.windowManager = windowManager
    }
    
    func start() {
        sourceObserver.addObserver(
            id: observerId,
            onFocusChanged: { [weak self] in
                // We don't need to do anything on focus change
            },
            onTitleChanged: { [weak self] in
                // Process source windows when titles change
                await self?.processSourceWindows()
            }
        )
        
        logger.info("Auto-capture service started")
    }
    
    func stop() {
        sourceObserver.removeObserver(id: observerId)
        logger.info("Auto-capture service stopped")
    }
    
    func saveWindowPosition(title: String, frame: NSRect) {
        guard autoCaptureEnabled else { return }
        
        for appName in autoCaptureApplications {
            if let characterName = extractCharacterName(from: title, appName: appName) {
                let key = "\(appName):\(characterName)"
                characterPositions[key] = WindowState(frame: frame)
                saveCharacterPositions()
                
                logger.info("Saved window position for character: \(characterName)")
                break
            }
        }
    }
    
    func resetCharacterPositions() {
        characterPositions = [:]
        saveCharacterPositions()
        logger.info("Reset all character positions")
    }
    
    // MARK: - Private Methods
    
    private func processSourceWindows() async {
        guard autoCaptureEnabled else { return }
        
        do {
            let sources = try await sourceManager.getAvailableSources()
            
            for source in sources {
                guard let appName = source.owningApplication?.applicationName,
                      let title = source.title,
                      autoCaptureApplications.contains(appName) else { continue }
                
                if let characterName = extractCharacterName(from: title, appName: appName) {
                    let key = "\(appName):\(characterName)"
                    
                    if !activeCharacters.contains(key) {
                        createWindowForCharacter(appName: appName, characterName: characterName)
                        activeCharacters.insert(key)
                    }
                }
            }
        } catch {
            logger.logError(error, context: "Failed to get available sources for auto-capture")
        }
    }
    
    private func extractCharacterName(from title: String, appName: String) -> String? {
        if appName == "EVE" && title.starts(with: "EVE - ") {
            return String(title.dropFirst(6)) // Remove "EVE - " prefix
        }
        return nil
    }
    
    private func createWindowForCharacter(appName: String, characterName: String) {
        guard let windowManager = windowManager else {
            logger.warning("Cannot create window: WindowManager not set")
            return
        }
        
        logger.debug("Creating window for character: \(characterName)")
        
        let key = "\(appName):\(characterName)"
        
        // Look for saved position for this character
        if let savedPosition = characterPositions[key] {
            // Create window with saved position
            do {
                try windowManager.createWindow(at: savedPosition.frame)
                logger.info("Created preview window for character: \(characterName) at saved position")
            } catch {
                logger.logError(error, context: "Failed to create preview window for character: \(characterName)")
            }
        } else {
            // Create window at default position
            do {
                try windowManager.createWindow()
                logger.info("Created preview window for character: \(characterName) at default position")
            } catch {
                logger.logError(error, context: "Failed to create preview window for character: \(characterName)")
            }
        }
    }
    
    private func loadCharacterPositions() {
        if let data = UserDefaults.standard.data(forKey: AutoCaptureSettingsKeys.characterPositions) {
            do {
                characterPositions = try JSONDecoder().decode([String: WindowState].self, from: data)
                logger.info("Loaded positions for \(characterPositions.count) characters")
            } catch {
                logger.logError(error, context: "Failed to load character positions")
                characterPositions = [:]
            }
        } else {
            characterPositions = [:]
        }
    }
    
    private func saveCharacterPositions() {
        do {
            let data = try JSONEncoder().encode(characterPositions)
            UserDefaults.standard.set(data, forKey: AutoCaptureSettingsKeys.characterPositions)
            logger.debug("Saved character positions")
        } catch {
            logger.logError(error, context: "Failed to save character positions")
        }
    }
}
