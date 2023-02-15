// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ESLRunner",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.1"),
        .package(url: "https://github.com/nubcoxyz/ESLogger.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "ESLRunner",
            dependencies: [ .product(name: "ArgumentParser", package: "swift-argument-parser"),
                            "ESLogger", ]),
    ]
)
