//===----------------------------------------------------------------------===//
//
// This source file is part of the Jaeger Client Swift open source project
//
// Copyright (c) 2020 Moritz Lang and the Jaeger Client Swift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Baggage
import Instrumentation
import Jaeger
import NIO
import NIOHTTP1
import NIOInstrumentation
import Tracing
import W3CTraceContext
import XCTest

final class JaegerTracerTests: XCTestCase {
    // MARK: - Context Propagation

    func test_extract_w3c_trace_context_into_baggage() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let recorder = TestSpanRecorder(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", recordingStrategy: .custom(recorder))
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)

        let traceContext = TraceContext(parent: .random(), state: .none)
        var baggage = Baggage.topLevel

        tracer.extract(
            [TraceParent.headerName: traceContext.parent.rawValue, TraceState.headerName: traceContext.state.rawValue],
            into: &baggage,
            using: HTTPHeadersExtractor()
        )

        XCTAssertEqual(baggage.traceContext, traceContext)
    }

    func test_extract_missing_w3c_trace_context_into_baggage() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let recorder = TestSpanRecorder(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", recordingStrategy: .custom(recorder))
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)

        var baggage = Baggage.topLevel

        tracer.extract([:], into: &baggage, using: HTTPHeadersExtractor())

        XCTAssertNil(baggage.traceContext)
    }

    func test_extract_missing_w3c_trace_context_without_state_into_baggage() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let recorder = TestSpanRecorder(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", recordingStrategy: .custom(recorder))
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)

        let traceContext = TraceContext(parent: .random(), state: .none)
        var baggage = Baggage.topLevel

        tracer.extract(
            [TraceParent.headerName: traceContext.parent.rawValue],
            into: &baggage,
            using: HTTPHeadersExtractor()
        )

        XCTAssertEqual(baggage.traceContext, traceContext)
    }

    func test_inject_w3c_trace_context_into_headers() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let recorder = TestSpanRecorder(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", recordingStrategy: .custom(recorder))
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)

        let traceContext = TraceContext(parent: .random(), state: .none)
        var baggage = Baggage.topLevel
        baggage.traceContext = traceContext
        var headers = HTTPHeaders()

        tracer.inject(baggage, into: &headers, using: HTTPHeadersInjector())

        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(headers.first(name: TraceParent.headerName), traceContext.parent.rawValue)
        XCTAssertEqual(headers.first(name: TraceState.headerName), traceContext.state.rawValue)
    }

    func test_inject_missing_w3c_trace_context_into_headers() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let recorder = TestSpanRecorder(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", recordingStrategy: .custom(recorder))
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)

        let baggage = Baggage.topLevel
        var headers = HTTPHeaders()

        tracer.inject(baggage, into: &headers, using: HTTPHeadersInjector())

        XCTAssertTrue(headers.isEmpty)
    }

    // MARK: - Flushing

    func test_emits_spans_to_recorder_on_forceFlush() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let recorder = TestSpanRecorder(eventLoop: eventLoopGroup.next())

        let settings = JaegerTracer.Settings(serviceName: "test", recordingStrategy: .custom(recorder))
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)

        var spans = [JaegerSpan]()

        for _ in 0 ..< 10 {
            let span = tracer.startSpan(named: "test", baggage: .topLevel, ofKind: .server, at: .now())
            spans.append(span as! JaegerSpan)
            span.end()
        }

        XCTAssertEqual(recorder.numberOfFlushes, 0)

        tracer.forceFlush()

        XCTAssertEqual(recorder.numberOfFlushes, 1)
        XCTAssertEqual(recorder.flushedSpans.count, 10)
        for (index, span) in recorder.flushedSpans.enumerated() {
            XCTAssert(spans[index] === span)
        }
    }
}

private final class TestSpanRecorder: SpanRecorder {
    private(set) var flushedSpans = [JaegerSpan]()
    private(set) var numberOfFlushes = 0
    private let eventLoop: EventLoop

    lazy var response: EventLoopFuture<Void> = self.eventLoop.makeSucceededFuture(())

    init(eventLoop: EventLoop) {
        self.eventLoop = eventLoop
    }

    func flush(spans: ArraySlice<JaegerSpan>, inService serviceName: String) -> EventLoopFuture<Void> {
        self.flushedSpans.append(contentsOf: spans)
        self.numberOfFlushes += 1
        return self.response
    }
}
