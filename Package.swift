// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "jaeger-client-swift",
    products: [
        .library(name: "Jaeger", targets: ["Jaeger"]),
        .library(name: "ZipkinReporting", targets: ["ZipkinReporting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "0.1.1"),
        .package(url: "https://github.com/slashmo/swift-w3c-trace-context.git", from: "0.6.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
    ],
    targets: [
        .target(name: "Jaeger", dependencies: [
            .product(name: "Tracing", package: "swift-distributed-tracing"),
            .product(name: "W3CTraceContext", package: "swift-w3c-trace-context"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
        ]),
        .testTarget(name: "JaegerTests", dependencies: [
            .target(name: "Jaeger"),
        ]),
        .target(name: "ZipkinReporting", dependencies: [
            .target(name: "Jaeger"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .testTarget(name: "ZipkinReportingTests", dependencies: [
            .target(name: "ZipkinReporting"),
        ]),
    ]
)
