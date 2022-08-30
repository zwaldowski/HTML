// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "HTML",
    products: [
        .library(
            name: "HTML",
            targets: [ "HTML" ])
    ],
    targets: [
        .target(
            name: "HTML",
            dependencies: [
                .target(name: "CHTML", condition: .when(platforms: [ .linux, .android ]))
            ]),
        .testTarget(
            name: "HTMLTests",
            dependencies: [ "HTML" ]),
        .systemLibrary(
            name: "CHTML",
            pkgConfig: "libxml-2.0",
            providers: [ .apt([ "libxml2-dev" ]) ])
    ]
)
