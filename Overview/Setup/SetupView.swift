/*
 Setup/SetupView.swift
 Overview
 
 Created by William Pierce on 2/10/25.
*/

import SwiftUI

struct SetupView: View {
    @ObservedObject var coordinator: SetupCoordinator
    private let logger = AppLogger.interface
    
    @State private var currentStep = 0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                header
                Spacer()
                stepContent
                Spacer()
                navigationButtons
            }
            .padding(40)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Material.ultraThick)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 20)
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.2.layers.3d.top.filled")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("Welcome to Overview")
                .font(.title)
                .fontWeight(.semibold)
        }
    }
    
    private var stepContent: some View {
        VStack(spacing: 16) {
            switch currentStep {
            case 0:
                welcomeStep
            case 1:
                permissionsStep
            case 2:
                finalStep
            default:
                EmptyView()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: currentStep)
    }
    
    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Text("Overview helps you manage multiple windows by creating floating preview windows that let you monitor and quickly switch between applications.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Text("Let's get you set up!")
                .fontWeight(.medium)
        }
    }
    
    private var permissionsStep: some View {
        VStack(spacing: 16) {
            Text("Overview needs screen recording permission to create window previews.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if coordinator.hasScreenRecordingPermission {
                permissionGrantedView
            } else {
                permissionRequestView
            }
        }
    }
    
    private var permissionGrantedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
            
            Text("Screen recording permission granted!")
                .fontWeight(.medium)
        }
    }
    
    private var permissionRequestView: some View {
        VStack(spacing: 16) {
            if coordinator.hasRequestedPermission {
                Button("Open System Settings") {
                    coordinator.openSystemPreferences()
                }
                .buttonStyle(.borderedProminent)
                
                Text("After enabling permission, click the button below to continue")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Check Permission") {
                    Task {
                        await coordinator.checkScreenRecordingPermission()
                    }
                }
            } else {
                Button("Request Permission") {
                    Task {
                        await coordinator.requestScreenRecordingPermission()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var finalStep: some View {
        VStack(spacing: 16) {
            Text("You're all set!")
                .fontWeight(.medium)
            
            Text("Access Overview's settings and create new windows from the menu bar icon in the top right.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    currentStep -= 1
                }
            }
            
            Spacer()
            
            if currentStep < 2 {
                Button("Continue") {
                    if currentStep == 1 && !coordinator.hasScreenRecordingPermission {
                        return
                    }
                    currentStep += 1
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentStep == 1 && !coordinator.hasScreenRecordingPermission)
            } else {
                Button("Get Started") {
                    coordinator.completeSetup()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
