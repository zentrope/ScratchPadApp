//
//  PreferencesManager.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/29/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import CloudKit

struct Preferences {
    // subscribed to private changes -> bool
    // created custom zone -> bool

    static var isCustomZoneCreated: Bool {
        get { return UserDefaults.standard.bool(forKey: "IsCustomZoneCreated") }
        set { UserDefaults.standard.set(newValue, forKey: "IsCustomZoneCreated")}
    }

    static var isSubscribedToPrivateChanges: Bool {
        get { return UserDefaults.standard.bool(forKey: "isSubscribedToPrivateChanges") }
        set { UserDefaults.standard.set(newValue, forKey: "isSubscribedToPrivateChanges")}
    }
}
