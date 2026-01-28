// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickLogMVP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "QuickLogMVP", targets: ["QuickLogMVP"])
    ],
    targets: [
        .executableTarget(
            name: "QuickLogMVP",
            path: "QuickLog"
        )
    ]
)
