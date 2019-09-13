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
}
