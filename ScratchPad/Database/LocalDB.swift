//
//  LocalDB.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/2/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import CoreData
import CloudKit
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "LocalDB")

extension Page {
    static func fromManagedObject(page: PageMO) -> Page {
        return Page(
            name: page.name ?? "unknown",
            dateCreated: page.dateCreated ?? Date(),
            dateUpdated: page.dateUpdated ?? Date(),
            body: page.body ?? NSAttributedString()
        )
    }
}

extension RecordMetadata {
    static func fromManagedObject(metadata: RecordMetadataMO) -> RecordMetadata {
        let name = metadata.name!
        let record = metadata.record as! CKRecord
        return RecordMetadata(name: name, record: record)
    }
}


/// A class for interacting with the local data store.
///
/// - Note: Only this class should interact with Core Data and Managed Objects directly. The rest of the application should use value structs for rendering and syncing.
///
class LocalDB: NSPersistentContainer {

    // We can't override init(name: String) because it's a convenience method
    // on the superclass.
    static func instantiate(name: String) -> LocalDB {
        let localDB = LocalDB(name: name)
        localDB.loadPersistentStores { (storeDescriotion, error) in
            localDB.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            // rem: query generations
            // rem: automaticallyMergesChangesFromParent
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
                fatalError(error.localizedDescription)
            }
        }
        return localDB
    }

    // MARK: - Mutations

    func upsert(record name: String, withRecord record: CKRecord) {
        viewContext.performAndWait {
            if let meta = fetchMO(metadata: name) {
                meta.record = record
                commit()
                return
            }
            let meta = RecordMetadataMO(context: viewContext)
            meta.name = name
            meta.record = record
            commit()
        }
    }

    func upsert(page name: String, withRecord record: CKRecord) {
        viewContext.perform {
            var meta: RecordMetadataMO
            if let found = self.fetchMO(metadata: name) {
                meta = found
            } else {
                meta = RecordMetadataMO(context: self.viewContext)
                meta.name = name
            }
            meta.record = record

            let page: PageMO
            if let found = self.fetchMO(page: name) {
                page = found
            } else {
                page = PageMO(context: self.viewContext)
                page.name = name
            }

            if let value = Page.fromRecord(record: record) {
                page.dateCreated = value.dateCreated
                page.dateUpdated = value.dateUpdated
                page.body = value.body
                self.commit()
            }
        }
    }

    /// Update a page in the local cache.
    /// - Parameter value: The page value containing the data to update
    func upsert(page value: Page) {
        viewContext.perform {
            var page: PageMO
            if let oldPage = self.fetchMO(page: value.name) {
                page = oldPage
            } else {
                page = PageMO(context: self.viewContext)
                page.name = value.name
            }
            page.dateCreated = value.dateCreated
            page.dateUpdated = value.dateUpdated
            page.body = value.body

            self.commit()
        }
    }

    func update(page name: String, withText body: NSAttributedString) {
        viewContext.perform {
            if let page = self.fetchMO(page: name) {
                page.body = body
                page.dateUpdated = Date()
                self.commit()
            } else {
                os_log("%{public}s", log: logger, type: .error, "Unable to update text of page '\(name)'.")
            }
        }
    }

    // MARK: - Queries

    func exists(pageNamed name: String) -> Bool {
        var result = false
        viewContext.performAndWait {
            result = fetchMO(page: name) != nil
        }
        return result
    }

    func fetchNames() -> [String] {
        var result = [String]()
        viewContext.performAndWait {
            do {
                let request: NSFetchRequest<PageMO> = PageMO.fetchRequest()
                let pages: [PageMO] = try viewContext.fetch(request)
                result = pages.map { $0.name! }
            } catch {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
            }
        }
        return result
    }

    func fetch(metadata name: String) -> RecordMetadata? {
        var result: RecordMetadata?

        viewContext.performAndWait {
            if let meta = fetchMO(metadata: name) {
                result = RecordMetadata.fromManagedObject(metadata: meta)
            }
        }

        return result
    }

    func fetch(page name: String) -> Page? {
        var result: Page?
        viewContext.performAndWait {
            if let page: PageMO = fetchMO(page: name) {
                result = Page.fromManagedObject(page: page)
            }
        }
        return result
    }

    // MARK: - Managed Object Functions

    private func fetchMO(metadata name: String) -> RecordMetadataMO? {
        var result: RecordMetadataMO?

        viewContext.performAndWait {
            do {
                let request: NSFetchRequest<RecordMetadataMO> = RecordMetadataMO.fetchRequest()
                request.predicate = NSPredicate(format: "name ==[c] %@", name.lowercased())
                let results = try viewContext.fetch(request)
                result = results.first
            }
            catch {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
            }
        }
        return result
    }

    private func fetchMO(page name: String) -> PageMO? {
        var result: PageMO?
        viewContext.performAndWait {
            do {
                let request: NSFetchRequest<PageMO> = PageMO.fetchRequest()
                request.predicate = NSPredicate(format: "name ==[c] %@", name)
                let pages = try viewContext.fetch(request)
                result = pages.first
            } catch {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
            }
        }
        return result
    }

    private func commit() {
        guard viewContext.hasChanges else { return }
        viewContext.perform {
            do {
                if self.viewContext.hasChanges {
                    try self.viewContext.save()
                }
            } catch {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
            }
        }
    }
}
