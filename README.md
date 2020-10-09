# Swift Jaeger Client

[![Swift 5.3](https://img.shields.io/badge/Swift-5.2-ED523F.svg?style=flat)](https://swift.org/download/)

This Swift package provides a **WIP** client for Jaeger Tracing implemented using the
[Swift Tracing](https://github.com/slashmo/gsoc-swift-tracing) set of APIs.

## Goal 🥅

The main goal of this project is to create a test, yet real-world, implementation for fleshing out the API details for
Swift Tracing.

## Stretch Goal 🙆‍♀️ 🥅

As a stretch goal for this implementation we aim to pitch it to become embraced by the Jaeger project as an [officially supported library](https://www.jaegertracing.io/docs/1.19/client-libraries/#supported-libraries).

## Installation

First, Add the following package dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/slashmo/jaeger-client-swift.git", .branch("main")),
```

Then, add the `Jaeger` library to the target(s) you want to use it with:

```swift
.product(name: "Jaeger", package: "jaeger-client-swift"),
```

> 🔖 At this point in time no version has been tagged as the API is still very fragile. Make sure to watch the repository to stay tuned.

## Configuration

Now that you installed the Jaeger client you can use it in your project by bootstrapping the `InstrumentationSystem` with an instance of `JaegerClient`:

```swift
let reporter = // ... see instructions below
let jaegerSettings = JaegerTracer.Settings(
    serviceName: "frontend", 
    reporter: reporter
)
let jaegerTracer = JaegerTracer(
    settings: jaegerSettings, 
    group: eventLoopGroup
)
InstrumentationSystem.bootstrap(jaegerTracer)
```

### Reporting

Jaeger supports different [Span reporting APIs](https://www.jaegertracing.io/docs/1.20/apis/#span-reporting-apis), but
not all are supported (yet) by this client implementation. Here's a list of the supported reporters:

#### Zipkin

https://www.jaegertracing.io/docs/1.20/apis/#zipkin-formats-stable

> Make sure to set `COLLECTOR_ZIPKIN_HTTP_PORT` accordingly when configuring your Jaeger instance

```swift
let reporter = JaegerTracer.Reporter.zipkin(
    collectorHost: "localhost",
    collectorPort: 9411,
    eventLoopGroup: eventLoopGroup
)
```

## Contributing

Please make sure to run the `./scripts/sanity.sh` script when contributing, it checks formatting and similar things.

You can ensure it always runs and passes before you push by installing a pre-push hook with git:

```sh
echo './scripts/sanity.sh' > .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```
