// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "jaeger-client-swift",
    products: [
        .library(name: "Jaeger", targets: ["Jaeger"]),
    ],
    dependencies: [
        .package(url: "https://github.com/slashmo/gsoc-swift-tracing.git", .branch("main")),
        .package(url: "https://github.com/slashmo/swift-w3c-trace-context.git", from: "0.3.0"),
    ],
    targets: [
        .target(name: "Jaeger", dependencies: [
            .product(name: "Tracing", package: "gsoc-swift-tracing"),
            .product(name: "W3CTraceContext", package: "swift-w3c-trace-context"),
        ]),
        .testTarget(name: "JaegerTests", dependencies: [
            .target(name: "Jaeger"),
        ]),
    ]
)
