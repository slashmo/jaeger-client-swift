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

import NIO

extension JaegerTracer {
    public struct Settings {
        public var serviceName: String
        public var reporter: Reporter
        public var flushInterval: TimeAmount
        public var flushTimeout: TimeAmount
        public var flushBatchSize: Int
        public var flushMaxBacklog: Int

        public init(
            serviceName: String,
            reporter: Reporter,
            flushInterval: TimeAmount = .seconds(1),
            flushTimeout: TimeAmount = .seconds(5),
            flushBatchSize: Int = 100,
            flushMaxBacklog: Int = 1000
        ) {
            self.serviceName = serviceName
            self.reporter = reporter
            self.flushInterval = flushInterval
            self.flushTimeout = flushTimeout
            self.flushBatchSize = flushBatchSize
            self.flushMaxBacklog = flushMaxBacklog
        }
    }

    public enum Reporter {
        case custom(SpanReporter)
    }
}
