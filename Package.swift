// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "link-framework-cli",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "link-framework-cli", targets: ["LinkFrameworkCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.21.0"),
    ],
    targets: [
        .executableTarget(
            name: "LinkFrameworkCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "XcodeProj", package: "XcodeProj"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "LinkFrameworkCLITests",
            dependencies: ["LinkFrameworkCLI"]
        )
    ]
)
