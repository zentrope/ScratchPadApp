//
//  CloudData.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/30/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import CloudKit
import CoreData
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudData")

extension Notification.Name {
    static let cloudDataChanged = Notification.Name("cloudDataChanged")
}

class CloudData {

    static let zoneName = "Pages"
    static let zoneID = CKRecordZone.ID(zoneName: CloudData.zoneName, ownerName: CKCurrentUserDefaultName)
    static let privateSubscriptionID = "private-changes"

    static let shared = CloudData()

    private var preferences: ScratchPadPrefs!
    private var store: Store!
    private var database: Database!

    private let container = CKContainer.default()
    private let privateDB: CKDatabase

    init() {
        self.privateDB = container.privateCloudDatabase
        self.preferences = Preferences()
        self.store = Store.shared
        self.database = Database.main
    }

    init(preferences: ScratchPadPrefs, store: Store, database: Database) {
        self.privateDB = container.privateCloudDatabase
        self.preferences = preferences
        self.store = store
        self.database = database
    }

    func setup(_ completion: @escaping () -> Void) {
        DispatchQueue.global().async {
            do {
                try self.createCustomZone()
                try self.createSubscription()

                self.fetchDatabaseChanges(database: self.privateDB) {
                    DispatchQueue.main.async {
                        os_log("%{public}s", log: logger, "Initial database fetch is complete.")
                        completion()
                    }
                }
            }

            catch {
                fatalError("\(error)")
            }
        }
    }

    func fetchChanges(in databaseScope: CKDatabase.Scope, completion: @escaping () -> Void) {
        // Don't really need this scope stuff, do we?
        switch databaseScope {
        case .private:
            fetchDatabaseChanges(database: privateDB, completion: completion)
        default:
            fatalError("Asked to fetch from scope we don't know about \(databaseScope)")
        }
    }

    func create(page: Page) {
        guard let body = page.bodyString else {
            os_log("%{public}s", log: logger, type: .error, "Unable to convert Page body to string.")
            return
        }

        let db = CKContainer.default().privateCloudDatabase

        let id = CKRecord.ID(recordName: page.name, zoneID: CloudData.zoneID)
        let type = "Page"
        let record = CKRecord(recordType: type, recordID: id)

        record["name"] = page.name
        record["body"] = body
        record["dateCreated"] = page.dateCreated
        record["dateUpdated"] = page.dateUpdated

        db.save(record) { (savedRecord, error) in
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, "\(error)")
                return
            }

