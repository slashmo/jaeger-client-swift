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
import Foundation
@testable import Jaeger
import W3CTraceContext
import XCTest
@testable import ZipkinReporting

final class ZipkinSpanRepresentationTests: XCTestCase {
    func test_encode_span_to_zipkin_json() {
        var baggage = Baggage.topLevel
        baggage.traceContext = TraceContext(parent: .random(), state: .none)

        let parent = JaegerSpan(
            operationName: "test",
            kind: .client,
            startTimestamp: .now(),
            baggage: .topLevel,
            onReport: { _ in }
        )

        let child = JaegerSpan(
            operationName: "test",
            kind: .client,
            startTimestamp: .now(),
            baggage: baggage,
            onReport: { _ in }
        )
        child.addLink(parent)
        child.attributes["a"] = .string("1")
        child.attributes["b"] = .int(1)
        child.attributes["c"] = .double(1.1)
        child.attributes["d"] = .bool(true)
        child.attributes["e"] = .array([.string("1"), .string("2")])
        child.attributes["f"] = .stringConvertible("1")
        child.end()

        let zipkinRepresentation = child.zipkinRepresentation(forService: "test")

        XCTAssertEqual(zipkinRepresentation?.id, child.baggage.traceContext?.parent.parentID)
        XCTAssertEqual(zipkinRepresentation?.traceID, child.baggage.traceContext?.parent.traceID)
        XCTAssertEqual(zipkinRepresentation?.parentID, parent.baggage.traceContext?.parent.parentID)
        XCTAssertEqual(zipkinRepresentation?.name, "test")
        XCTAssertEqual(zipkinRepresentation?.kind, .client)
        XCTAssertEqual(zipkinRepresentation?.localEndpoint.serviceName, "test")
        XCTAssertEqual(zipkinRepresentation?.tags["a"], "1")
        XCTAssertEqual(zipkinRepresentation?.tags["b"], "1")
        XCTAssertEqual(zipkinRepresentation?.tags["c"], "1.1")
        XCTAssertEqual(zipkinRepresentation?.tags["d"], "true")
        XCTAssertEqual(zipkinRepresentation?.tags["e"], "[1, 2]")
        XCTAssertEqual(zipkinRepresentation?.tags["f"], "1")
    }

    func test_encode_span_to_zipkin_json_without_ending() {
        var baggage = Baggage.topLevel
        baggage.traceContext = TraceContext(parent: .random(), state: .none)

        let span = JaegerSpan(
            operationName: "test",
            kind: .client,
            startTimestamp: .now(),
            baggage: baggage,
            onReport: { _ in }
        )

        XCTAssertNil(span.zipkinRepresentation(forService: "test"))
    }
}
