// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CatBar",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "CatBar", targets: ["CatBar"]),
        .executable(name: "CatBarProxyHelper", targets: ["CatBarProxyHelper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
    ],
    targets: [
        .target(
            name: "ProxyHelperShared",
            path: "Sources/ProxyHelperShared"),
        .executableTarget(
            name: "CatBar",
            dependencies: [
                "ProxyHelperShared",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/ClashBar",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                // App bundle packaging copies Sparkle.framework into Contents/Frameworks.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]),
        .executableTarget(
            name: "CatBarProxyHelper",
            dependencies: ["ProxyHelperShared"],
            path: "Sources/ProxyHelper/Daemon"),
    ])
