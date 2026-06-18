// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DiecastVaultCore",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "DiecastVaultCore",
            targets: ["DiecastVaultCore"]
        )
    ],
    targets: [
        .target(
            name: "DiecastVaultCore"
        ),
        .testTarget(
            name: "DiecastVaultCoreTests",
            dependencies: ["DiecastVaultCore"]
        )
    ]
)
