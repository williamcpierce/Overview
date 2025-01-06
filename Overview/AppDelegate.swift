/*
 Application/AppDelegate.swift
 Overview

 Created by William Pierce on 1/5/25.

 Manages application lifecycle events and state persistence.
*/

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowService: WindowService
    private let logger = AppLogger.interface
    
    init(windowService: WindowService) {
        self.windowService = windowService
        super.init()
        configureTerminationHandler()
    }
    
    private func configureTerminationHandler() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc func applicationWillTerminate(_ notification: Notification) {
        windowService.saveWindowStates()
        logger.info("Application terminating, window states saved")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
