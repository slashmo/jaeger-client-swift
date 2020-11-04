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
    private let reporter: SpanReporter

    private var flushTask: RepeatedTask!

    private let lock = Lock()

    public init(settings: Settings, group: EventLoopGroup) {
        self.eventLoop = group.next()
        self.settings = settings
        switch settings.reporter {
        case .custom(let reporter):
            self.reporter = reporter
        }
        self.flushTask = self.eventLoop
            .scheduleRepeatedAsyncTask(
                initialDelay: self.settings.flushInterval,
                delay: self.settings.flushInterval
            ) { _ in
            self.flush()
        }
    }

    public func extract<Carrier, Extractor>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extractor)
        where
        Carrier == Extractor.Carrier,
        Extractor: ExtractorProtocol {
        if let parent = extractor.extract(key: TraceParent.headerName, from: carrier) {
            let state = extractor.extract(key: TraceState.headerName, from: carrier) ?? ""
            baggage.traceContext = TraceContext(parent: parent, state: state)
        }
    }

    public func inject<Carrier, Injector>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Injector)
        where
        Carrier == Injector.Carrier,
        Injector: InjectorProtocol {
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
        let parentBaggage = baggage
        var childBaggage = baggage
        var samplingAttributes: SpanAttributes = [:]

        if parentBaggage.traceContext != nil {
            // reuse trace-id and trace flags from parent, but generate new parent id
            childBaggage.traceContext?.regenerateParentID()
        } else {
            // start a new trace context
            var traceContext = TraceContext(parent: .random(), state: .none)
            let samplingStatus = self.settings.sampler.sample(
                operationName: operationName,
                traceID: traceContext.parent.traceID
            )
            samplingAttributes = samplingStatus.attributes
            traceContext.sampled = samplingStatus.isSampled
            childBaggage.traceContext = traceContext
        }

        let span = JaegerSpan(
            operationName: operationName,
            kind: kind,
            startTimestamp: timestamp,
            baggage: childBaggage
        ) { [weak self] endedSpan in
            guard endedSpan.isRecording else { return }
            self?.spansToEmit.append(endedSpan)
        }

        // link as child of previous trace context
        if parentBaggage.traceContext != nil {
            span.addLink(SpanLink(baggage: parentBaggage))
        }

        // add sampling attributes
        samplingAttributes.forEach { key, attribute in
            // TODO: `SpanAttributes.merge`?
            span.attributes[key] = attribute
        }

        return span
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
        guard !spansToFlush.isEmpty else { return self.eventLoop.makeSucceededFuture(()) }
        return self.reporter.flush(spans: spansToFlush, inService: self.settings.serviceName)
    }
}
