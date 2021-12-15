// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "MicroSwitch",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "mswitch", targets: ["MicroSwitch"]),
        .executable(name: "mclient", targets: ["MicroClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.4.2"),
        .package(url: "https://github.com/grpc/grpc-swift", from: "1.5.0"),
        .package(url: "https://github.com/JohnSundell/Files", from: "4.2.0"),
        .package(url: "https://github.com/kylebrowning/APNSwift", from: "3.2.0")
    ],
    targets: [
        .executableTarget(
            name: "MicroSwitch",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "Files", package: "Files"),
                .product(name: "APNSwift", package: "APNSwift")
            ]),
        .executableTarget(
            name: "MicroClient",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "GRPC", package: "grpc-swift")
            ]),
        .testTarget(
            name: "MicroSwitchTests",
            dependencies: ["MicroSwitch"]),
    ]
)
