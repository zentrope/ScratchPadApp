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

    static let shared = Store()

    private let mainArticleIndex = "main"

    // Core Data
    private var container: NSPersistentContainer!

    // Cache
    private var changes = Atomic(Set<String>())

    // Names are used to create links in page text for clickable navigation
    var names: [String] {
        get {
            return fetchNames()
        }
    }

    init() {
        container = NSPersistentContainer(name: "ScratchPadModel")
        container.loadPersistentStores { storeDescription, error in
            os_log("%{public}s", log: logger, "Loading persistent store in '\(storeDescription)'.")
            self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
            }
        }

        scheduleChangeMonitor()
    }

    /// Return the main/initial article
    func mainPage() -> Page {
        return find(index: mainArticleIndex)
    }

    func find(index: String) -> Page {

        // Fetch the page from the database, or create (and save and sync)
        // a new one if we can't find it.

        if let page = fetchPage(name: index) {
            return page
        }
        return newPage(name: index)
    }

    
    func replace(record: CKRecord) {
        if let page = fromRecord(record: record) {
            self.saveContext()
            changes.swap { $0.remove(page.name.lowercased()) }
        }
    }

    func update(page: Page) {
        // Receives updates from the UI
        saveContext() //
        changes.swap { $0.insert(page.name.lowercased()) }
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

        var pages = [Page]()
        for name in pageNames {
            if let page = fetchPage(name: name) {
                pages.append(page)
            }
        }

        os_log("%{public}s", log: logger, type: .debug, "Scheduling pages: '\(pageNames)', for iCloud update.")
        CloudData.shared.update(pages: pages) { names in
            os_log("%{public}s", log: logger, type: .debug, "Pages updated: \(names.count).")
            self.changes.swap { $0.subtract(names) }
            self.scheduleChangeMonitor()
        }
    }

    private func newPage(name: String) -> Page {
        let page = makePage(name: name)
        CloudData.shared.create(page: page)
        return page
    }

    private func makePage(name: String) -> Page {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16.0),
            .foregroundColor: NSColor.controlTextColor
        ]

        let message = name.lowercased() == mainArticleIndex.lowercased() ? "Welcome!\n\n" : "\(name)\n\n"
        let body = NSAttributedString(string: message, attributes: attrs)

        let page = Page(context: container.viewContext)
        page.name = name.lowercased()
        page.dateCreated = Date()
        page.dateUpdated = Date()
        page.body = body

        saveContext()
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

        // Conver the RTF string representation into data to build an NSAttributedString.
        guard let data = rtfString.data(using: .utf8) else {
            os_log("%{public}s", log: logger, type: .error, "Unable to convert rtf string to data")
            return nil
        }


        if let name = record["name"] as? String,
            let dateCreated = record["dateCreated"] as? Date,
            let dateUpdated = record["dateUpdated"] as? Date,
            let body = NSAttributedString(rtf: data, documentAttributes: nil) {

            let page = Page(context: container.viewContext)
            page.name = name
            page.dateCreated = dateCreated
            page.dateUpdated = dateUpdated
            page.body = body
            return page
        }

        os_log("%{public}s", log: logger, type: .error, "Unable to create a Page from a Record.")
        return nil
    }

    func fetchPage(name: String) -> Page? {
        do {
            let request: NSFetchRequest<Page> = Page.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[c] %@", name)
            let pages = try container.viewContext.fetch(request)
            return pages.first
        } catch {
            os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
            return nil
        }
    }

    func fetchNames() -> [String] {
        do {
            let request: NSFetchRequest<Page> = Page.fetchRequest()
            let pages: [Page] = try container.viewContext.fetch(request)
            return pages.map { $0.name }
        } catch {
            os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
        }
        return [String]()
    }

    func saveContext() {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
            } catch {
                os_log("%{public}s", log: logger, type: .error, "CoreData.save \(error)")
            }
        }
    }
}
