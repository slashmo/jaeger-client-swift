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
import Foundation
import Jaeger
import Logging
import NIO
import NIOHTTP1

extension JaegerTracer.RecordingStrategy {
    public static func zipkin(collectorHost: String, collectorPort: UInt, eventLoopGroup: EventLoopGroup) -> Self {
        .custom(
            ZipkinJSONHTTPRecorder(
                collectorHost: collectorHost,
                collectorPort: collectorPort,
                eventLoopGroup: eventLoopGroup
            )
        )
    }
}

private final class ZipkinJSONHTTPRecorder: SpanRecorder {
    private let eventLoopGroup: EventLoopGroup
    private let jsonEncoder = JSONEncoder()
    private let collectorHost: String
    private let collectorPort: UInt

    fileprivate init(collectorHost: String, collectorPort: UInt, eventLoopGroup: EventLoopGroup) {
        self.collectorHost = collectorHost
        self.collectorPort = collectorPort
        self.eventLoopGroup = eventLoopGroup
    }

    func flush(spans: ArraySlice<JaegerSpan>, inService serviceName: String) -> EventLoopFuture<Void> {
        guard !spans.isEmpty else {
            return self.eventLoopGroup.next().makeSucceededFuture(())
        }

        let zipkinSpans = spans.compactMap { $0.zipkinRepresentation(forService: serviceName) }
        do {
            let encodedZipkinSpans = try self.jsonEncoder.encode(zipkinSpans)
            let bootstrap = ClientBootstrap(group: self.eventLoopGroup)
                .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .channelInitializer { channel in
                    channel.pipeline
                        .addHTTPClientHandlers(position: .first, leftOverBytesStrategy: .fireError)
                        .flatMap {
                            let clientHandler = HTTPClientHandler(
                                sendingSpanData: encodedZipkinSpans,
                                toHost: self.collectorHost,
                                port: self.collectorPort
                            )
                            return channel.pipeline.addHandler(clientHandler)
                        }
                }
            return bootstrap.connect(host: self.collectorHost, port: Int(self.collectorPort)).flatMap { $0.closeFuture }
        } catch {
            return self.eventLoopGroup.next().makeFailedFuture(error)
        }
    }
}

private final class HTTPClientHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPClientRequestPart

    private let spanData: Data
    private let host: String
    private let port: UInt

    init(sendingSpanData spanData: Data, toHost host: String, port: UInt) {
        self.spanData = spanData
        self.host = host
        self.port = port
    }

    func channelActive(context: ChannelHandlerContext) {
        let bodyBuffer = context.channel.allocator.buffer(bytes: self.spanData)
        let headers: HTTPHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json; charset=utf-8",
            "Content-Length": "\(bodyBuffer.readableBytes)",
            "Host": "\(self.host):\(self.port)",
        ]
        let requestHead = HTTPRequestHead(
            version: .init(major: 1, minor: 1),
            method: .POST,
            uri: "/api/v2/spans",
            headers: headers
        )
        context.write(self.wrapOutboundOut(.head(requestHead)), promise: nil)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(bodyBuffer))), promise: nil)
        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.fireChannelRead(data)
        if case .end = self.unwrapInboundIn(data) {
            context.close(promise: nil)
        }
    }
}
