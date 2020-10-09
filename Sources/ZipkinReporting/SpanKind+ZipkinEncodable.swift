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

extension SpanKind: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .client:
            try container.encode("CLIENT")
        case .server:
            try container.encode("SERVER")
        case .consumer:
            try container.encode("CONSUMER")
        case .producer:
            try container.encode("PRODUCER")
        case .internal:
            try container.encodeNil()
        }
    }
}
