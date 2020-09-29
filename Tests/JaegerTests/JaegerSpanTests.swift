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
@testable import Jaeger
import Tracing
import W3CTraceContext
import XCTest

final class JaegerSpanTests: XCTestCase {
    func test_adds_trace_context_if_not_yet_recorded() {
        let span = JaegerSpan()

        XCTAssertNotNil(span.context.traceContext)
    }

    func test_recordError_sets_exception_attributes() {
        let span = JaegerSpan()
        XCTAssertEqual(span.attributes, [:])

        span.recordError(TestError.test)
        XCTAssertEqual(span.attributes, [
            "exception.type": "TestError",
            "exception.message": "test",
        ])
    }

    func test_calls_report_on_end() {
        var reportedSpan: JaegerSpan?

        let span = JaegerSpan { span in
            reportedSpan = span
        }
        span.end()

        XCTAssert(reportedSpan === span)
    }

    func test_calls_report_on_end_only_once() {
        var invocationCount = 0

        let span = JaegerSpan { _ in
            invocationCount += 1
        }

        span.end()
        span.end()
        span.end()

        XCTAssertEqual(invocationCount, 1)
    }

    func test_creates_trace_context_for_root_span() {
        let span = JaegerSpan()

        XCTAssertNotNil(span.context.traceContext)
    }

    func test_regenerates_parent_id_in_existing_trace_context() {
        var context = BaggageContext()
        context.traceContext = TraceContext(parent: .random(), state: TraceState(rawValue: "rojo=123")!)

        let span = JaegerSpan(context: context)

        XCTAssertNotNil(span.context.traceContext)
        XCTAssertEqual(span.context.traceContext?.state, context.traceContext?.state)
        XCTAssertEqual(span.context.traceContext?.parent.traceID, context.traceContext?.parent.traceID)
        XCTAssertNotEqual(span.context.traceContext?.parent.parentID, context.traceContext?.parent.parentID)
        XCTAssertEqual(span.context.traceContext?.parent.traceFlags, context.traceContext?.parent.traceFlags)
    }
}

extension JaegerSpan {
    fileprivate convenience init(
        context: BaggageContext = .init(),
        onReport: @escaping (JaegerSpan) -> Void = { _ in }
    ) {
        self.init(operationName: "test", kind: .server, startTimestamp: .now(), context: context, onReport: onReport)
    }
}

private enum TestError: Error {
    case test
}
