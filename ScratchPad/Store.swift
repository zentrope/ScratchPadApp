//
//  Store.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa
import CloudKit

class Store {

    static let shared = Store()

    private let mainArticle = "Main"

    var names = [String]()

    func mainPage() -> Page {
        names = findNames()
        return self[mainArticle]
    }

    subscript(index: String) -> Page {
        get {
            let page = getInCloud(index.lowercased()) ?? newPage(index)
            names.append(page.name)
            return page
        }
    }

    func save(_ page: Page) {
        DispatchQueue.global().async {
            self.updateInCloud(page)
        }
    }

    private let standardAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 16.0),
        .foregroundColor: NSColor.controlTextColor
    ]

    private func newPage(_ name: String) -> Page {
        let index = name.lowercased()
        let message = index == mainArticle.lowercased() ? "Welcome!\n\n" : "\(name)\n\n"
        let body = NSAttributedString(string: message, attributes: standardAttributes)
        let page = Page(name: name, body: body)

        DispatchQueue.global().async {
            self.createInCloud(page)
        }

        names.append(page.name)
        return page
    }
}

// MARK: - Cloud Functions

extension Store {

    // https://stackoverflow.com/q/40847040
    private func findNames() -> [String] {
        var names = [String]()

        let db = CKContainer.default().privateCloudDatabase
        let predicate = NSPredicate(value: true)

        // Fixme: Doesn't seem to be a way to set the recordName index.

//        <CKError 0x600000c79dd0: "Invalid Arguments" (12/2015);
//                 server message = "Field 'recordName' is not marked queryable";
//                 uuid = 6DF6BC6D-D3A3-4BAD-A209-57C4B0F4B919;
//                 container ID = "iCloud.com.zentrope.ScratchPad">

        let query = CKQuery(recordType: "Article", predicate: predicate)

        let lock = DispatchSemaphore(value: 0)

        var op = CKQueryOperation(query: query)
        op.desiredKeys = ["name"]
        op.resultsLimit = 1000

        op.recordFetchedBlock = { record in
            print("find names: record = \(record)")
            if let name = record["name"] as? String {
                names.append(name)
            }
        }

        op.queryCompletionBlock = { cursor, error in
            if let error = error {
                print("ERROR (query): \(error)")
                lock.signal()
                return
            }

            if cursor != nil {

                // Figure this out: how should this actually work?
                let qNext = CKQueryOperation(cursor: cursor!)
                qNext.resultsLimit = op.resultsLimit
                qNext.queryCompletionBlock = op.queryCompletionBlock
                qNext.desiredKeys = op.desiredKeys
                qNext.recordFetchedBlock = op.recordFetchedBlock
                op = qNext
                db.add(op)
                return
            }

            lock.signal()
        }

        db.add(op)

        lock.wait()

        print("names: \(names)")
        return names
    }

    private func createInCloud(_ page: Page) {
        guard let body = page.bodyData else {
            print("Unable to turn text into data")
            return
        }

        let db = CKContainer.default().privateCloudDatabase

        let id = CKRecord.ID(recordName: page.index)
        let type = "Article"
        let article = CKRecord(recordType: type, recordID: id)

        article["name"] = page.name
        article["body"] = body
        article["uuid"] = page.uuid.uuidString
        article["dateCreated"] = page.dateCreated
        article["dateUpdated"] = page.dateUpdated

        db.save(article) { (savedArticle, error) in
            if let error = error {
                print("ERROR: \(error)")
                return
            }

            if let saved = savedArticle {
                print("SAVED: \(saved.recordID)")
            }
        }
    }

    private func updateInCloud(_ page: Page) {
        guard let body = page.bodyData else {
            print("ERROR (update): unable to convert text to data")
            return
        }

        guard let article = getRecord(page.index) else {
            print("ERROR (update): unable to find article \(page.index)")
            return
        }

        let db = CKContainer.default().privateCloudDatabase

        article["dateUpdated"] = Date()
        article["body"] = body

        db.save(article) { (record, error) in
            if let error = error {
                print("ERROR (update): \(error)")
                return
            }
            if let record = record {
                print("Updated: \(record.recordID)")
            }
        }
    }

    private func getInCloud(_ index: String) -> Page? {
        // This is going to be synchronous for a while until I can get some
        // better logic at the window/editor layer.

        guard let article = getRecord(index) else {
            print("ERROR (fetch): unable to unwrap article return value")
            return nil
        }

        guard let data = article["body"] as? Data else {
            print("ERROR (fetch): unable to convert body to data")
            return nil
        }

        // Maybe make names enums for string constants?
        if let name = article["name"] as? String,
            let uuid = UUID(uuidString: article["uuid"] ?? UUID().uuidString),
            let dateCreated = article["dateCreated"] as? Date,
            let dateUpdated = article["dateUpdated"] as? Date,
            let body = NSAttributedString(rtf: data, documentAttributes: nil) {
            return Page(uuid: uuid, name: name, body: body, dateCreated: dateCreated, dateUpdated: dateUpdated)
        }

        print("ERROR (fetch): unable to convert record to page")
        return nil
    }

    private func getRecord(_ index: String) -> CKRecord? {

        let db = CKContainer.default().privateCloudDatabase

        let id = CKRecord.ID(recordName: index)
        let type = "Article"

        let semaphore = DispatchSemaphore(value: 0)

        var error: Error?
        var record: CKRecord?

        db.fetch(withRecordID: id) { (_record, _error) in
            defer {
                semaphore.signal()
            }
            error = _error
            record = _record
        }

        semaphore.wait()

        if let error = error {
            print("ERROR (fetch): \(error)")
            return nil
        }

        return record
    }

}
