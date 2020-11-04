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
}

extension JaegerSpan {
    fileprivate convenience init(
        baggage: Baggage = .topLevel,
        onReport: @escaping (JaegerSpan) -> Void = { _ in }
    ) {
        self.init(operationName: "test", kind: .server, startTimestamp: .now(), baggage: baggage, onReport: onReport)
    }
}

private enum TestError: Error {
    case test
}
