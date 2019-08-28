//
//  Model.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

struct Page {
    var uuid: UUID
    var name: String
    var body: NSAttributedString
    var dateCreated: Date
    var dateUpdated: Date

    init(name: String, body: NSAttributedString) {
        self.uuid = UUID()
        self.name = name
        self.body = body
        self.dateCreated = Date()
        self.dateUpdated = Date()
    }

    init(uuid: UUID, name: String, body: NSAttributedString, dateCreated: Date, dateUpdated: Date) {
        self.uuid = uuid
        self.name = name
        self.body = body
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
    }

    mutating func update(_ body: NSAttributedString) {
        self.body = body
        self.dateUpdated = Date()
    }

    var index: String {
        get { return name.lowercased() }
    }

    var bodyData: Data? {
        get {
            do {
                return try body.data(from: NSMakeRange(0, body.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            }
            catch {
                print("Attributed String to Data Error: \(error)")
                return nil
            }
        }
    }
}
