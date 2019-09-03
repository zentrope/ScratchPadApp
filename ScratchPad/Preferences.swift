//
//  PreferencesManager.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/29/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import CloudKit
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "UserDefaults")

protocol ScratchPadPrefs {
    var isCustomZoneCreated: Bool { get set }
    var isSubscribedToPrivateChanges: Bool { get set }
    var databaseChangeToken: CKServerChangeToken? { get set }
    var zoneRecordChangeToken: CKServerChangeToken? { get set }
}

struct Preferences: ScratchPadPrefs {

    var isCustomZoneCreated: Bool {
        get { return UserDefaults.standard.bool(forKey: "IsCustomZoneCreated") }
        set { UserDefaults.standard.set(newValue, forKey: "IsCustomZoneCreated") }
    }

    var isSubscribedToPrivateChanges: Bool {
        get { return UserDefaults.standard.bool(forKey: "isSubscribedToPrivateChanges") }
        set { UserDefaults.standard.set(newValue, forKey: "isSubscribedToPrivateChanges") }
    }

    var databaseChangeToken: CKServerChangeToken? {
        get { return UserDefaults.standard.ckServerChangeToken(forKey: "databaseChangeToken") }
        set { UserDefaults.standard.set(newValue, forKey: "databaseChangeToken") }
    }

    var zoneRecordChangeToken: CKServerChangeToken? {
        get { return UserDefaults.standard.ckServerChangeToken(forKey: "ZoneRecordChangeToken") }
        set { UserDefaults.standard.set(newValue, forKey: "ZoneRecordChangeToken") }
    }
}

public extension UserDefaults {

    func set(_ value: CKServerChangeToken, forKey key: String) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false)
            self.set(data, forKey: key)
        } catch {
            self.removeObject(forKey: key)
        }
    }

    func ckServerChangeToken(forKey key: String) -> CKServerChangeToken? {
        guard let data = self.value(forKey: key) as? Data else {
            return nil
        }

        let token: CKServerChangeToken?
        do {
            token = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        } catch {
            token = nil
        }

        return token
    }
}
