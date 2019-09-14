//
//  CloudDB.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/30/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import CloudKit
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudDB")

enum CloudError : Error {
    case NoMetadata
}

class CloudDB {

    static let zoneName = "Pages"
    static let zoneID = CKRecordZone.ID(zoneName: CloudDB.zoneName, ownerName: CKCurrentUserDefaultName)
    static let privateSubscriptionID = "private-changes"

    private var preferences: ScratchPadPrefs!

    private let container = CKContainer.default()
    private let privateDB: CKDatabase

    enum Event {
        case updatePage(name: String, record: CKRecord)
        case deletePage(name: String)
        case updateMetadata(name: String, record: CKRecord)
    }

    var action: ((Event) -> Void)?

    struct UpdateFailure {
        var page: Page
        var error: Error
    }

    init(preferences: ScratchPadPrefs) {
        self.privateDB = container.privateCloudDatabase
        self.preferences = preferences
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

    func delete(record meta: RecordMetadata) {
        let recordID = meta.record.recordID
        privateDB.delete(withRecordID: recordID) { (recordId, error) in
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
                return
            }
            let msg = String(describing: recordId)
            os_log("%{public}s", log: logger, type: .debug, "Deleted record: '\(msg)'.")
        }
    }

    // Should take a completion handler.
    func create(page: Page) {

        guard let body: String = page.body.rtfString else {
            os_log("%{public}s", log: logger, type: .error, "Unable to convert Page body to string.")
            return
        }

        let id = CKRecord.ID(recordName: page.name, zoneID: CloudDB.zoneID)
        let type = "Page"
        let record = CKRecord(recordType: type, recordID: id)

        record["name"] = page.name
        record["body"] = body
        record["dateCreated"] = page.dateCreated
        record["dateUpdated"] = page.dateUpdated

        privateDB.save(record) { (savedRecord, error) in
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, "\(error)")
                return
            }

            if let record = savedRecord {
                self.notifyMetadataUpdate(forPageName: page.name.lowercased(), record: record)
                os_log("%{public}s", log: logger, "Saved '\(record.recordID.recordName)' to iCloud.")
            }
        }
    }

    func update(pages: [PageUpdate], _ completion: @escaping ((_ successes: [String], _ failures: [UpdateFailure]) -> Void)) {

        let candidates = pages.reduce(into: [String:Page]()) { a, v in a[v.page.name] = v.page }

        var failures = [UpdateFailure]()

        let records: [CKRecord] = pages.compactMap { update in

            guard let record = update.metadata?.record else {
                os_log("%{public}s", log: logger, type: .error, "Unable to get metadata for '\(update.page.name)'.")
                failures.append(UpdateFailure(page: update.page, error: CloudError.NoMetadata))
                return nil
            }

            guard let body = update.page.body.rtfString else {
                os_log("%{public}s", log: logger, type: .error, "Unable to decode page body string")
                return nil
            }

            record["name"] = update.page.name
            record["dateCreated"] = update.page.dateCreated
            record["dateUpdated"] = update.page.dateUpdated
            record["body"] = body
            return record
        }

        if records.isEmpty {
            os_log("%{public}s", log: logger, type: .debug, "None of the \(pages.count) record(s) submitted could be serialized.")
            completion([String](), failures)
            return
        }

        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [])
        op.savePolicy = .changedKeys
        op.perRecordCompletionBlock = { record, error in
            if let error = error {
                failures.append(UpdateFailure(page: candidates[record.recordID.recordName]!, error: error))
            }
        }

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
                    self.notifyMetadataUpdate(forPageName: key, record: record)
                }

                completion(indexes, failures)
            }
        }
        privateDB.add(op)
    }

}

// MARK: - Convenience utility functions

extension CloudDB {

    private func notifyPageUpdate(forPageName name: String, record: CKRecord) {
        action?(.updatePage(name: name.lowercased(), record: record))
    }

    private func notifyPageDelete(forPageName name: String) {
        action?(.deletePage(name: name))
    }

    private func notifyMetadataUpdate(forPageName name: String, record: CKRecord) {
        action?(.updateMetadata(name: name.lowercased(), record: record))
    }
}

// MARK: Fetching changes

// Methods related to fetching changes on application start up, and when
// a push notification arrives.

extension CloudDB {

