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

    func test_extract_w3c_trace_context_into_baggage() throws {
        let tracer: JaegerTracer = .test()

        let traceContext = TraceContext(parent: .random(), state: TraceState(rawValue: "rojo=123")!)
        var baggage = Baggage.topLevel

        tracer.extract(
            [TraceParent.headerName: traceContext.parent.rawValue, TraceState.headerName: traceContext.state.rawValue],
            into: &baggage,
            using: HTTPHeadersExtractor()
        )

        XCTAssertEqual(baggage.traceContext, traceContext)
    }

    func test_extract_w3c_trace_context_without_state_into_baggage() throws {
        let tracer: JaegerTracer = .test()

        let traceContext = TraceContext(parent: .random(), state: .none)
        var baggage = Baggage.topLevel

        tracer.extract(
            [TraceParent.headerName: traceContext.parent.rawValue],
            into: &baggage,
            using: HTTPHeadersExtractor()
        )

        XCTAssertEqual(baggage.traceContext, traceContext)
    }

    func test_extract_missing_w3c_trace_context_into_baggage() throws {
        let tracer: JaegerTracer = .test()

        var baggage = Baggage.topLevel

        tracer.extract([:], into: &baggage, using: HTTPHeadersExtractor())

        XCTAssertNil(baggage.traceContext)
    }

    func test_inject_w3c_trace_context_into_headers() throws {
        let tracer: JaegerTracer = .test()

        let traceContext = TraceContext(parent: .random(), state: .none)
        var baggage = Baggage.topLevel
        baggage.traceContext = traceContext
        var headers = HTTPHeaders()

        tracer.inject(baggage, into: &headers, using: HTTPHeadersInjector())

        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(headers.first(name: TraceParent.headerName), traceContext.parent.rawValue)
        XCTAssertEqual(headers.first(name: TraceState.headerName), traceContext.state.rawValue)
    }

    func test_inject_missing_w3c_trace_context_into_headers() throws {
        let tracer: JaegerTracer = .test()

        let baggage = Baggage.topLevel
        var headers = HTTPHeaders()

        tracer.inject(baggage, into: &headers, using: HTTPHeadersInjector())

        XCTAssert(headers.isEmpty)
    }

    func test_creates_trace_context_for_root_span() throws {
        let tracer: JaegerTracer = .test()

        let span = tracer.startSpan(named: "test", baggage: .topLevel, ofKind: .server)

        XCTAssertNotNil(span.baggage.traceContext)
    }

    func test_regenerates_parent_id_in_existing_trace_context() throws {
        let tracer: JaegerTracer = .test()

        var childBaggage = Baggage.topLevel
        childBaggage.traceContext = TraceContext(parent: .random(), state: TraceState(rawValue: "rojo=123")!)
        let parent = tracer.startSpan(named: "client", baggage: childBaggage, ofKind: .client)
        let child = tracer.startSpan(named: "server", baggage: parent.baggage, ofKind: .server) as! JaegerSpan

        XCTAssertNotNil(child.baggage.traceContext)
        XCTAssertEqual(child.baggage.traceContext?.state, childBaggage.traceContext?.state)
        XCTAssertEqual(child.baggage.traceContext?.parent.traceID, childBaggage.traceContext?.parent.traceID)
        XCTAssertNotEqual(child.baggage.traceContext?.parent.parentID, childBaggage.traceContext?.parent.parentID)
        XCTAssertEqual(child.baggage.traceContext?.parent.traceFlags, childBaggage.traceContext?.parent.traceFlags)
        XCTAssertEqual(child.links.first?.baggage.traceContext, parent.baggage.traceContext)
    }

    // MARK: - Flushing

    func test_flushes_sampled_spans() throws {
        let (tracer, reporter) = JaegerTracer.test(sampler: ConstantSampler(samples: true))

        let spans = (0 ..< 10).map { _ in tracer.startSpan(named: "test", baggage: .topLevel) }
        spans.forEach { $0.end() }

        tracer.forceFlush()

        XCTAssertEqual(reporter.numberOfFlushes, 1)
        XCTAssertEqual(reporter.flushedSpans.count, 10)
        for (index, span) in reporter.flushedSpans.enumerated() {
            XCTAssert(spans[index] === span)
        }
    }

    func test_does_not_flush_unsampled_spans() throws {
        let (tracer, reporter) = JaegerTracer.test(sampler: ConstantSampler(samples: false))

        let spans = (0 ..< 10).map { _ in tracer.startSpan(named: "test", baggage: .topLevel) }
        spans.forEach { $0.end() }

        tracer.forceFlush()

        XCTAssertEqual(reporter.numberOfFlushes, 0)
    }
}

extension JaegerTracer {
    fileprivate static func test(
        sampler: Sampler = ConstantSampler(samples: false),
        file: StaticString = #file,
        line: UInt = #line
    ) -> (JaegerTracer, TestSpanReporter) {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let reporter = TestSpanReporter(eventLoop: eventLoopGroup.next())

        let settings = JaegerTracer.Settings(serviceName: "test", reporter: .custom(reporter), sampler: sampler)
        let tracer = JaegerTracer(settings: settings, group: eventLoopGroup)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully(), file: file, line: line) }
        return (tracer, reporter)
    }

    fileprivate static func test(
        sampler: Sampler = ConstantSampler(samples: false),
        file: StaticString = #file,
        line: UInt = #line
    ) -> JaegerTracer {
        self.test(sampler: sampler).0
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
