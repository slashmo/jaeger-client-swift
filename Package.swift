// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "jaeger-client-swift",
    products: [
        .library(name: "Jaeger", targets: ["Jaeger"]),
    ],
    dependencies: [
        .package(url: "https://github.com/slashmo/gsoc-swift-tracing.git", .branch("main")),
    ],
    targets: [
        .target(name: "Jaeger", dependencies: [
            .product(name: "Tracing", package: "gsoc-swift-tracing"),
        ]),
        .testTarget(name: "JaegerTests", dependencies: [
            .target(name: "Jaeger"),
        ]),
    ]
)
