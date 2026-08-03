// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TiboResetNotifier",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TiboResetNotifier", targets: ["TiboResetNotifier"]),
        .executable(name: "TiboResetNotifierChecks", targets: ["TiboResetNotifierChecks"]),
    ],
    targets: [
        .target(name: "TiboResetCore"),
        .executableTarget(
            name: "TiboResetNotifier",
            dependencies: ["TiboResetCore"]
        ),
        .executableTarget(
            name: "TiboResetNotifierChecks",
            dependencies: ["TiboResetCore"]
        ),
    ]
)
