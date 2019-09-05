//
//  PageValue.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/4/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import CloudKit
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "PageValue")

struct PageValue {

    var name: String
    var dateCreated: Date
    var dateUpdated: Date
    var body: NSAttributedString

    // Should be an extension in the LocalDatabase
    static func fromManagedObject(page: PageMO) -> PageValue {
        return PageValue(
            name: page.name ?? "unknown",
            dateCreated: page.dateCreated ?? Date(),
            dateUpdated: page.dateUpdated ?? Date(),
            body: page.body ?? NSAttributedString()
        )
    }

    // Should be an extension in the CloudDB?
    static func fromRecord(record: CKRecord) -> PageValue? {

        guard let rtfString = record["body"] as? String else {
            os_log("%{public}s", log: logger, type: .error, "Unable to retrieve record's body.")
            return nil
        }

        guard let data = rtfString.data(using: .utf8) else {
            os_log("%{public}s", log: logger, type: .error, "Unable to convert rtf string to data")
            return nil
        }

        guard let body = NSAttributedString(rtf: data, documentAttributes: nil) else {
            os_log("%{public}s", log: logger, type: .error, "Unable to create attributed string from body data.")
            return nil
        }

        guard let dateCreated = record["dateCreated"] as? Date else {
            os_log("%{public}s", log: logger, type: .error, "Unable to retrieve date created from record.")
            return nil
        }

        guard let dateUpdated = record["dateUpdated"] as? Date else {
            os_log("%{public}s", log: logger, type: .error, "Unable to retrieve date updated from record.")
            return nil
        }

        guard let name = record["name"] as? String else {
            os_log("%{public}s", log: logger, type: .error, "Unable to retrieve name from record.")
            return nil
        }

        let page = PageValue(
            name: name,
            dateCreated: dateCreated,
            dateUpdated: dateUpdated,
            body: body
        )
        return page
    }

}
