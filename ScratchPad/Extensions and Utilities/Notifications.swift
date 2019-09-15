//
//  Notifications.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/14/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

extension Notification.Name {

    /// Posted by the LocalDB when Core Data posts a dataDidChange notification. UserInfo contains list of inserted, updated and deleted Page objects via a DataUpdatePacket struct.
    static let localDatabaseDidChange = Notification.Name("localDatabaseDidChange")
}

