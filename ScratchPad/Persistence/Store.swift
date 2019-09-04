//
//  Store.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa
import CloudKit
import CoreData

import os.log
fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Store")

class Store {

    private let mainArticleIndex = "main"

    private var database: LocalDatabase!
    private var cloudData: CloudData!

    // Cache
    private var changes = Atomic(Set<String>())

    // Names are used to create links in page text for clickable navigation
    var names: [String] {
        get {
            return database.fetchNames()
        }
    }

    init(database: LocalDatabase, cloudData: CloudData) {
        self.database = database

        // This dependency on cloud should be removed. Instead, AppDelegate should listen for change notifications on Core Data and call functions on the CloudData resource at that time.
        self.cloudData = cloudData
        scheduleChangeMonitor()
    }

    /// Return the main/initial article
    func mainPage() -> Page {
        return find(index: mainArticleIndex)
    }

    func find(index: String) -> Page {

        // Fetch the page from the database, or create (and save and sync)
        // a new one if we can't find it.

        if let page = database.fetch(page: index) {
            return page
        }
        return newPage(name: index)
    }

    func replace(metadata record: CKRecord) {
        let recordMetadata = database.makeRecordMetadataStub()
        recordMetadata.name = record.recordID.recordName.lowercased()
        recordMetadata.record = record
        database.saveContext()
    }

    func replace(page record: CKRecord) {
        if let page = fromRecord(record: record) {
            changes.swap { $0.remove(page.name.lowercased()) }
        }
    }

    func update(page: Page) {
        // Receives updates from the UI

        changes.swap { $0.insert(page.name.lowercased()) }
    }

    private func scheduleChangeMonitor() {
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 5) { [ weak self] in
            self?.scheduleChangesForUpload()
        }
    }

    private func scheduleChangesForUpload() {

        database.saveContext()

        let pageNames = self.changes.deref()
        if pageNames.isEmpty {
            self.scheduleChangeMonitor()
            return
        }

        var pages = [Page]()
        for name in pageNames {
            if let page = database.fetch(page: name) {
                pages.append(page)
            }
        }

        os_log("%{public}s", log: logger, type: .debug, "Scheduling pages: '\(pageNames)', for iCloud update.")
        cloudData.update(pages: pages) { names in
            os_log("%{public}s", log: logger, type: .debug, "Pages updated: \(names.count).")
            self.changes.swap { $0.subtract(names) }
            self.scheduleChangeMonitor()
        }
    }

    private func newPage(name: String) -> Page {
        let page = makePage(name: name)
        cloudData.create(page: page)
        return page
    }

    private func makePage(name: String) -> Page {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16.0),
            .foregroundColor: NSColor.controlTextColor
        ]

        let message = name.lowercased() == mainArticleIndex.lowercased() ? "Welcome!\n\n" : "\(name)\n\n"
        let body = NSAttributedString(string: message, attributes: attrs)

        let page = database.makePageStub()
        page.name = name.lowercased()
        page.dateCreated = Date()
        page.dateUpdated = Date()
        page.body = body

        database.saveContext()
        return page
    }
}

// MARK: - Core Data

extension Store {

    func fromRecord(record: CKRecord) -> Page? {

        // Retrieve the string representation of an RTF document.
        guard let rtfString = record["body"] as? String else {
            os_log("%{public}s", log: logger, type: .error, "Unable to retrieve record's body.")
            return nil
        }

        // Convert the RTF string representation into data to build an NSAttributedString.
        guard let data = rtfString.data(using: .utf8) else {
            os_log("%{public}s", log: logger, type: .error, "Unable to convert rtf string to data")
            return nil
        }

        // Piece by piece to see what's missing. Also could iterate through CKRecord (if possible) to list attributes if we can't unpack them all.
        guard let name = record["name"] as? String else {
            os_log("%{public}s", log: logger, type: .error, "Unable to find name of record.")
            return nil
        }

        guard let body = NSAttributedString(rtf: data, documentAttributes: nil) else {
            os_log("%{public}s", log: logger, type: .error, "Unable to create attributed string from body data.")
            return nil
        }

        guard let dateUpdated = record["dateUpdated"] as? Date else {
            os_log("%{public}s", log: logger, type: .error, "Unable to find dateUpdated of record.")
            return nil
        }

        guard let dateCreated = record["dateCreated"] as? Date else {
            os_log("%{public}s", log: logger, type: .error, "Unable to find dateCreated of record.")
            print(record)
            return nil
        }

        let page = database.makePageStub()
        page.name = name
        page.dateCreated = dateCreated
        page.dateUpdated = dateUpdated
        page.body = body
        return page
    }
}
