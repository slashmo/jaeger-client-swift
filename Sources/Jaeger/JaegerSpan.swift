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

import struct Dispatch.DispatchWallTime
import NIOConcurrencyHelpers
import Tracing
import W3CTraceContext

public final class JaegerSpan: Span {
    public var attributes: SpanAttributes = [:]

    public var isRecording: Bool {
        self.baggage.traceContext?.sampled ?? false
    }

    public let startTimestamp: DispatchWallTime
    public let baggage: Baggage
    public private(set) var endTimestamp: DispatchWallTime?
    public let operationName: String
    public let kind: SpanKind
    public private(set) var links = [SpanLink]()

    private let lock = Lock()
    private let onEnd: (JaegerSpan) -> Void

    init(
        operationName: String,
        kind: SpanKind,
        startTimestamp: DispatchWallTime,
        baggage: Baggage,
        onEnd: @escaping (JaegerSpan) -> Void
    ) {
        self.operationName = operationName
        self.kind = kind
        self.startTimestamp = startTimestamp
        self.onEnd = onEnd
        self.baggage = baggage
    }

    public func setStatus(_ status: SpanStatus) {}

    public func addEvent(_ event: SpanEvent) {}

    public func recordError(_ error: Error) {
        self.lock.withLockVoid {
            attributes["exception.type"] = String(describing: type(of: error))
            attributes["exception.message"] = String(describing: error)
        }
    }

    public func addLink(_ link: SpanLink) {
        self.lock.withLockVoid {
            links.append(link)
        }
    }

    public func end(at timestamp: DispatchWallTime) {
        self.lock.withLockVoid {
            guard self.endTimestamp == nil else { return }
            self.endTimestamp = timestamp
            self.onEnd(self)
        }
    }
}
