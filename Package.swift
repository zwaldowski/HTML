// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "HTML",
    platforms: [ .iOS(.v16), .macCatalyst(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v7) ],
    products: [
        .library(
            name: "HTMLAttributedString",
            targets: [ "HTMLAttributedString" ]),
    ],
    targets: [
        .target(
            name: "HTMLAttributedString"),
        .testTarget(
            name: "HTMLAttributedStringTests",
            dependencies: [ "HTMLAttributedString" ])
    ]
)
