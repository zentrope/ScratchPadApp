//
//  Environment.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/11/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

class Environment {

    static let shared = Environment()

    // Convenience properties to avoid having to call Environment.shared
    // when using features.

    static var database: Database {
        get {
            return shared.database
        }
    }

    static var windows: Windows {
        get {
            return shared.windows
        }
    }

    static var preferences: ScratchPadPrefs {
        get {
            return shared.preferences
        }
        set (newPrefs) {
            // This allows callers to set props on the preferences object.
        }
    }

    // The app needs to fail hard if these aren't set
    var database: Database!
    var windows: Windows!
    var preferences: ScratchPadPrefs!

    init() {
    }
}
