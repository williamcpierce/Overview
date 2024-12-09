/*
 HotkeyRecorder.swift
 Overview
 
 Created by William Pierce on 12/8/24.
*/

import AppKit
import SwiftUI

struct HotkeyRecorder: NSViewRepresentable {
    @Binding var shortcut: HotkeyBinding?
    let windowTitle: String
    
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.title = shortcut?.description ?? "Click to record shortcut"
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked(_:))
        return button
    }
    
    func updateNSView(_ button: NSButton, context: Context) {
        button.title = shortcut?.description ?? "Click to record shortcut"
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: HotkeyRecorder
        var isRecording = false
        var currentModifiers: NSEvent.ModifierFlags = []
        var monitor: Any?
        
        init(_ parent: HotkeyRecorder) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            stopRecording()
        }
        
        @objc func buttonClicked(_ sender: NSButton) {
            if isRecording {
                stopRecording()
                sender.title = parent.shortcut?.description ?? "Click to record shortcut"
            } else {
                startRecording(sender)
                sender.title = "Type shortcut..."
            }
        }
        
        func startRecording(_ sender: NSButton) {
            guard monitor == nil else { return }
            
            isRecording = true
            currentModifiers = []
            
            // Monitor both key up and key down to handle modifier changes
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
                self?.handleKeyEvent(event)
                return nil // Consume the event during recording
            }
        }
        
        func stopRecording() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            isRecording = false
            currentModifiers = []
        }
        
        func handleKeyEvent(_ event: NSEvent) {
            if event.type == .flagsChanged {
                currentModifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
                return
            }
            
            // Only handle keyDown events when we're actually recording
            guard event.type == .keyDown && isRecording else { return }
            
            // Require at least one modifier key
            let requiredModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            guard !requiredModifiers.intersection(currentModifiers).isEmpty else { return }
            
            // Create new binding
            parent.shortcut = HotkeyBinding(
                windowTitle: parent.windowTitle,
                keyCode: Int(event.keyCode),
                modifiers: currentModifiers
            )
            
            stopRecording()
        }
    }
}
