// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Recombine",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .watchOS(.v6), .tvOS(.v13),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Recombine",
            targets: ["Recombine"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/CombineExpectations", from: "0.7.0"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.7.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.2.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Recombine",
            dependencies: [
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "RecombineTests",
            dependencies: [
                "Recombine",
                "CombineExpectations",
            ],
            path: "Tests"
        ),
    ]
)
