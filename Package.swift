// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexBreathingLight",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "codex-breathing-light", targets: ["codex-breathing-light"]),
        .executable(name: "codex-breathing-light-ui", targets: ["codex-breathing-light-ui"]),
        .executable(name: "codex-approval-watcher", targets: ["codex-approval-watcher"]),
        .executable(name: "codex-reminder-control", targets: ["codex-reminder-control"]),
        .executable(name: "codex-reminder-agent", targets: ["codex-reminder-agent"])
    ],
    targets: [
        .target(name: "CodexBreathingLightCore"),
        .executableTarget(
            name: "codex-breathing-light",
            dependencies: ["CodexBreathingLightCore"]
        ),
        .executableTarget(
            name: "codex-breathing-light-ui",
            dependencies: ["CodexBreathingLightCore"]
        ),
        .executableTarget(
            name: "codex-approval-watcher",
            dependencies: ["CodexBreathingLightCore"]
        ),
        .executableTarget(
            name: "codex-reminder-control",
            dependencies: ["CodexBreathingLightCore"]
        ),
        .executableTarget(
            name: "codex-reminder-agent",
            dependencies: ["CodexBreathingLightCore"]
        ),
        .testTarget(
            name: "CodexBreathingLightCoreTests",
            dependencies: ["CodexBreathingLightCore"]
        )
    ]
)
