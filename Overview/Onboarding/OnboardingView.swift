/*
 Onboarding/OnboardingView.swift
 Overview

 Created by William Pierce on 2/23/25.
*/

import SwiftUI

struct OnboardingView: View {
    // Dependencies
    @ObservedObject var coordinator: OnboardingCoordinator
    private let logger = AppLogger.interface

    // View State
    @State private var tabIndex = 0
    @State private var appIconIsActive = false

    var body: some View {
        ZStack {
            Group {
                switch tabIndex {
                case 0: introTab
                case 1: permissionsTab
                case 2: completedTab
                default: EmptyView()
                }
            }
            .transition(
                .asymmetric(insertion: .offset(x: 500), removal: .offset(x: -500))
                    .combined(with: .opacity)
            )
        }
        .frame(width: 500, height: 320)
        .background(Material.thick)
        .background(backgroundGradient)
    }

    private var introTab: some View {
        VStack(spacing: 0) {
            Spacer()

            AppIconView()
                .padding(.bottom, 24)

            Text("Welcome to Overview")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 8)

            Text("The free and open source window preview tool for macOS")
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()

            primaryButton("Get Started") {
                nextTab()
            }
        }
        .padding(24)
    }

    private var permissionsTab: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Permission Setup")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 24)
                .padding(.bottom, 16)

            PermissionRow(
                icon: "rectangle.dashed",
                title: "Screen Recording",
                description:
                    "This permission is needed to show live previews and titles of open windows",
                state: coordinator.screenRecordingPermission,
                action: coordinator.openScreenRecordingPreferences,
                requestPermission: coordinator.requestScreenRecordingPermission
            )
            .padding(.horizontal, 24)

            Spacer()

            primaryButton("Continue") {
                nextTab()
            }
            .disabled(coordinator.screenRecordingPermission != .granted)
        }
        .padding(.bottom, 24)
    }

    private var completedTab: some View {
        VStack(spacing: 0) {
            Spacer()

            AppIconView()
                .padding(.bottom, 24)

            Text("You're ready to go!")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 8)

            Text(
                "When you click the button below, Overview will move to the menu bar to run in the background"
            )
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(width: 400)

            Spacer()

            primaryButton("Complete Setup") {
                coordinator.completeOnboarding()
            }
        }
        .padding(24)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(width: 200)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func nextTab() {
        withAnimation(.smooth) {
            tabIndex += 1
        }
    }
}

// MARK: - View Components

struct AppIconView: View {
    var body: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 120, height: 120)
            .brightness(0.1)
            .shadow(
                color: .black.opacity(0.5),
                radius: 32,
                y: 24
            )
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let state: OnboardingCoordinator.PermissionStatus
    let action: () -> Void
    let requestPermission: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
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

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 24)

                HStack(spacing: 12) {
                    Button("Check Permission") {
                        requestPermission()
                    }
                    Button("Open Preferences...") {
                        action()
                    }
                }
                .frame(height: 32)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
