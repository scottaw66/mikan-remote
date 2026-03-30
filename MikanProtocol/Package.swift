// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MikanProtocol",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "MikanProtocol", targets: ["MikanProtocol"]),
    ],
    targets: [
        .target(name: "MikanProtocol"),
        .testTarget(name: "MikanProtocolTests", dependencies: ["MikanProtocol"]),
    ]
)
