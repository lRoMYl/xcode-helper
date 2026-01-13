// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "xcode-helper",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "xcode-helper", targets: ["XCodeHelper"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.21.0"),
    ],
    targets: [
        .executableTarget(
            name: "XCodeHelper",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "XcodeProj", package: "XcodeProj"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "XCodeHelperTests",
            dependencies: ["XCodeHelper"]
        )
    ]
)
