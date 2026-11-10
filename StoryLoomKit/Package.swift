// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StoryLoomKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "StoryLoomKit", targets: ["StoryLoomKit"]),
        .executable(name: "storyloom", targets: ["storyloom"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.0"),
    ],
    targets: [
        .target(
            name: "StoryLoomKit",
            dependencies: [.product(name: "Yams", package: "Yams")],
            swiftSettings: [.swiftLanguageMode(.v6), .treatAllWarnings(as: .error)]
        ),
        .executableTarget(
            name: "storyloom",
            dependencies: [
                "StoryLoomKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6), .treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "StoryLoomKitTests",
            dependencies: ["StoryLoomKit"],
            swiftSettings: [.swiftLanguageMode(.v6), .treatAllWarnings(as: .error)]
        ),
    ]
)
