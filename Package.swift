// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "deskloop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "deskloop", targets: ["deskloop"]),
        .library(name: "DeskloopCore", targets: ["DeskloopCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DeskloopCore",
            path: "Sources/DeskloopCore"
        ),
        .executableTarget(
            name: "deskloop",
            dependencies: ["DeskloopCore"],
            path: "Sources/deskloop"
        ),
        .testTarget(
            name: "DeskloopTests",
            dependencies: ["DeskloopCore"],
            path: "Tests/DeskloopTests"
        )
    ]
)
