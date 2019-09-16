//
//  Page.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/4/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

struct Page: Hashable {
    var name: String
    var dateCreated: Date
    var dateUpdated: Date
    var body: NSAttributedString

    var snippet: String {
        get {
            return body.string.clean().trim(toSize: 300)
        }
    }

    var size: Int {
        get {
            return body.length
        }
    }
}
