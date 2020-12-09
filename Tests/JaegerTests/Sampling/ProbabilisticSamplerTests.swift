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

import Jaeger
import W3CTraceContext
import XCTest

final class ProbabilisticSamplerTests: XCTestCase {
    func test_sample_comparesLowIDPartToUpperBound() {
        let samplingRate = Double.random(in: Double.leastNonzeroMagnitude ..< 1.0)
        let upperBound = UInt64(samplingRate * Double(UInt64.max))
        let sampler = ProbabilisticSampler(samplingRate: samplingRate)

        do {
            let traceID = TraceID(high: 0, low: upperBound)
            let samplingStatus = sampler.sample(operationName: "test", traceID: traceID)
            XCTAssertFalse(samplingStatus.isSampled)
        }

        do {
            let traceID = TraceID(high: 0, low: upperBound - 1)
            let samplingStatus = sampler.sample(operationName: "test", traceID: traceID)
            XCTAssert(samplingStatus.isSampled)
        }
    }

    func test_sample_returnsSamplingStatus_withAttributes() {
        let sampler = ProbabilisticSampler(samplingRate: 0.1)

        let samplingStatus = sampler.sample(operationName: "test", traceID: .random())

        XCTAssertEqual(samplingStatus.attributes["sampler.type"]?.toSpanAttribute(), "probabilistic")
        XCTAssertEqual(samplingStatus.attributes["sampler.param"]?.toSpanAttribute(), 0.1)
    }
}
