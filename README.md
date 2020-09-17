# W3C Trace Context

[![Swift 5.2](https://img.shields.io/badge/Swift-5.2-ED523F.svg?style=flat)](https://swift.org/download/)

This Swift package provides a **WIP** client for Jaeger Tracing implemented using the
[Swift Tracing](https://github.com/slashmo/gsoc-swift-tracing) set of APIs.

## Goal 🥅

The main goal of this project is to create a test, yet real-world, implementation for fleshing out the API details for
Swift Tracing.

## Stretch Goal 🙆‍♀️ 🥅

As a stretch goal for this implementation we aim to pitch it to become embraced by the Jaeger project as an [officially supported library](https://www.jaegertracing.io/docs/1.19/client-libraries/#supported-libraries).

## Contributing

Please make sure to run the `./scripts/sanity.sh` script when contributing, it checks formatting and similar things.

You can ensure it always runs and passes before you push by installing a pre-push hook with git:

```sh
echo './scripts/sanity.sh' > .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```
