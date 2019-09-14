//
//  Database.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa
import CloudKit

import os.log
fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "DataBroker")

class Database {

    let mainPageName = "main"

    private var localDB: LocalDB!
    private var cloudDB: CloudDB!

    // Cache so we can lazily update the cloud until I understand a better way to do this.
    private var changes = Atomic(Set<String>())

    // Names are used to create links in page text for clickable navigation
    var names: [String] {
        get {
            return localDB.fetchNames()
        }
    }

    var pages: [Page] { get { return localDB.fetch() } }

    init(local: LocalDB, cloud: CloudDB) {
        self.localDB = local
        self.cloudDB = cloud

        scheduleChangeMonitor()
    }

    /// Return the main/initial article
    func mainPage() -> Page {
        return find(index: mainPageName)
    }

    func find(index: String) -> Page {
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

    func delete(pageNamed name: String) {
        localDB.delete(pageNamed: name)
    }

    func delete(page: Page) {
        if let record = localDB.fetch(metadata: page.name) {
            cloudDB.delete(record: record)
        }
        localDB.delete(page: page)
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

        var updates = [PageUpdate]()
        for name in pageNames {
            if let page = localDB.fetch(page: name) {
                let meta = localDB.fetch(metadata: name)
                updates.append(PageUpdate(page: page, metadata: meta))
            }
        }

        os_log("%{public}s", log: logger, type: .debug, "Scheduling pages: '\(pageNames)', for iCloud update.")

        cloudDB.update(pages: updates) { names, failures in
            os_log("%{public}s", log: logger, type: .debug, "Pages update successes: \(names.count).")
            os_log("%{public}s", log: logger, type: .debug, "Pages update failures: \(failures.count).")
            self.changes.swap { $0.subtract(names) }

            // I think the reason for the failure matters: not found, or previous update? So should pair up an error.
            for result in failures {
                switch result.error {
                case CloudError.NoMetadata:
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

    private func newPage(name: String) -> Page {
        let page = makePage(name: name)
        localDB.upsert(page: page)
        cloudDB.create(page: page)
        return page
    }

    private func makePage(name: String) -> Page {
        let message = name.lowercased() == mainPageName.lowercased() ? "Welcome!\n\n" : "\(name)\n\n"
        let body = NSMutableAttributedString(string: message)
        body.setAttributes(EditorTextView.defaultAttributes, range: NSMakeRange(0, body.length))

        return Page(name: name.lowercased(), dateCreated: Date(), dateUpdated: Date(), body: body)
    }
}
