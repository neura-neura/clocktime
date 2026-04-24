// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ClockTime",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClockTime", targets: ["ClockTime"])
    ],
    targets: [
        .executableTarget(
            name: "ClockTime",
            path: "Sources/ClockTime"
        )
    ]
)
