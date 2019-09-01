//
//  CloudData.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/30/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import CloudKit
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudData")

// https://apple.co/2NJjCsE

extension Notification.Name {
    static let cloudDataChanged = Notification.Name("cloudDataChanged")
}

struct CloudData {

    static let zoneName = "Articles"
    static let zoneID = CKRecordZone.ID(zoneName: CloudData.zoneName, ownerName: CKCurrentUserDefaultName)
    static let privateSubscriptionID = "private-changes"

    static let shared = CloudData()

    let container = CKContainer.default()
    let privateDB: CKDatabase

    init() {
        self.privateDB = container.privateCloudDatabase
    }

    func setup(_ completion: @escaping () -> Void) {

        DispatchQueue.global().async {
            do {
                os_log("%{public}s", log: logger, "create article zone")
                try self.createArticleZone()
                os_log("%{public}s", log: logger, "create subscription")
                try self.createSubscription()
                self.fetchDatabaseChanges(database: self.privateDB) {
                    DispatchQueue.main.async {
                        os_log("%{public}s", log: logger, "dispatching completion on fetch database completion")
                        completion()
                    }
                }
            }

            catch {
                fatalError("\(error)")
            }
        }

        os_log("%{public}s", log: logger, "setup exit")
    }

    func fetchChanges(in databaseScope: CKDatabase.Scope, completion: @escaping () -> Void) {
        switch databaseScope {
        case .private:
            fetchDatabaseChanges(database: privateDB, completion: completion)
        default:
            fatalError("Asked to fetch from scope we don't know about \(databaseScope)")
        }
    }

    func save(page: Article) {
        guard let body = page.bodyString else {
            print("Unable to turn text into string")
            return
        }

        let db = CKContainer.default().privateCloudDatabase

        let id = CKRecord.ID(recordName: page.index, zoneID: CloudData.zoneID)
        let type = "Article"
        let article = CKRecord(recordType: type, recordID: id)

        article["name"] = page.name
        article["body"] = body
        article["uuid"] = page.uuid.uuidString
        article["dateCreated"] = page.dateCreated
        article["dateUpdated"] = page.dateUpdated

        db.save(article) { (savedArticle, error) in
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, "\(error)")
                return
            }

