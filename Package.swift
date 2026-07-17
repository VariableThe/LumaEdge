// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LumaEdge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LumaEdgeApp", targets: ["LumaEdgeApp"]),
        .executable(name: "lumaedge", targets: ["LumaEdgeCLI"]),
        .library(name: "LumaEdgeCore", targets: ["LumaEdgeCore"]),
        .library(name: "RenderingEngine", targets: ["RenderingEngine"]),
        .library(name: "OverlayManager", targets: ["OverlayManager"]),
        .library(name: "DisplayManager", targets: ["DisplayManager"]),
        .library(name: "MenuBar", targets: ["MenuBar"]),
        .library(name: "Settings", targets: ["Settings"])
    ],
    dependencies: [],
    targets: [
        // Base Core Module
        .target(
            name: "LumaEdgeCore",
            dependencies: []
        ),
        // Display Management
        .target(
            name: "DisplayManager",
            dependencies: ["LumaEdgeCore"]
        ),
        // GPU & Canvas Rendering Engine
        .target(
            name: "RenderingEngine",
            dependencies: ["LumaEdgeCore"],
            resources: [.process("MetalEdgeShader.metal")]
        ),
        // Click-through Borderless Overlays
        .target(
            name: "OverlayManager",
            dependencies: ["LumaEdgeCore", "RenderingEngine", "DisplayManager"]
        ),
        // Modern SwiftUI Settings UI
        .target(
            name: "Settings",
            dependencies: [
                "LumaEdgeCore",
                "RenderingEngine",
                "DisplayManager",
                "ApplicationProfiles",
                "CameraDetection",
                "AnimationEngine",
                "WindowManager",
                "AccessibilityManager",
                "PluginAPI"
            ]
        ),
        // Native Menu Bar Status Popover
        .target(
            name: "MenuBar",
            dependencies: ["LumaEdgeCore", "OverlayManager", "Settings", "DisplayManager"]
        ),
        // Future / Layered Modules (Stubs / Phase 2-5)
        .target(
            name: "WindowManager",
            dependencies: ["LumaEdgeCore"]
        ),
        .target(
            name: "AccessibilityManager",
            dependencies: ["LumaEdgeCore", "WindowManager"]
        ),
        .target(
            name: "CameraDetection",
            dependencies: ["LumaEdgeCore"]
        ),
        .target(
            name: "ApplicationProfiles",
            dependencies: ["LumaEdgeCore"]
        ),
        .target(
            name: "AnimationEngine",
            dependencies: ["LumaEdgeCore"]
        ),
        .target(
            name: "PluginAPI",
            dependencies: ["LumaEdgeCore"]
        ),
        // Main Application Executable
        .executableTarget(
            name: "LumaEdgeApp",
            dependencies: [
                "LumaEdgeCore",
                "DisplayManager",
                "RenderingEngine",
                "OverlayManager",
                "Settings",
                "MenuBar",
                "WindowManager",
                "AccessibilityManager",
                "CameraDetection",
                "ApplicationProfiles",
                "AnimationEngine",
                "PluginAPI"
            ]
        ),
        // Command-Line Utility Executable
        .executableTarget(
            name: "LumaEdgeCLI",
            dependencies: ["LumaEdgeCore"]
        ),
        // Unit & Integration Test Suite
        .testTarget(
            name: "LumaEdgeTests",
            dependencies: [
                "LumaEdgeCore",
                "RenderingEngine",
                "DisplayManager",
                "OverlayManager",
                "ApplicationProfiles",
                "AnimationEngine",
                "CameraDetection",
                "WindowManager",
                "AccessibilityManager",
                "PluginAPI"
            ]
        )
    ]
)
