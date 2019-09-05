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

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Database")


/// A class for interacting with the local data store.
///
/// - Note: Only this class should interact with Core Data and Managed Objects directly. The rest of the application should use value structs for rendering and syncing.
///
class LocalDB: NSPersistentContainer {

    // MARK: - Mutations

    func upsert(record name: String, withRecord record: CKRecord) {
        viewContext.performAndWait {
            if var meta = fetch(metadata: name) {
                meta.record = record
                saveContext()
                return
            }
            let meta = RecordMetadataMO(context: viewContext)
            meta.name = name
            meta.record = record
            saveContext()
        }
    }

    func upsert(page value: PageValue) {
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
            self.saveContext()
        }
    }

    func update(page name: String, withText body: NSAttributedString) {
        viewContext.perform {
            if let page = self.fetchMO(page: name) {
                page.body = body
                page.dateUpdated = Date()
                self.saveContext()
            }
        }
    }

    // MARK: - Queries

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

    func fetch(metadata name: String) -> MetadataValue? {
        var result: MetadataValue?

        viewContext.performAndWait {
            if let meta = fetchMO(metadata: name) {
                result = MetadataValue.fromManagedObject(metadata: meta)
            }
        }

        return result
    }

    func fetch(page name: String) -> PageValue? {
        var result: PageValue?
        viewContext.performAndWait {
            if let page: PageMO = fetchMO(page: name) {
                result = PageValue.fromManagedObject(page: page)
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

    private func saveContext() {
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
