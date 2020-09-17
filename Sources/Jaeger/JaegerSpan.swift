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
import Tracing
import W3CTraceContext

public final class JaegerSpan: Span {
    public var attributes: SpanAttributes = [:]
    public private(set) var isRecording: Bool
    public let startTimestamp: Timestamp
    public private(set) var endTimestamp: Timestamp?
    public let context: BaggageContext

    private let operationName: String
    private let kind: SpanKind
    private let lock = Lock()
    private let record: (JaegerSpan) -> Void

    public init(
        operationName: String,
        kind: SpanKind,
        startTimestamp: Timestamp,
        context: BaggageContext,
        record: @escaping (JaegerSpan) -> Void
    ) {
        self.operationName = operationName
        self.kind = kind
        self.startTimestamp = startTimestamp

        if context.traceContext != nil {
            // TODO: Generate new parentID for this span
            self.context = context
            self.isRecording = false
        } else {
            var context = context
            // TODO: Avoid force-unwrap for empty state: https://github.com/slashmo/swift-w3c-trace-context/issues/5
            context.traceContext = TraceContext(parent: .random(), state: TraceState(rawValue: "")!)
            self.context = context
            self.isRecording = true
        }

        self.record = record
    }

    public func setStatus(_ status: SpanStatus) {}

    public func addEvent(_ event: SpanEvent) {}

    public func recordError(_ error: Error) {
        self.lock.withLockVoid {
            attributes["exception.type"] = .string(String(describing: type(of: error)))
            attributes["exception.message"] = .string(String(describing: error))
        }
    }

    public func addLink(_ link: SpanLink) {}

    public func end(at timestamp: Timestamp) {
        self.lock.withLockVoid {
            self.endTimestamp = .now()
            self.record(self)
        }
    }
}
