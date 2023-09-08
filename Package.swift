// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "HTML",
    platforms: [ .iOS(.v15), .macCatalyst(.v15), .macOS(.v12), .tvOS(.v15) ],
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