            if let saved = savedArticle {
                os_log("%{public}s", log: logger, "Saved '\(saved.recordID.recordName)' to iCloud.")
            }
        }
    }

    func update(page: Article, metadata: Data?) {
        os_log("%{public}s", log: logger, type: .debug, "Updating '\(page.index)' in cloud.")

        guard let metadata = metadata else {
            os_log("%{public}s", log: logger, type: .error, "Unable to get metadata for '\(page.index)'")
            return
        }

        guard let body = page.bodyString else {
            os_log("%{public}s", log: logger, type: .error, "Unable to decode page body string")
            return
        }

        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: metadata) else {
            os_log("%{public}s", log: logger, type: .error, "Unable to create coder from metadata '\(page.index)'")
            return
        }
        coder.requiresSecureCoding = true
        let record = CKRecord(coder: coder)
        coder.finishDecoding()

        guard let update = record else {
            os_log("%{public}s", log: logger, type: .error, "Unable to unpack record.")
            return
        }

        update["dateUpdated"] = Date()
        update["body"] = body

        let op = CKModifyRecordsOperation(recordsToSave: [update], recordIDsToDelete: [])
        op.savePolicy = .changedKeys
        op.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedIds, error) in
            if let error = error {
                os_log("%{public}s", log: logger, type: .error, "Unable to update '\(page.index)', error: '\(error)'.")
                return
            }
            if let saves = savedRecords {
                let indexes = saves.map { $0.recordID.recordName }
                os_log("%{public}s", log: logger, "Updated success for \(indexes)")
            }
        }
        privateDB.add(op)
    }

    // MARK: - Private

    private func fetchDatabaseChanges(database: CKDatabase, completion: @escaping () -> Void) {

        // Deal with changes to the zones themselves.

        var changedZoneIDs = [CKRecordZone.ID]()
        let changeToken: CKServerChangeToken? = nil // Should be preserved when there's a cache on disk
        let op = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)

        op.recordZoneWithIDChangedBlock = { zoneID in
            changedZoneIDs.append(zoneID)
        }

        op.recordZoneWithIDWasDeletedBlock = { zoneID in
            // Should save this in a vector to react to it
            print("Zone \(zoneID) was deleted. How can this be!")
        }

        op.changeTokenUpdatedBlock = { token in
            // flush zone deletions to disk
            // save the new token to be used on subsequent starts

        }

        op.fetchDatabaseChangesCompletionBlock = { token, moreComing, error in
            if let error = error {
                // Should set an alert
                os_log("%{public}s", log: logger, type: .error, "\(error)")
                completion()
                return
            }

            os_log("%{public}s", log: logger, "database change token \(String(describing: token))")

            // If the Articles zone is deleted, mark it uncreated in
            // preferences? Then what? Recreated it?

            self.fetchZoneChanges(database: database, zoneIDs: changedZoneIDs) {
                // Flush token to disk
                completion()
            }
        }

        op.qualityOfService = .utility
        database.add(op)
    }

    private func fetchZoneChanges(database: CKDatabase, zoneIDs: [CKRecordZone.ID], completion: @escaping () -> Void) {

        var optionsByRecordZoneID = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
        for zoneID in zoneIDs {
            let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            options.previousServerChangeToken = nil // pull from preferences? Is there a separate token per zone?
            optionsByRecordZoneID[zoneID] = options
        }

        let op = CKFetchRecordZoneChangesOperation()

        op.recordZoneIDs = zoneIDs
        op.configurationsByRecordZoneID = optionsByRecordZoneID
        op.fetchAllChanges = true

        // The block to execute with the contents of a changed record.
        // The operation object executes this block once for each record in the zone that changed since the previous fetch request. Each time the block is executed, it is executed serially with respect to the other progress blocks of the operation. If no records changed, the block is not executed.
        op.recordChangedBlock = { record in
            // if record.recordType == "Article"
            if let article = Article.fromCloud(record) {
                // Metadata
                let coder = NSKeyedArchiver(requiringSecureCoding: true)
                record.encodeSystemFields(with: coder)
                coder.finishEncoding()
                let data = coder.encodedData
                Store.shared.update(articleId: article.index, page: article, metadata: data)
            }
            os_log("%{public}s", log: logger, "processed push update for '\(record.recordID.recordName)'")
        }

        op.recordWithIDWasDeletedBlock = { recordId, recordType in
            print("deleted", recordId, recordType)
        }

        // The block to execute when the change token has been updated.
        op.recordZoneChangeTokensUpdatedBlock = { (zoneId, token, data) in
            // Flush record changes and deletions for this zone to disk
            // Write this new zone change token to disk
            os_log("%{public}s", log: logger, "recordZoneChangeTokensUpdatedBlock: \(zoneId.zoneName) -> token = \(token!)")
        }

        // The block to execute when the fetch for a zone has completed.
        op.recordZoneFetchCompletionBlock = { (zoneId, changeToken, _, _, error) in
            if let error = error {
                print("ERROR: zone fetch completion \(error)")
            }
            os_log("%{public}s", log: logger, "recordZoneFetchCompletionBlock: \(zoneId.zoneName) -> token = \(changeToken!)")
            // Flush to disk
            // Save this token
        }

        // The block to use to process the record zone changes.
        op.fetchRecordZoneChangesCompletionBlock = { (error) in
            if let error = error {
                print("Error fetching zone change:", error)
            }
            completion()
        }

        database.add(op)
    }


    // MARK: - Initialization

    private func createArticleZone() throws {
        if Preferences.isCustomZoneCreated {
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
        Preferences.isCustomZoneCreated = true
    }

    private func createSubscription() throws {
        if Preferences.isSubscribedToPrivateChanges {
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
        Preferences.isSubscribedToPrivateChanges = true
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
