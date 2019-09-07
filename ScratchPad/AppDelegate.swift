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

    private let coreDataModelName = "ScratchPadModel"

    private var windowManager: WindowManager!
    private var cloudDB: CloudDB!
    private var localDB: LocalDB!
    private var preferences: Preferences!
    private var broker: DataBroker!

    private var isInitialized = false


    func applicationWillFinishLaunching(_ notification: Notification) {
        initAndConfigure()
        registerForUrlEvents()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        cloudDB.setup() {
            NSApp.registerForRemoteNotifications()
            self.isInitialized = true
            self.openMainWindow()
            //self.registerForCoreDataChanges()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // launchMainWindowIfNotWindowsOpen()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        os_log("%{public}s", log: logger, "received a remote device token")
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        os_log("%{public}s", log: logger, "Received a remote notification about an iCloud update.")
        let dict = userInfo as! [String:NSObject]
        guard let notification: CKDatabaseNotification = CKNotification(fromRemoteNotificationDictionary: dict) as? CKDatabaseNotification else {
            return }
        cloudDB.fetchChanges(in: notification.databaseScope) {
            os_log("%{public}s", log: logger, "Completed change fetches due to push notification.")
            NotificationCenter.default.post(name: .cloudDataChanged, object: self)
        }
    }
}


// MARK: - Develop Menu

extension AppDelegate {

    @IBAction func refreshAllFromCloud(_ sender: NSMenuItem) {
        preferences.zoneRecordChangeToken = nil
        preferences.databaseChangeToken = nil
        cloudDB.fetchChanges(in: .private) {
            os_log("%{public}s", log: logger, "Develop menu: refreshAllFromCloud completed.")
            NotificationCenter.default.post(name: .cloudDataChanged, object: self)
        }
    }
}

// MARK: - Implementation Details

extension AppDelegate {

    private func initAndConfigure() {
        localDB = LocalDB.instantiate(name: coreDataModelName)
        preferences = Preferences()
        cloudDB = CloudDB(preferences: preferences)
        broker = DataBroker(database: localDB, cloudData: cloudDB)
        windowManager = WindowManager(broker: broker)

        cloudDB.action = { [weak self] event in
            switch event {
            case let .updatePage(name: name, record: record):
                self?.broker.replace(pageNamed: name, withRecord: record)
            case let .updateMetadata(name: _, record: record):
                self?.broker.replace(metadata: record)
            }
        }
    }

    private func registerForUrlEvents() {
        // For receiving a request to open a scratchpad URL outside the application
        let manager = NSAppleEventManager.shared()
        manager.setEventHandler(self, andSelector: #selector(handle(_:withReplyEvent:)),
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

    private func openMainWindow() {
        if isInitialized {
            windowManager.spawnMainPage()
        }
    }

    private func launchMainWindowIfNotWindowsOpen() {
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

    private func registerForCoreDataChanges() {
        NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: self.localDB.viewContext, queue: .main) { msg in
            print("Core Data Change Notification: note changes, bg thread can send 'em later.")

            guard let uinfo = msg.userInfo else { return }

            if let updated = uinfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
                print(" updated: \(updated.count)")
            }
            if let deleted = uinfo[NSDeletedObjectsKey] as? Set<NSManagedObject> {
                print(" deleted: \(deleted.count)")
            }
            if let inserted = uinfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
                print("inserted: \(inserted.count)")
            }
        }

    }
}

