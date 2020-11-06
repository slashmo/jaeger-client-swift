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
import W3CTraceContext

public struct SamplingStatus {
    public let isSampled: Bool
    public let attributes: SpanAttributes
}

public protocol Sampler {
    func sample(operationName: String, traceID: TraceID) -> SamplingStatus
}
