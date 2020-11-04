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

public final class ConstantSampler: Sampler {
    private let samples: Bool

    public init(samples: Bool) {
        self.samples = samples
    }

    public func sample(operationName: String, traceID: String) -> SamplingStatus {
        SamplingStatus(isSampled: self.samples, attributes: [
            "sampler.type": "const",
            "sampler.param": self.samples ? "true" : "false",
        ])
    }
}
