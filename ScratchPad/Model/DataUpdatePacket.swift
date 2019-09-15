//
//  DataUpdatePacket.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/14/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

/// When the local database changes, it sends one of these via the .localDatabaseDidChange notification.
struct DataUpdatePacket {
    var updates: [Page]
    var inserts: [Page]
    var deletes: [Page]
}
