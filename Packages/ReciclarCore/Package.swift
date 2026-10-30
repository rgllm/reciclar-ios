// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ReciclarCore",
    defaultLocalization: "pt-PT",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "ReciclarCore", targets: ["ReciclarCore"]),
        .executable(name: "ReciclarCoreChecks", targets: ["ReciclarCoreChecks"]),
    ],
    targets: [
        .target(
            name: "ReciclarCore",
            resources: [
                .process("Fixtures"),
            ]
        ),
        .executableTarget(
            name: "ReciclarCoreChecks",
            dependencies: ["ReciclarCore"]
        ),
    ]
)
