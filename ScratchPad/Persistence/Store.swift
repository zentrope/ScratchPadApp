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

    func replace(pageNamed name: String, withRecord record: CKRecord) {
        localDB.upsert(page: name, withRecord: record)
        changes.swap { $0.remove(name.lowercased()) }
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


        cloudDB.update(pages: pages) { names, failures in
            os_log("%{public}s", log: logger, type: .debug, "Pages update successes: \(names.count).")
            os_log("%{public}s", log: logger, type: .debug, "Pages update failures: \(failures.count).")
            self.changes.swap { $0.subtract(names) }

            // I think the reason for the failure matters: not found, or previous update? So should pair up an error.
            for result in failures {
                switch result.error {
                case CloudDB.LocalCKError.NoMetadata:
                    os_log("%{public}s", log: logger, type: .error, "\(result.page.name) no metadata on file")
                    // could be we have a copy, but not posted, so try and retrieve it. If that succeeds, update, else create.
                    break
                case CKError.serverRecordChanged:
                    os_log("%{public}s", log: logger, type: .error, "\(result.page.name) we have an out of date copy")
                    // retrieve then update
                    break
                default:
                    break
                }
                self.cloudDB.create(page: result.page)
                self.changes.swap { $0.remove(result.page.name) } // Do this on success. Not sure what to do on failure to create. Same?
            }
            self.scheduleChangeMonitor()
        }
    }

    private func newPage(name: String) -> PageValue {
        let page = makePage(name: name)
        localDB.upsert(page: page)
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

        return PageValue(name: name.lowercased(), dateCreated: Date(), dateUpdated: Date(), body: body)
    }
}
