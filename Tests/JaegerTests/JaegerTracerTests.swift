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
        let reporter = TestSpanReporter(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", reporter: .custom(reporter), sampler: ConstantSampler(samples: false))
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
        let reporter = TestSpanReporter(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", reporter: .custom(reporter), sampler: ConstantSampler(samples: false))
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)

        var baggage = Baggage.topLevel

        tracer.extract([:], into: &baggage, using: HTTPHeadersExtractor())

        XCTAssertNil(baggage.traceContext)
    }

    func test_extract_missing_w3c_trace_context_without_state_into_baggage() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let reporter = TestSpanReporter(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", reporter: .custom(reporter), sampler: ConstantSampler(samples: false))
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
        let reporter = TestSpanReporter(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", reporter: .custom(reporter), sampler: ConstantSampler(samples: false))
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
        let reporter = TestSpanReporter(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", reporter: .custom(reporter), sampler: ConstantSampler(samples: false))
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)

        let baggage = Baggage.topLevel
        var headers = HTTPHeaders()

        tracer.inject(baggage, into: &headers, using: HTTPHeadersInjector())

        XCTAssertTrue(headers.isEmpty)
    }

    func test_creates_trace_context_for_root_span() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let reporter = TestSpanReporter(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", reporter: .custom(reporter), sampler: ConstantSampler(samples: false))
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)

        let span = tracer.startSpan(named: "test", baggage: .topLevel, ofKind: .server, at: .now())
        XCTAssertNotNil(span.baggage.traceContext)
    }

    func test_regenerates_parent_id_in_existing_trace_context() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let reporter = TestSpanReporter(eventLoop: eventLoopGroup.next())
        let settings = JaegerTracer.Settings(serviceName: "test", reporter: .custom(reporter), sampler: ConstantSampler(samples: false))
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)

        var parentBaggage = Baggage.topLevel
        parentBaggage.traceContext = TraceContext(parent: .random(), state: TraceState(rawValue: "rojo=123")!)

        let parent = tracer.startSpan(named: "test", baggage: parentBaggage, ofKind: .server, at: .now()) as! JaegerSpan
        let child = tracer.startSpan(named: "test", baggage: parent.baggage, ofKind: .server, at: .now()) as! JaegerSpan

        XCTAssertNotNil(child.baggage.traceContext)
        XCTAssertEqual(child.baggage.traceContext?.state, parentBaggage.traceContext?.state)
        XCTAssertEqual(child.baggage.traceContext?.parent.traceID, parentBaggage.traceContext?.parent.traceID)
        XCTAssertNotEqual(child.baggage.traceContext?.parent.parentID, parentBaggage.traceContext?.parent.parentID)
        XCTAssertEqual(child.baggage.traceContext?.parent.traceFlags, parentBaggage.traceContext?.parent.traceFlags)
        XCTAssertEqual(child.links.first?.baggage.traceContext, parent.baggage.traceContext)
    }

    // MARK: - Flushing

    func test_emits_spans_to_reporter_on_forceFlush() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let reporter = TestSpanReporter(eventLoop: eventLoopGroup.next())

        let settings = JaegerTracer.Settings(serviceName: "test", reporter: .custom(reporter), sampler: ConstantSampler(samples: false))
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)

        var spans = [JaegerSpan]()

        for _ in 0 ..< 10 {
            let span = tracer.startSpan(named: "test", baggage: .topLevel, ofKind: .server, at: .now())
            spans.append(span as! JaegerSpan)
            span.end()
        }

        XCTAssertEqual(reporter.numberOfFlushes, 0)

        tracer.forceFlush()

        XCTAssertEqual(reporter.numberOfFlushes, 1)
        XCTAssertEqual(reporter.flushedSpans.count, 10)
        for (index, span) in reporter.flushedSpans.enumerated() {
            XCTAssert(spans[index] === span)
        }
    }
}

private final class TestSpanReporter: SpanReporter {
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
