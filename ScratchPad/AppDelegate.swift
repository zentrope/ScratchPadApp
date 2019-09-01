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

    private var isInitialized = false

    private func openMainWindow() {
        os_log("%{public}s", log: logger, "open main window on main page")
        if !isInitialized {
            os_log("%{public}s", log: logger, "refusing to open main window until init complete")
            return
        }
        WindowManager.shared.spawn(Store.shared.mainPage())
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        let manager = NSAppleEventManager.shared()
        manager.setEventHandler(self,
                                andSelector: #selector(handle(_:withReplyEvent:)),
                                forEventClass:AEEventClass(kInternetEventClass),
                                andEventID: AEEventID(kAEGetURL))
    }

    @objc func handle(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlStr = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
        guard let link = urlStr.removingPercentEncoding else { return }
        if WindowManager.shared.isScratchPadLink(link: link) {
            WindowManager.shared.open(link: link)
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("%{public}s", log: logger, "application finished launching")
        CloudData.shared.setup() {
            os_log("%{public}s", log: logger, "setup.callback: registering for remote notifications")
            NSApp.registerForRemoteNotifications()
            os_log("%{public}s", log: logger, "setup.callback: opening main window")
            self.isInitialized = true
            self.openMainWindow()
        }
        os_log("%{public}s", log: logger, "application finished launching handler complete")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // This will make the main window appear if it has been closed
        // and the user clicks the app icon, or ⌘-Tabs to the app.

        os_log("%{public}s", log: logger, "application did become active")
        func noVisibleWindows() -> Bool {
            for w in NSApp.windows {
                if w.isVisible {
                    return false
                }
            }
            return true
        }

        if noVisibleWindows() {
            openMainWindow()
        }
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
        CloudData.shared.fetchChanges(in: notification.databaseScope) {
            os_log("%{public}s", log: logger, "completed change fetches: sending notification")
        }

    }
}

