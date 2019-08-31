//
//  AppDelegate.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/22/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa
import CloudKit

// https://stackoverflow.com/questions/38613606/run-mac-app-with-cloudkit-connected-to-the-production-environment
// https://apple.co/2NGzsnV (CloudKit Quick Start)
// https://stackoverflow.com/questions/16364249/convert-nsattributedstring-to-string-and-back

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private func openMainWindow() {
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
        CloudData.shared.setup() {
            NSApp.registerForRemoteNotifications()
            self.openMainWindow()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // This will make the main window appear if it has been closed
        // and the user clicks the app icon, or ⌘-Tabs to the app.

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

        if !flag {
            openMainWindow()
        }
        return true
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("REMOTE got a device token")
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {

        print("REMOTE application did receive remote notification", userInfo)
        let dict = userInfo as! [String:NSObject]
        guard let notification: CKDatabaseNotification = CKNotification(fromRemoteNotificationDictionary: dict) as? CKDatabaseNotification else {
            return }
        CloudData.shared.fetchChanges(in: notification.databaseScope) {
            print("CHANGES WERE FETCHED")
            NotificationCenter.default.post(name: .cloudDataChanged, object: self)
        }

    }
}

