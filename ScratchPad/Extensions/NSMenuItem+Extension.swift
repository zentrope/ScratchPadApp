//
//  NSMenuItem+Extension.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/7/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

extension NSMenuItem {
    convenience init(title: String, action: Selector, keyEquivalent: String, tag: Int) {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        self.tag = tag
    }
}
