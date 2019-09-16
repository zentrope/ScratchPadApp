//
//  Page.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/4/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

// KV Compliant (for sorting in the Page Browser)
final class Page: NSObject {
    @objc let name: String
    @objc let dateCreated: Date
    @objc let dateUpdated: Date
    @objc let body: NSAttributedString

    init(name: String, dateCreated: Date, dateUpdated: Date, body: NSAttributedString) {
        self.name = name
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
        self.body = body
    }

    @objc var snippet: String {
        get {
            return body.string.clean().trim(toSize: 300)
        }
    }

    @objc var size: Int {
        get {
            return body.length
        }
    }
}
