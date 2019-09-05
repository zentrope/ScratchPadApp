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

    private var localDB: LocalDB!
    private var cloudDB: CloudDB!

    // Cache so we can lazily update the cloud, for now.
    private var changes = Atomic(Set<String>())

    // Names are used to create links in page text for clickable navigation
    var names: [String] {
        get {
            return localDB.fetchNames()
        }
    }

    init(database: LocalDB, cloudData: CloudDB) {
        self.localDB = database
        self.cloudDB = cloudData

        scheduleChangeMonitor()
    }

    /// Return the main/initial article
    func mainPage() -> PageValue {
        return find(index: mainArticleIndex)
    }

    func find(index: String) -> PageValue {
        if let page = localDB.fetch(page: index) {
            return page
        }
        return newPage(name: index)
    }

    func replace(metadata record: CKRecord) {
        localDB.upsert(record: record.recordID.recordName.lowercased(), withRecord: record)
    }

    func replace(page record: CKRecord) {
        if let page = PageValue.fromRecord(record: record) {
            localDB.upsert(page: page)
            changes.swap { $0.remove(page.name.lowercased()) }
        }
    }

    func update(page name: String, withText text: NSAttributedString) {
        // Receives updates from the UI
        localDB.update(page: name, withText: text)
        changes.swap { $0.insert(name.lowercased()) }
    }

    private func scheduleChangeMonitor() {
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 5) { [ weak self] in
            self?.scheduleChangesForUpload()
        }
    }

    private func scheduleChangesForUpload() {

        let pageNames = self.changes.deref()
        if pageNames.isEmpty {
            self.scheduleChangeMonitor()
            return
        }

        var pages = [PageValue]()
        for name in pageNames {
            if let page = localDB.fetch(page: name) {
                pages.append(page)
            }
        }

        os_log("%{public}s", log: logger, type: .debug, "Scheduling pages: '\(pageNames)', for iCloud update.")
        cloudDB.update(pages: pages) { names in
            os_log("%{public}s", log: logger, type: .debug, "Pages updated: \(names.count).")
            self.changes.swap { $0.subtract(names) }
            self.scheduleChangeMonitor()
        }
    }

    private func newPage(name: String) -> PageValue {
        let page = makePage(name: name)
        cloudDB.create(page: page)
        return page
    }

    private func makePage(name: String) -> PageValue {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16.0),
            .foregroundColor: NSColor.controlTextColor
        ]

        let message = name.lowercased() == mainArticleIndex.lowercased() ? "Welcome!\n\n" : "\(name)\n\n"
        let body = NSAttributedString(string: message, attributes: attrs)

        let page = PageValue(name: name.lowercased(), dateCreated: Date(), dateUpdated: Date(), body: body)

        localDB.upsert(page: page)
        return page
    }
}
