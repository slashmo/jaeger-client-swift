// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "jaeger-client-swift",
    products: [
        .library(name: "Jaeger", targets: ["Jaeger"]),
    ],
    targets: [
        .target(name: "Jaeger"),
        .testTarget(name: "JaegerTests", dependencies: [
            .target(name: "Jaeger"),
        ]),
    ]
)
