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

import Jaeger
import Tracing

extension JaegerSpan {
    struct ZipkinRepresentation: Encodable {
        let id: String
        let traceID: String
        let parentID: String?
        let name: String
        let timestamp: Int64
        let duration: Int64
        let kind: SpanKind
        let localEndpoint: Endpoint
        let remoteEndpoint: Endpoint?
        let tags: [String: String]

        private enum CodingKeys: String, CodingKey {
            case id, name, timestamp, duration, kind, localEndpoint, tags
            case traceID = "traceId"
            case parentID = "parentId"
        }
    }

    func zipkinRepresentation(forService serviceName: String) -> ZipkinRepresentation? {
        guard let traceContext = baggage.traceContext, let endTimestamp = self.endTimestamp else { return nil }

        var tags = [String: String]()
        self.attributes.forEach { label, attribute in
            tags[label] = attribute.asString()
        }

        return ZipkinRepresentation(
            id: traceContext.parent.parentID,
            traceID: traceContext.parent.traceID,
            parentID: self.links.first?.baggage.traceContext?.parent.parentID,
            name: self.operationName,
            timestamp: self.startTimestamp.microsSinceEpoch,
            duration: endTimestamp.microsSinceEpoch - self.startTimestamp.microsSinceEpoch,
            kind: kind,
            localEndpoint: .init(serviceName: serviceName),
            remoteEndpoint: nil,
            tags: tags
        )
    }
}

extension SpanAttribute {
    fileprivate func asString() -> String {
        switch self {
        case .string(let value):
            return "\(value)"
        case .int(let value):
            return "\(value)"
        case .double(let value):
            return "\(value)"
        case .bool(let value):
            return "\(value)"
        case .array(let value):
            return "[\(value.map { $0.asString() }.joined(separator: ", "))]"
        case .stringConvertible(let value):
            return "\(value)"
        case .__namespace:
            fatalError("__namespace MUST NOT be stored not can be extracted from using anyValue")
        }
    }
}

extension JaegerSpan.ZipkinRepresentation {
    struct Endpoint: Encodable {
        var serviceName: String?
    }
}
