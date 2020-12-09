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
        let kind: SpanKind?
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
            traceID: String(describing: traceContext.parent.traceID),
            parentID: self.links.first?.baggage.traceContext?.parent.parentID,
            name: self.operationName,
            timestamp: Int64(bitPattern: self.startTimestamp.rawValue),
            duration: Int64(bitPattern: endTimestamp.rawValue) - Int64(bitPattern: self.startTimestamp.rawValue),
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
        case .stringConvertible(let value):
            return "\(value)"
        case .intArray(let value):
            return "[\(value.map { String($0) }.joined(separator: ", "))]"
        case .doubleArray(let value):
            return "[\(value.map { String($0) }.joined(separator: ", "))]"
        case .boolArray(let value):
            return "[\(value.map { String($0) }.joined(separator: ", "))]"
        case .stringArray(let value):
            return "[\(value.map { #""\#($0)""# }.joined(separator: ", "))]"
        case .stringConvertibleArray(let value):
            return "[\(value.map { #""\#(String(describing: $0))""# }.joined(separator: ", "))]"
        }
    }
}

extension JaegerSpan.ZipkinRepresentation {
    struct Endpoint: Encodable {
        var serviceName: String?
    }
}
