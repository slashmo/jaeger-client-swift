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

import W3CTraceContext

public struct ProbabilisticSampler: Sampler {
    private let samplingRate: Double
    private let lowUpperBound: UInt64

    public init(samplingRate: Double = 0.001) {
        precondition(
            samplingRate > 0 && samplingRate < 1,
            "The sampling rate must be greater than 0.0 and less than 1.0. Please use ConstantSampler instead."
        )
        self.samplingRate = samplingRate
        self.lowUpperBound = UInt64(samplingRate * Double(UInt64.max))
    }

    public func sample(operationName: String, traceID: TraceID) -> SamplingStatus {
        SamplingStatus(isSampled: traceID.low < self.lowUpperBound, attributes: [
            "sampler.type": "probabilistic",
            "sampler.param": .double(self.samplingRate),
        ])
    }
}
