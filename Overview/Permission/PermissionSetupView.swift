/*
 Permission/PermissionSetupView.swift
 Overview

 Created by William Pierce on 2/10/25.
*/

import SwiftUI

struct PermissionSetupView: View {
    // Dependencies
    @ObservedObject var coordinator: PermissionSetupCoordinator
    private let logger = AppLogger.interface

    var body: some View {
        VStack(spacing: 16) {
            header
            Spacer()
                .frame(height: 8)
            permissionsContent
            Spacer()
                .frame(height: 8)
            navigationButtons
        }
        .padding(24)
        .frame(height: 460)
        .background(.background)
    }

    // MARK: - View Components

    private var header: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .foregroundColor(.accentColor)
            Text("Welcome to Overview")
                .font(.title)
                .fontWeight(.semibold)
        }
    }

    private var permissionsContent: some View {
        VStack(spacing: 16) {
            PermissionRow(
                icon: "rectangle.dashed",
                title: "Screen Recording",
                description:
                    "This permission is needed to show live previews and titles of open windows",
                state: coordinator.screenRecordingPermission,
                action: coordinator.openScreenRecordingPreferences,
                requestPermission: coordinator.requestScreenRecordingPermission
            )
        }
    }

    private var navigationButtons: some View {
        HStack {
            Button("Continue") {
                coordinator.completeSetup()
            }
            .buttonStyle(.borderedProminent)
            .disabled(coordinator.screenRecordingPermission != .granted)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let state: PermissionSetupCoordinator.PermissionStatus
    let action: () -> Void
    let requestPermission: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                VStack {
                    if state == .denied {
                        HStack(spacing: 12) {
                            Button("Request Permission") {
                                requestPermission()
                            }
                            Button("Open Preferences...") {
                                action()
                            }
                        }
                    }
                }
                .frame(height: 32)
            }
            Spacer(minLength: 16)
            permissionIndicator
        }
        .padding(.vertical, 16)
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var permissionIndicator: some View {
        Group {
            switch state {
            case .unknown:
                ProgressView()
            case .denied:
                Label("Not allowed", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .granted:
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .denied:
            return Color(.systemRed).opacity(0.1)
        case .granted:
            return Color(.systemGreen).opacity(0.1)
        case .unknown:
            return Color(.separatorColor).opacity(0.1)
        }
    }
}
