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

import Instrumentation

struct TestCarrier {
    private(set) var storage = [String: String]()

    subscript(key: String) -> String? {
        get {
            self.storage[key]
        }
        set {
            self.storage[key] = newValue
        }
    }

    var count: Int {
        self.storage.count
    }
}

extension TestCarrier: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, String)...) {
        self.init(storage: [String: String](uniqueKeysWithValues: elements))
    }
}

struct TestCarrierInjector: Injector {
    func inject(_ value: String, forKey key: String, into carrier: inout TestCarrier) {
        carrier[key] = value
    }
}

struct TestCarrierExtractor: Extractor {
    func extract(key: String, from carrier: TestCarrier) -> String? {
        carrier[key]
    }
}
