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

import Tracing
import XCTest
import ZipkinReporting

final class SpanKindZipkinEncodingTests: XCTestCase {
    func test_converts_spanKind_to_zipkin_spanKind() throws {
        let jsonEncoder = JSONEncoder()

        let clientString = String(data: try jsonEncoder.encode(SpanKind.client), encoding: .utf8)
        XCTAssertEqual(clientString, #""CLIENT""#)

        let serverString = String(data: try jsonEncoder.encode(SpanKind.server), encoding: .utf8)
        XCTAssertEqual(serverString, #""SERVER""#)

        let consumerString = String(data: try jsonEncoder.encode(SpanKind.consumer), encoding: .utf8)
        XCTAssertEqual(consumerString, #""CONSUMER""#)

        let producerString = String(data: try jsonEncoder.encode(SpanKind.producer), encoding: .utf8)
        XCTAssertEqual(producerString, #""PRODUCER""#)

        let internalString = String(data: try jsonEncoder.encode(SpanKind.internal), encoding: .utf8)
        XCTAssertEqual(internalString, "null")
    }
}
