//
//  Database.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/2/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import CoreData
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Database")

class Database {

    private var persistentContainer: NSPersistentContainer!

    init() {
        persistentContainer = NSPersistentContainer(name: "ScratchPadModel")
        persistentContainer.loadPersistentStores { storeDescription, error in
            self.persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
            }

        }
        NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: persistentContainer.viewContext, queue: .main) { msg in
            print("Got change notification: Could do cloud notification stuff right here.")

            guard let uinfo = msg.userInfo else { return }

            if let updated = uinfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
                print(" updated: \(updated.count)")
            }
            if let deleted = uinfo[NSDeletedObjectsKey] as? Set<NSManagedObject> {
                print(" deleted: \(deleted.count)")
            }
            if let inserted = uinfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
                print("inserted: \(inserted.count)")
            }
        }
    }

    func makePageStub() -> Page {
        return Page(context: persistentContainer.viewContext)
    }

    func makeRecordMetadataStub() -> RecordMetadata {
        return RecordMetadata(context: persistentContainer.viewContext)
    }

    func fetchRecordMetadata(name: String) -> RecordMetadata? {
        do {
            let request: NSFetchRequest<RecordMetadata> = RecordMetadata.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[c] %@", name.lowercased())
            let results = try persistentContainer.viewContext.fetch(request)
            return results.first
        } catch {
            os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
            return nil
        }
    }

    func fetch(page name: String) -> Page? {
        do {
            let request: NSFetchRequest<Page> = Page.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[c] %@", name)
            let pages = try persistentContainer.viewContext.fetch(request)
            return pages.first
        } catch {
            os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
            return nil
        }
    }

    func fetchNames() -> [String] {
        do {
            let request: NSFetchRequest<Page> = Page.fetchRequest()
            let pages: [Page] = try persistentContainer.viewContext.fetch(request)
            return pages.map { $0.name }
        } catch {
            os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
        }
        return [String]()
    }

    func saveContext() {
        guard persistentContainer.viewContext.hasChanges else { return }
        self.persistentContainer.viewContext.perform {
            do {
                if self.persistentContainer.viewContext.hasChanges {
                    try self.persistentContainer.viewContext.save()
                }
            } catch {
                os_log("%{public}s", log: logger, type: .error, "CoreData.save \(error)")
            }
        }
    }
}