            if let record = savedRecord {
                self.setMetadata(forPageName: page.name.lowercased(), record: record)
                os_log("%{public}s", log: logger, "Saved '\(record.recordID.recordName)' to iCloud.")
            }
        }
    }

    func update(pages: [Page], _ completion: @escaping (([String]) -> Void)) {

        let records: [CKRecord] = pages.compactMap { page in
            let key = page.name.lowercased()

            guard let update = self.getRecordFromMetadata(name: key) else {
                os_log("%{public}s", log: logger, type: .error, "Unable to get metadata for '\(page.name.lowercased())'")

                // FIXME: This is not good. We need a way to figure out what's local only and sync it to the cloud.
                create(page: page)
                return nil
            }

            guard let body = page.bodyString else {
                os_log("%{public}s", log: logger, type: .error, "Unable to decode page body string")
                return nil
            }

            update["name"] = page.name.lowercased()
            update["dateUpdated"] = Date()
            update["body"] = body
            return update
        }

        if records.isEmpty {
            os_log("%{public}s", log: logger, type: .debug, "None of the \(pages.count) record(s) submitted could be serialized.")
            completion([String]())
            return
        }

        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [])
        op.savePolicy = .changedKeys
        op.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedIds, error) in
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, "\(error)")
                return
            }
            if let records = savedRecords {
                let indexes = records.map { $0.recordID.recordName }
                os_log("%{public}s", log: logger, "Updated success for \(indexes)")

                records.forEach { record in
                    let key = record.recordID.recordName.lowercased()
                    self.setMetadata(forPageName: key, record: record)
                }

                completion(indexes)
            }
        }
        privateDB.add(op)
    }

    // MARK: - Convenience

    private func setMetadata(forPageName name: String, record: CKRecord) {
        let recordMetadata = database.makeRecordMetadataStub()
        recordMetadata.name = name.lowercased()
        recordMetadata.record = record
        database.saveContext()
    }

    private func getRecordFromMetadata(name: String) -> CKRecord? {
        guard let recordAccount = database.fetchRecordMetadata(name: name) else { return nil }
        return recordAccount.record as? CKRecord
    }

    private func notifyChanges(index: String) {
        NotificationCenter.default.post(name: .cloudDataChanged, object: self, userInfo: ["page": index])
    }

    // Called when CloudKit receives a new/update record from iCloud
    private func updateRecord(_ record: CKRecord) {
        let key = record.recordID.recordName.lowercased()
        setMetadata(forPageName: key, record: record)
        store.replace(record: record)
        notifyChanges(index: key)
        os_log("%{public}s", log: logger, "Processed a push update for '\(key)'.")
    }

    // MARK: - Fetch Changes

    private func fetchDatabaseChanges(database: CKDatabase, completion: @escaping () -> Void) {

        // Deal with changes to the zones themselves.

        var changedZoneIDs = [CKRecordZone.ID]()

        let op = CKFetchDatabaseChangesOperation(previousServerChangeToken: preferences.databaseChangeToken)

        op.recordZoneWithIDChangedBlock = { zoneID in
            os_log("%{public}s", log: logger, "There's a change in zone '\(zoneID.zoneName)'.")
            changedZoneIDs.append(zoneID)
        }

        op.recordZoneWithIDWasDeletedBlock = { zoneID in
            // If this mattered to us, delete all the data associated with that zone.
            print("Zone \(zoneID) was deleted.")
            self.preferences.isSubscribedToPrivateChanges = false
            self.preferences.isCustomZoneCreated = false
        }

        op.changeTokenUpdatedBlock = { token in
            self.preferences.databaseChangeToken = token
        }

        op.fetchDatabaseChangesCompletionBlock = { token, _, error in
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
                completion()
                return
            }

            self.preferences.databaseChangeToken = token
            os_log("%{public}s", log: logger, type: .debug, "Saved database change token")

            if changedZoneIDs.isEmpty {
                completion()
                return
            }

            self.fetchZoneChanges(database: database, zoneIDs: changedZoneIDs) {
                completion()
            }
        }

        op.qualityOfService = .utility
        database.add(op)
    }

    private func fetchZoneChanges(database: CKDatabase, zoneIDs: [CKRecordZone.ID], completion: @escaping () -> Void) {

        var zoneConfigs = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
        for zoneID in zoneIDs {
            let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            options.previousServerChangeToken = preferences.zoneRecordChangeToken
            zoneConfigs[zoneID] = options
        }

        let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, configurationsByRecordZoneID: zoneConfigs)

        op.fetchAllChanges = true

        op.recordChangedBlock = { record in
            self.updateRecord(record)
        }

        op.recordWithIDWasDeletedBlock = { recordId, recordType in
            os_log("%{public}s", log: logger, type: .error, "A request to delete a record arrived, but doing so is not implemented.")
        }

        op.recordZoneChangeTokensUpdatedBlock = { (zoneId, token, data) in
            os_log("%{public}s", log: logger, type: .debug, "Saved zone '\(zoneId.zoneName)' change token.")
            self.preferences.zoneRecordChangeToken = token
        }

        op.recordZoneFetchCompletionBlock = { (zoneId, changeToken, _, _, error) in
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
                return
            }
            os_log("%{public}s", log: logger, type: .debug, "Zone fetching is complete: saved zone '\(zoneId.zoneName)' change token.")
            self.preferences.zoneRecordChangeToken = changeToken
        }

        op.fetchRecordZoneChangesCompletionBlock = { (error) in
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
            }
            completion()
        }

        database.add(op)
    }


    // MARK: - Initialization

    private func createCustomZone() throws {
        os_log("%{public}s", log: logger, "Create zone '\(CloudData.zoneName)' if necessary.")
        if preferences.isCustomZoneCreated {
            os_log("%{public}s", log: logger, "Zone '\(CloudData.zoneName)' already created.")
            return
        }

        let lock = DispatchSemaphore(value: 0)

        let zone = CKRecordZone(zoneID: CloudData.zoneID)

        var error: Error?

        let op = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: [])

        op.modifyRecordZonesCompletionBlock = { saved, deleted, _error in
            defer { lock.signal() }
            error = _error
        }
        op.qualityOfService = .utility
        privateDB.add(op)

        lock.wait()

        if let error = error {
            throw error
        }
        os_log("%{public}s", log: logger, "Zone '\(CloudData.zoneID.zoneName)' was created successfully.")
        preferences.isCustomZoneCreated = true
    }

    private func createSubscription() throws {
        os_log("%{public}s", log: logger, "Subscribe to private database changes if necessary.")
        if preferences.isSubscribedToPrivateChanges {
            os_log("%{public}s", log: logger, "Already subscribed to private database changes.")
            return
        }

        let lock = DispatchSemaphore(value: 0)
        var error: Error?

        let op = makeSubscriptionOp(id: CloudData.privateSubscriptionID)

        op.modifySubscriptionsCompletionBlock = { subscriptions, deleteIds, _error in
            defer { lock.signal() }
            error = _error
        }

        privateDB.add(op)

        lock.wait()

        if let error = error {
            throw error
        }
        os_log("%{public}s", log: logger, "Subscription '\(CloudData.privateSubscriptionID)' was successful.")
        preferences.isSubscribedToPrivateChanges = true
    }

    private func makeSubscriptionOp(id: String) -> CKModifySubscriptionsOperation {
        let sub = CKDatabaseSubscription(subscriptionID: CloudData.privateSubscriptionID)
        let note = CKSubscription.NotificationInfo()
        note.shouldSendContentAvailable = true
        sub.notificationInfo = note

        let op = CKModifySubscriptionsOperation(subscriptionsToSave: [sub], subscriptionIDsToDelete: [])
        op.qualityOfService = .utility
        return op
    }
}
