//
//  Page+Extension.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/31/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import CloudKit

extension Article {

    static func fromCloud(_ article: CKRecord) -> Article? {

        guard let rtfString = article["body"] as? String else {
            print("ERROR (fetch): unable to convert body to data")
            return nil
        }

        guard let data = rtfString.data(using: .utf8) else {
            print("ERROR (fetch): unable to convert body rtf to data")
            return nil
        }

        // Maybe make names enums for string constants?
        if let name = article["name"] as? String,
            let uuid = UUID(uuidString: article["uuid"] ?? UUID().uuidString),
            let dateCreated = article["dateCreated"] as? Date,
            let dateUpdated = article["dateUpdated"] as? Date,
            let body = NSAttributedString(rtf: data, documentAttributes: nil) {
            return Article(uuid: uuid, name: name, body: body, dateCreated: dateCreated, dateUpdated: dateUpdated)
        }

        print("ERROR (fetch): unable to convert record to page")
        return nil

    }
}
