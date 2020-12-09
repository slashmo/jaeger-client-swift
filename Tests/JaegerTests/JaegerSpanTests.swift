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

@testable import Jaeger
import Tracing
import W3CTraceContext
import XCTest

final class JaegerSpanTests: XCTestCase {
    func test_recordError_sets_exception_attributes() {
        let span = JaegerSpan(sampled: false, onEnd: { _ in })
        XCTAssertEqual(span.attributes, [:])

        span.recordError(TestError.test)
        XCTAssertEqual(span.attributes, [
            "exception.type": "TestError",
            "exception.message": "test",
        ])
    }

    func test_calls_onEnd_if_sampled() {
        var reportedSpan: JaegerSpan?

        let span = JaegerSpan(sampled: true) { span in
            reportedSpan = span
        }
        span.end()

        XCTAssert(reportedSpan === span)
    }

    func test_calls_onEnd_if_not_sampled() {
        var reportedSpan: JaegerSpan?

        let span = JaegerSpan(sampled: false) { span in
            reportedSpan = span
        }
        span.end()

        XCTAssert(reportedSpan === span)
    }

    func test_calls_report_on_end_only_once() {
        var invocationCount = 0

        let span = JaegerSpan(sampled: true) { _ in
            invocationCount += 1
        }

        span.end()
        span.end()
        span.end()

        XCTAssertEqual(invocationCount, 1)
    }
}

extension JaegerSpan {
    fileprivate convenience init(sampled: Bool, onEnd: @escaping (JaegerSpan) -> Void) {
        var baggage = Baggage.topLevel
        var traceContext = TraceContext(parent: .random(), state: .none)
        traceContext.sampled = sampled
        baggage.traceContext = traceContext
        self.init(operationName: "test", kind: .client, startTimestamp: .now(), baggage: baggage, onEnd: onEnd)
    }
}

private enum TestError: Error {
    case test
}
