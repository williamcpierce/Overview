// swift-tools-version: 6.0
// Package.swift — Portable Phase 1 lifecycle, persistence, and resolver tests.
import PackageDescription

let package = Package(
    name: "OverviewCore",
    platforms: [.macOS("27.0")],
    products: [.library(name: "OverviewCore", targets: ["OverviewCore"])],
    targets: [
        .target(
            name: "OverviewCore",
            path: "Overview/Core",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "OverviewCoreTests",
            dependencies: ["OverviewCore"],
            path: "Tests/OverviewCoreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
