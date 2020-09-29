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
import Instrumentation
import NIO
import Tracing
import W3CTraceContext

public final class JaegerTracer: Tracer {
    private var spansToEmit = [JaegerSpan]()

    private let eventLoop: EventLoop
    private let flushInterval = TimeAmount.seconds(1)
    private let flushBatchSize = 100
    private let recorder: SpanRecorder

    private var flushTask: RepeatedTask!

    private let lock = Lock()

    public init(settings: Settings, group: EventLoopGroup) {
        self.eventLoop = group.next()
        switch settings.recordingStrategy {
        case .custom(let recorder):
            self.recorder = recorder
        }
        self.flushTask = self.eventLoop
            .scheduleRepeatedAsyncTask(initialDelay: self.flushInterval, delay: self.flushInterval) { _ in
                self.flush()
            }
    }

    public func extract<Carrier, Extractor>(
        _ carrier: Carrier,
        into context: inout BaggageContext,
        using extractor: Extractor
    )
        where
        Carrier == Extractor.Carrier,
        Extractor: ExtractorProtocol
    {
        if let parent = extractor.extract(key: TraceParent.headerName, from: carrier) {
            let state = extractor.extract(key: TraceState.headerName, from: carrier) ?? ""
            context.traceContext = TraceContext(parent: parent, state: state)
        }
    }

    public func inject<Carrier, Injector>(
        _ context: BaggageContext,
        into carrier: inout Carrier,
        using injector: Injector
    )
        where
        Carrier == Injector.Carrier,
        Injector: InjectorProtocol
    {
        guard let traceContext = context.traceContext else { return }
        injector.inject(traceContext.parent.rawValue, forKey: TraceParent.headerName, into: &carrier)
        injector.inject(traceContext.state.rawValue, forKey: TraceState.headerName, into: &carrier)
    }

    public func startSpan(
        named operationName: String,
        context: BaggageContextCarrier,
        ofKind kind: SpanKind,
        at timestamp: Timestamp
    ) -> Span {
        return JaegerSpan(
            operationName: operationName,
            kind: kind,
            startTimestamp: timestamp,
            context: context.baggage
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
            let spans = self.spansToEmit.prefix(self.flushBatchSize)
            self.spansToEmit.removeFirst(spans.count)
            return spans
        }
        return self.recorder.flush(spans: spansToFlush)
    }
}
