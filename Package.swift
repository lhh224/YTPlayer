// swift-tools-version: 5.7
// Package.swift — YTPlayer
import PackageDescription

let package = Package(
    name: "YTPlayer",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "YTPlayer",
            targets: ["YTPlayer"]
        ),
    ],
    targets: [
        .target(
            name: "YTPlayer",
            path: ".",
            exclude: [
                "YTPlayer.xcodeproj",
                "Documentation",
                "Tests",
                "Config",
                "generate_xcodeproj.py"
            ],
            sources: [
                "App",
                "Core",
                "Features",
                "Services"
            ]
        ),
        .testTarget(
            name: "YTPlayerTests",
            dependencies: ["YTPlayer"],
            path: "Tests/YTPlayerTests"
        )
    ]
)
