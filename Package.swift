// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "HTML",
    platforms: [ .iOS(.v15), .macCatalyst(.v15), .macOS(.v12), .tvOS(.v15) ],
    products: [
        .library(
            name: "HTMLTree",
            targets: [ "HTMLTree" ]),
        .library(
            name: "HTMLAttributedString",
            targets: [ "HTMLAttributedString" ]),
    ],
    targets: [
        .target(
            name: "HTMLTree",
            dependencies: [
                .target(name: "libxml2", condition: .when(platforms: [ .linux, .android ]))
            ]),
        .testTarget(
            name: "HTMLTreeTests",
            dependencies: [ "HTMLTree" ]),
        .target(
            name: "HTMLAttributedString"),
        .testTarget(
            name: "HTMLAttributedStringTests",
            dependencies: [ "HTMLAttributedString" ]),
        .systemLibrary(
            name: "libxml2",
            pkgConfig: "libxml-2.0",
            providers: [ .apt([ "libxml2-dev" ]) ])
    ]
)
