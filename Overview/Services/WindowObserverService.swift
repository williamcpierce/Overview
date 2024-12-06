/*
 WindowObserverService.swift
 Overview

 Created by William Pierce on 12/5/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit

protocol WindowObserverService: AnyObject {
    var onFocusStateChanged: (() async -> Void)? { get set }
    var onWindowTitleChanged: (() async -> Void)? { get set }
    func startObserving()
    func stopObserving()
}

class DefaultWindowObserverService: WindowObserverService {
    var onFocusStateChanged: (() async -> Void)?
    var onWindowTitleChanged: (() async -> Void)?
    
    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?
    private var titleCheckTimer: Timer?
    
    deinit {
        stopObserving()
    }
    
    func startObserving() {
        setupWorkspaceObserver()
        setupWindowObserver()
        startTitleChecks()
    }
    
    func stopObserving() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        titleCheckTimer?.invalidate()
    }
    
    private func setupWorkspaceObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.onFocusStateChanged?()
            }
        }
    }
    
    private func setupWindowObserver() {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.onFocusStateChanged?()
            }
        }
    }
    
    private func startTitleChecks() {
        titleCheckTimer?.invalidate()
        titleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.onWindowTitleChanged?()
            }
        }
    }
}
