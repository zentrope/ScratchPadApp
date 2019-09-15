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

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Preferences")

protocol ScratchPadPrefs {
    var isCustomZoneCreated: Bool { get set }
    var isSubscribedToPrivateChanges: Bool { get set }
    var databaseChangeToken: CKServerChangeToken? { get set }
    var zoneRecordChangeToken: CKServerChangeToken? { get set }

    func removeWindowFramePosition(withName name: String)
}

struct Preferences: ScratchPadPrefs {

    func removeWindowFramePosition(withName name: String) {
        let key = "NSWindow Frame \(name)"
        print("removing key '\(key)'")
        UserDefaults.standard.removeObject(forKey: key)
    }

    var isCustomZoneCreated: Bool {
        get { return UserDefaults.standard.bool(forKey: "CloudKitIsCustomZoneCreated") }
        set { UserDefaults.standard.set(newValue, forKey: "CloudKitIsCustomZoneCreated") }
    }

    var isSubscribedToPrivateChanges: Bool {
        get { return UserDefaults.standard.bool(forKey: "CloudKitIsSubscribedToPrivateChanges") }
        set { UserDefaults.standard.set(newValue, forKey: "CloudKitIsSubscribedToPrivateChanges") }
    }

    var databaseChangeToken: CKServerChangeToken? {
        get { return UserDefaults.standard.ckServerChangeToken(forKey: "CloudKitDatabaseChangeToken") }
        set { UserDefaults.standard.set(newValue, forKey: "CloudKitDatabaseChangeToken") }
    }

    var zoneRecordChangeToken: CKServerChangeToken? {
        get { return UserDefaults.standard.ckServerChangeToken(forKey: "CloudKitZoneRecordChangeToken") }
        set { UserDefaults.standard.set(newValue, forKey: "CloudKitZoneRecordChangeToken") }
    }
}

public extension UserDefaults {

    func set(_ value: CKServerChangeToken?, forKey key: String) {
        guard let token = value else {
            self.removeObject(forKey: key)
            return
        }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            self.set(data, forKey: key)
        } catch {
            os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
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
