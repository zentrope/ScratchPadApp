//
//  Sequence+Ext.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/15/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

extension Sequence {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>, ascending: Bool) -> [Element] {
        return sorted { a, b in
            ascending ? a[keyPath: keyPath] < b[keyPath: keyPath] : a[keyPath: keyPath] > b[keyPath: keyPath]
        }
    }
}
