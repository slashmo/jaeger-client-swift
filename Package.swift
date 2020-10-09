// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "jaeger-client-swift",
    products: [
        .library(name: "Jaeger", targets: ["Jaeger"]),
        .library(name: "ZipkinReporting", targets: ["ZipkinReporting"]),
    ],
    dependencies: [
        .package(name: "swift-context", url: "https://github.com/slashmo/gsoc-swift-baggage-context", from: "0.5.0"),
        .package(url: "https://github.com/slashmo/gsoc-swift-tracing.git", .branch("main")),
        .package(url: "https://github.com/slashmo/swift-w3c-trace-context.git", from: "0.4.0"),
        .package(url: "https://github.com/slashmo/swift-nio.git", .branch("feature/baggage-context")),
    ],
    targets: [
        .target(name: "Jaeger", dependencies: [
            .product(name: "Tracing", package: "gsoc-swift-tracing"),
            .product(name: "W3CTraceContext", package: "swift-w3c-trace-context"),
            .product(name: "Baggage", package: "swift-context"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
        ]),
        .testTarget(name: "JaegerTests", dependencies: [
            .target(name: "Jaeger"),
            .product(name: "NIOInstrumentation", package: "gsoc-swift-tracing"),
        ]),
        .target(name: "ZipkinReporting", dependencies: [
            .target(name: "Jaeger"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .testTarget(name: "ZipkinReportingTests", dependencies: [
            .target(name: "ZipkinReporting"),
            .product(name: "BaggageContext", package: "swift-context"),
        ]),
    ]
)
