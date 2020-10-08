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

import BaggageContext
import Instrumentation
import Logging
import NIO
import NIOConcurrencyHelpers
import Tracing
import W3CTraceContext

public final class JaegerTracer: Tracer {
    private var spansToEmit = [JaegerSpan]()

    private let eventLoop: EventLoop
    private let settings: Settings
    private let recorder: SpanRecorder

    private var flushTask: RepeatedTask!

    private let lock = Lock()
    private let logger = Logger(label: "JaegerTracer")

    public init(settings: Settings, group: EventLoopGroup) {
        self.eventLoop = group.next()
        self.settings = settings
        switch settings.recordingStrategy {
        case .custom(let recorder):
            self.recorder = recorder
        }
        self.flushTask = self.eventLoop
            .scheduleRepeatedAsyncTask(initialDelay: self.settings.flushInterval, delay: self.settings.flushInterval) { _ in
                self.flush()
            }
    }

    public func extract<Carrier, Extractor>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extractor)
        where
        Carrier == Extractor.Carrier,
        Extractor: ExtractorProtocol
    {
        if let parent = extractor.extract(key: TraceParent.headerName, from: carrier) {
            let state = extractor.extract(key: TraceState.headerName, from: carrier) ?? ""
            baggage.traceContext = TraceContext(parent: parent, state: state)
        }
    }

    public func inject<Carrier, Injector>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Injector)
        where
        Carrier == Injector.Carrier,
        Injector: InjectorProtocol
    {
        guard let traceContext = baggage.traceContext else { return }
        injector.inject(traceContext.parent.rawValue, forKey: TraceParent.headerName, into: &carrier)
        injector.inject(traceContext.state.rawValue, forKey: TraceState.headerName, into: &carrier)
    }

    public func startSpan(
        named operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind,
        at timestamp: Timestamp
    ) -> Span {
        return JaegerSpan(
            operationName: operationName,
            kind: kind,
            startTimestamp: timestamp,
            baggage: baggage
        ) { [weak self] endedSpan in
            self?.spansToEmit.append(endedSpan)
        }
    }

    public func forceFlush() {
        self.flush()
    }

    @discardableResult
    private func flush() -> EventLoopFuture<Void> {
        let spansToFlush: ArraySlice<JaegerSpan> = self.lock.withLock {
            let spans = self.spansToEmit.prefix(self.settings.flushBatchSize)
            self.spansToEmit.removeFirst(spans.count)
            return spans
        }
        return self.recorder.flush(spans: spansToFlush, inService: self.settings.serviceName)
    }
}
