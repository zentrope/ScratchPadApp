//
//  AppDelegate.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/22/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa
import CloudKit
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private var windowManager: WindowManager!
    private var cloudData: CloudData!
    private var database: Database!
    private var preferences: Preferences!
    private var store: Store!

    private var isInitialized = false

    private func openMainWindow() {
        if isInitialized {
            windowManager.spawnMainPage()
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        self.database = Database()
        self.preferences = Preferences()
        self.cloudData = CloudData(preferences: preferences, database: database)
        self.store = Store(database: database, cloudData: cloudData)
        self.windowManager = WindowManager(store: store)

        NotificationCenter.default.addObserver(forName: .cloudDataChanged, object: nil, queue: .main) { [weak self] msg in
            guard let uinfo = msg.userInfo, let record = uinfo["record"] as? CKRecord else { return }
            self?.store.replace(record: record)
        }

        // For receiving a request to open a scratchpad URL.
        let manager = NSAppleEventManager.shared()
        manager.setEventHandler(self,
                                andSelector: #selector(handle(_:withReplyEvent:)),
                                forEventClass:AEEventClass(kInternetEventClass),
                                andEventID: AEEventID(kAEGetURL))
    }

    @objc func handle(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlStr = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
        guard let link = urlStr.removingPercentEncoding else { return }

        if windowManager.isScratchPadLink(link: link) {
            windowManager.open(link: link)
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        cloudData.setup() {
            NSApp.registerForRemoteNotifications()
            self.isInitialized = true
            self.openMainWindow()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // This will make the main window appear if it has been closed
        // and the user ⌘-Tabs to the app or at any other moment when
        // it's foregrounded.

//        func noVisibleWindows() -> Bool {
//            for w in NSApp.windows {
//                if w.isVisible {
//                    return false
//                }
//            }
//            return true
//        }
//
//        if noVisibleWindows() {
//            openMainWindow()
//        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When the user clicks on the app-icon and there's no window, open a window.
        os_log("%{public}s", log: logger, "application should handle reopen")

        if !flag {
            openMainWindow()
        }
        return true
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        os_log("%{public}s", log: logger, "received a remote device token")
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        os_log("%{public}s", log: logger, "received a remote notification")
        let dict = userInfo as! [String:NSObject]
        guard let notification: CKDatabaseNotification = CKNotification(fromRemoteNotificationDictionary: dict) as? CKDatabaseNotification else {
            return }
        cloudData.fetchChanges(in: notification.databaseScope) {
            os_log("%{public}s", log: logger, "completed change fetches: sending notification")
        }

    }
}

