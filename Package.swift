// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "deskloop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "deskloop", targets: ["deskloop"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DeskloopCore"
        ),
        .executableTarget(
            name: "deskloop",
            dependencies: ["DeskloopCore"]
        ),
        .testTarget(
            name: "DeskloopTests",
            dependencies: ["DeskloopCore"]
        )
    ]
)
