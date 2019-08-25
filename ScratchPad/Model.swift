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

    var index: String {
        get { return name.lowercased() }
    }

    enum CodingKeys: String, CodingKey {
        case uuid, name, body, dateCreated, dateUpdated
    }

    init(name: String, body: NSAttributedString) {
        self.uuid = UUID()
        self.name = name
        self.body = body
        self.dateCreated = Date()
        self.dateUpdated = Date()
    }

    mutating func update(_ body: NSAttributedString) {
        self.body = body
        self.dateUpdated = Date()
    }
}

extension Page: Decodable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try values.decode(UUID.self, forKey: .uuid)
        name = try values.decode(String.self, forKey: .name)
        let _data = try values.decode(Data.self, forKey: .body)
        body = NSAttributedString(rtf: _data, documentAttributes: nil)!
        dateCreated = try values.decode(Date.self, forKey: .dateCreated)
        dateUpdated = try values.decode(Date.self, forKey: .dateUpdated)
    }
}

extension Page: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(name, forKey: .name)
        let _data = try body.data(from: NSMakeRange(0, body.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        try container.encode(_data, forKey: .body)
        try container.encode(dateCreated, forKey: .dateCreated)
        try container.encode(dateUpdated, forKey: .dateUpdated)
    }
}
