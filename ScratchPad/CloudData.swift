//
//  CloudData.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/30/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import CloudKit

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
        createArticleZone()
        createSubscription()
        fetchDatabaseChanges(database: privateDB) {
            DispatchQueue.main.async {
                print("CHECK ON START UP")
                completion()
            }
        }
    }

    func fetchChanges(in databaseScope: CKDatabase.Scope, completion: @escaping () -> Void) {
        switch databaseScope {
        case .private:
            fetchDatabaseChanges(database: privateDB, completion: completion)
        default:
            fatalError("Asked to fetch from scope we don't know about \(databaseScope)")
        }
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
                print("ERROR: fetch database changed \(error)")
                completion()
                return
            }

            print("completion token: \(String(describing: token))")
            print("moreComing = \(moreComing)")

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
            if let page = Page.fromCloud(record) {
                Store.shared[page.index] = page

//                let coder = NSKeyedArchiver(requiringSecureCoding: true)
//                record.encodeSystemFields(with: coder)
//                coder.finishEncoding()
//                let data = coder.encodedData
            }

            print("changed", record)
        }

        op.recordWithIDWasDeletedBlock = { recordId, recordType in
            print("deleted", recordId, recordType)
        }

        // The block to execute when the change token has been updated.
        op.recordZoneChangeTokensUpdatedBlock = { (zoneId, token, data) in
            // Flush record changes and deletions for this zone to disk
            // Write this new zone change token to disk
            print("recordZoneChangeTokensUpdatedBlock: \(zoneId) -> token = \(token!)")
        }

        // The block to execute when the fetch for a zone has completed.
        op.recordZoneFetchCompletionBlock = { (zoneId, changeToken, _, _, error) in
            if let error = error {
                print("ERROR: zone fetch completion \(error)")
            }
            print("recordZoneFetchCompletionBlock: \(zoneId) -> token = \(changeToken!)")
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

    private func createArticleZone() {
        if Preferences.isCustomZoneCreated {
            print("Already created zone: \(CloudData.zoneName).")
            return
        }

        let createZoneGroup = DispatchGroup()

        createZoneGroup.enter()

        let customZone = CKRecordZone(zoneID: CloudData.zoneID)
        let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone], recordZoneIDsToDelete: [])
        createZoneOperation.modifyRecordZonesCompletionBlock = { saved, deleted, error in
            defer { createZoneGroup.leave() }
            if let error = error {
                print("🔥 ERROR (create zone): \(error)")
                return
            }
            Preferences.isCustomZoneCreated = true
        }

        createZoneOperation.qualityOfService = .utility
        privateDB.add(createZoneOperation)
    }

    private func createSubscription() {
        if Preferences.isSubscribedToPrivateChanges {
            print("Already subscribed to private changes.")
            return
        }

        let op = makeSubscriptionOp(id: CloudData.privateSubscriptionID)

        op.modifySubscriptionsCompletionBlock = { subscriptions, deleteIds, error in
            if let error = error {
                print("🔥 ERROR (create sub): \(error)")
                return
            }
            print("Subscription \(CloudData.privateSubscriptionID) was successful.")
        }

        privateDB.add(op)
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
