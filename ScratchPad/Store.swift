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

    // Serialize attempts to update (in case we update the same object twice).
    private let updateQueue = DispatchQueue(label: "cloudkit.update.com.zentrope.ScratchPad")

    private var pages = [String:Page]()


    var names: [String] {
        get {
            return Array(pages.keys)
        }
    }

    func mainPage() -> Page {
        print("GETTING MAIN PAGE")
        return self[mainArticle]
    }

    subscript(index: String) -> Page {
        get {
            if let page = pages[index.lowercased()] {
                return page
            }
            let newPage = self.newPage(index)
            pages[index] = newPage
            return newPage
        }
        set (newPage) {
            pages[newPage.index.lowercased()] = newPage
        }
    }

    func save(_ page: Page) {
        // The problem here is that ALL updates are serialized, even if they
        // can be applied in parallel. Maybe it doesn't matter for this app.
        pages[page.index] = page
        updateQueue.async {
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
        return page
    }
}

// MARK: - Cloud Functions

extension Store {

    private func createInCloud(_ page: Page) {
        guard let body = page.bodyString else {
            print("Unable to turn text into string")
            return
        }

        let db = CKContainer.default().privateCloudDatabase

        let id = CKRecord.ID(recordName: page.index, zoneID: CloudData.zoneID)
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
        guard let body = page.bodyString else {
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

    private func getRecord(_ index: String) -> CKRecord? {

        let db = CKContainer.default().privateCloudDatabase

        let id = CKRecord.ID(recordName: index, zoneID: CloudData.zoneID)
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

extension Page {

    static func fromCloud(_ article: CKRecord) -> Page? {

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
            return Page(uuid: uuid, name: name, body: body, dateCreated: dateCreated, dateUpdated: dateUpdated)
        }

        print("ERROR (fetch): unable to convert record to page")
        return nil

    }
}
