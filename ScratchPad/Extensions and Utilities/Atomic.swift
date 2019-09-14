//
//  Atomic.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/31/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

class Atomic<T> {

    private var value: T

    private let queue = DispatchQueue(label: "atom." + UUID().uuidString)

    init(_ value: T) {
        self.value = value
    }

    func swap(_ f: (inout T) -> Void) {
        queue.sync {
            var oldValue = self.value
            f(&oldValue)
            self.value = oldValue
        }
    }

    func reset(_ value: T) {
        queue.sync {
            self.value = value
        }
    }

    func deref() -> T {
        return queue.sync { let copy = self.value ; return copy }
    }
}
