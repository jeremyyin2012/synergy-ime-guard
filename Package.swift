// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "synergy-ime-guard",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SynergyIMEGuardCore",
            targets: ["SynergyIMEGuardCore"]
        ),
        .executable(
            name: "synergy-ime-guard",
            targets: ["SynergyIMEGuard"]
        ),
    ],
    targets: [
        .target(
            name: "SynergyIMEGuardCore",
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        ),
        .executableTarget(
            name: "SynergyIMEGuard",
            dependencies: ["SynergyIMEGuardCore"]
        ),
        .testTarget(
            name: "SynergyIMEGuardCoreTests",
            dependencies: ["SynergyIMEGuardCore"]
        ),
    ]
)
