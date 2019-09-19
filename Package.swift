// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
let cTarget = Target.target(name: "CHTML", path: "Sources/CHTML-Darwin")
#else
let cTarget = Target.systemLibrary(name: "CHTML", pkgConfig: "libxml-2.0", providers: [.apt(["libxml2-dev"])])
#endif

let package = Package(
    name: "HTML",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "HTML",
            targets: ["HTML"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        cTarget,
        .target(
            name: "HTML",
            dependencies: ["CHTML"]),
        .testTarget(
            name: "HTMLTests",
            dependencies: ["HTML"]),
    ]
)
