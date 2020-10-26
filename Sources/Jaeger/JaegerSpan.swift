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
import NIOConcurrencyHelpers
import Tracing
import W3CTraceContext

public final class JaegerSpan: Span {
    public var attributes: SpanAttributes = [:]
    public private(set) var isRecording: Bool
    public let startTimestamp: Timestamp
    public let baggage: Baggage
    public private(set) var endTimestamp: Timestamp?
    public let operationName: String
    public let kind: SpanKind
    public private(set) var links = [SpanLink]()

    private let lock = Lock()
    private let onReport: (JaegerSpan) -> Void

    init(
        operationName: String,
        kind: SpanKind,
        startTimestamp: Timestamp,
        baggage: Baggage,
        onReport: @escaping (JaegerSpan) -> Void
    ) {
        self.operationName = operationName
        self.kind = kind
        self.startTimestamp = startTimestamp
        self.onReport = onReport

        if baggage.traceContext != nil {
            var childBaggage = baggage
            childBaggage.traceContext?.regenerateParentID()
            self.baggage = childBaggage
            self.isRecording = false
            self.addLink(SpanLink(baggage: baggage))
        } else {
            var baggage = baggage
            baggage.traceContext = TraceContext(parent: .random(), state: .none)
            self.baggage = baggage
            self.isRecording = true
        }
    }

    public func setStatus(_ status: SpanStatus) {}

    public func addEvent(_ event: SpanEvent) {}

    public func recordError(_ error: Error) {
        self.lock.withLockVoid {
            attributes["exception.type"] = .string(String(describing: type(of: error)))
            attributes["exception.message"] = .string(String(describing: error))
        }
    }

    public func addLink(_ link: SpanLink) {
        self.lock.withLockVoid {
            links.append(link)
        }
    }

    public func end(at timestamp: Timestamp) {
        self.lock.withLockVoid {
            guard self.endTimestamp == nil else { return }
            self.endTimestamp = timestamp
            self.onReport(self)
        }
    }
}
