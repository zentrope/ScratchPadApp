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

    static let main = Database()

    private var persistentContainer: NSPersistentContainer!

    init() {
        persistentContainer = NSPersistentContainer(name: "ScratchPadModel")
        persistentContainer.loadPersistentStores { storeDescription, error in
            self.persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
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
