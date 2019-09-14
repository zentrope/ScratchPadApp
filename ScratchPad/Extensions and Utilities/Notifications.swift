//
//  Notifications.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/14/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

extension Notification.Name {

    /// Posted by AppDelegate and PageBrowserVC when cloud data has been updated so that editors can update their views.
    /// - Note: This is not well thought out. VCs should not post this message, and we need finer grained details, such as "text" data changed, or "repaint your links" changes, and possibly a container for what changed. In fact, we might better use the localDatabaseUpdated notification to figure out the right thing to do given cloud updates are reflected there.
    @available(*, deprecated, message: "Should use localDatabaseUpdated instead.")
    static let cloudDataChanged = Notification.Name("cloudDataChanged")

    /// Posted by the LocalDB when Core Data posts a dataDidChange notification. UserInfo contains list of inserted, updated and deleted Page objects.
    static let localDatabaseUpdated = Notification.Name("localDatabaseUpdated")
}

