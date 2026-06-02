// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AgentBeacon",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AgentBeacon", targets: ["AgentBeaconApp"]),
        .executable(name: "AgentBeaconStatus", targets: ["AgentBeaconStatus"]),
        .executable(name: "AgentBeaconSnapshot", targets: ["AgentBeaconSnapshot"]),
        .library(name: "AgentBeaconCore", targets: ["AgentBeaconCore"]),
        .library(name: "AgentBeaconUI", targets: ["AgentBeaconUI"])
    ],
    targets: [
        .target(name: "AgentBeaconCore"),
        .target(
            name: "AgentBeaconUI",
            dependencies: ["AgentBeaconCore"]
        ),
        .executableTarget(
            name: "AgentBeaconApp",
            dependencies: ["AgentBeaconCore", "AgentBeaconUI"]
        ),
        .executableTarget(
            name: "AgentBeaconStatus",
            dependencies: ["AgentBeaconCore"]
        ),
        .executableTarget(
            name: "AgentBeaconSnapshot",
            dependencies: ["AgentBeaconCore", "AgentBeaconUI"]
        ),
        .testTarget(
            name: "AgentBeaconCoreTests",
            dependencies: ["AgentBeaconCore"]
        ),
        .testTarget(
            name: "AgentBeaconUITests",
            dependencies: ["AgentBeaconCore", "AgentBeaconUI"]
        )
    ]
)