    func fetchChanges(in databaseScope: CKDatabase.Scope, completion: @escaping () -> Void) {
        // Don't really need this scope stuff, do we?
        switch databaseScope {
        case .private:
            fetchDatabaseChanges(database: privateDB, completion: completion)
        default:
            fatalError("Asked to fetch from scope we don't know about \(databaseScope)")
        }
    }

    // Called when CloudKit receives a new/update record from iCloud
    private func updateRecord(_ record: CKRecord) {
        let key = record.recordID.recordName.lowercased()
        notifyPageUpdate(forPageName: key, record: record)
        os_log("%{public}s", log: logger, "Processed a push update for '\(key)'.")
    }

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
            os_log("%{public}s", log: logger, "Zone '\(zoneID.zoneName)' was deleted.")
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
            os_log("%{public}s", log: logger, type: .debug, "Saved database change token.")

            if changedZoneIDs.isEmpty {
                os_log("%{public}s", log: logger, type: .debug, "No zones were changed.")
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
            guard recordType == "Page" else {
                os_log("%{public}s", log: logger, type: .error, "Unable to process deletes for record type '\(recordType)'.")
                return
            }
            os_log("%{public}s", log: logger, type: .debug, "Deleting page named '\(recordId.recordName)' as per CloudKit notification.")
            self.notifyPageDelete(forPageName: recordId.recordName)
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


}

// MARK: - Initialization

extension CloudDB {

    private func createCustomZone() throws {
        os_log("%{public}s", log: logger, "Create zone '\(CloudDB.zoneName)' if necessary.")
        if preferences.isCustomZoneCreated {
            os_log("%{public}s", log: logger, "Zone '\(CloudDB.zoneName)' already created.")
            return
        }

        let lock = DispatchSemaphore(value: 0)

        let zone = CKRecordZone(zoneID: CloudDB.zoneID)

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
        os_log("%{public}s", log: logger, "Zone '\(CloudDB.zoneID.zoneName)' was created successfully.")
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

        let op = makeSubscriptionOp(id: CloudDB.privateSubscriptionID)

        op.modifySubscriptionsCompletionBlock = { subscriptions, deleteIds, _error in
            defer { lock.signal() }
            error = _error
        }

        privateDB.add(op)

        lock.wait()

        if let error = error {
            throw error
        }
        os_log("%{public}s", log: logger, "Subscription '\(CloudDB.privateSubscriptionID)' was successful.")
        preferences.isSubscribedToPrivateChanges = true
    }

    private func makeSubscriptionOp(id: String) -> CKModifySubscriptionsOperation {
        let sub = CKDatabaseSubscription(subscriptionID: CloudDB.privateSubscriptionID)
        let note = CKSubscription.NotificationInfo()
        note.shouldSendContentAvailable = true
        sub.notificationInfo = note

        let op = CKModifySubscriptionsOperation(subscriptionsToSave: [sub], subscriptionIDsToDelete: [])
        op.qualityOfService = .utility
        return op
    }
}

extension Page {

    static func fromRecord(record: CKRecord) -> Page? {

        guard let rtfString = record["body"] as? String else {
            os_log("%{public}s", log: logger, type: .error, "Unable to retrieve record's body.")
            return nil
        }

        guard let data = rtfString.data(using: .utf8) else {
            os_log("%{public}s", log: logger, type: .error, "Unable to convert rtf string to data")
            return nil
        }

        guard let body = NSAttributedString(rtf: data, documentAttributes: nil) else {
            os_log("%{public}s", log: logger, type: .error, "Unable to create attributed string from body data.")
            return nil
        }

        guard let dateCreated = record["dateCreated"] as? Date else {
            os_log("%{public}s", log: logger, type: .error, "Unable to retrieve date created from record.")
            return nil
        }

        guard let dateUpdated = record["dateUpdated"] as? Date else {
            os_log("%{public}s", log: logger, type: .error, "Unable to retrieve date updated from record.")
            return nil
        }

        guard let name = record["name"] as? String else {
            os_log("%{public}s", log: logger, type: .error, "Unable to retrieve name from record.")
            return nil
        }

        let page = Page(
            name: name,
            dateCreated: dateCreated,
            dateUpdated: dateUpdated,
            body: body
        )
        return page
    }
}
