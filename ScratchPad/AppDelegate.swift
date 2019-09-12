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

    private var statusBarItem = NSStatusItem()

    private let coreDataModelName = "ScratchPadModel"

    private var windowManager: WindowManager!
    private var cloudDB: CloudDB!
    private var localDB: LocalDB!
    private var preferences: Preferences!
    private var broker: DataBroker!

    private var isInitialized = false

    // MARK: - NSApplicationDelegate

    func applicationWillFinishLaunching(_ notification: Notification) {
        initAndConfigure()
        registerForUrlEvents()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        cloudDB.setup() {
            NSApp.registerForRemoteNotifications()
            self.isInitialized = true
            self.makeStatusBarItem()
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

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        return makeHelperMenu()
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

// MARK: - Menu Commands

extension AppDelegate {

    @IBAction func openPageBrowserWindow(_ sender: NSMenuItem) {
        let pageBrowser = PageBrowserWindowController()
        pageBrowser.window?.makeKeyAndOrderFront(self)
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

    @IBAction func toggleInspectorBar(_ sender: NSMenuItem) {
        // A custom action to be implemented by the editor text view as first responder.
    }

    @IBAction func revertSelectionToStandardAppearance(_ sender: NSMenuItem) {
        // A custom action to be implemented by the editor text view as first responder.
    }
}

// MARK: - Auxiliary Menu Concerns

extension AppDelegate {

    private func makeStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength )
        if let button = statusBarItem.button {
            button.image = NSImage(named: "skew")?.scaled(toHeight: 17)
            button.image?.isTemplate = true
            button.imageScaling = .scaleProportionallyDown
        }
        statusBarItem.menu = makeHelperMenu(includeQuit: true)
    }

    private func makeHelperMenu(includeQuit: Bool = false) -> NSMenu {
        let openMain = NSMenuItem(title: "Main ScratchPad", action: #selector(statusBarMenuSelected), keyEquivalent: "", tag: 1001)

        let openPageBrowser = NSMenuItem(title: "Page Browser", action: #selector(statusBarMenuSelected(_:)), keyEquivalent: "b", tag: 1002)
        openPageBrowser.keyEquivalentModifierMask = [.option, .command]

        let scratchPadSelector = NSMenuItem(title: "ScratchPads", action: nil, keyEquivalent: "")

        let padMenus = localDB.fetchNames().sorted().enumerated().map { index, name in
            NSMenuItem(title: name, action: #selector(statusBarMenuSelected(_:)), keyEquivalent: "", tag: 2001 + index)
        }

        let closeAll = NSMenuItem(title: "Close All ScratchPads", action: #selector(statusBarMenuSelected(_:)), keyEquivalent: "", tag: 3001)

        let quit = NSMenuItem(title: "Quit", action: #selector(statusBarMenuSelected(_:)), keyEquivalent: "q", tag: 9001)

        let menu = NSMenu()
        menu.addItem(openMain)
        menu.addItem(openPageBrowser)
        menu.addItem(.separator())
        menu.addItem(scratchPadSelector)
        for padMenu in padMenus {
            menu.addItem(padMenu)
        }
        menu.addItem(.separator())
        menu.addItem(closeAll)
        if includeQuit {
            menu.addItem(.separator())
            menu.addItem(quit)
        }
        return menu
    }

    @objc private func statusBarMenuSelected(_ sender: NSMenuItem) {
        switch sender.tag {
        case 1001:
            openMainWindow()
        case 1002:
            openPageBrowserWindow(sender)
        case 2001..<3001:
            let pageName = sender.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if localDB.exists(pageNamed: pageName) {
                NSApp.activate(ignoringOtherApps: true)
                windowManager.open(name: pageName)
            }
        case 3001:
            windowManager.closeAll()
        case 9001:
            NSApp.activate(ignoringOtherApps: true)
            NSApp.terminate(self)
        default:
            break
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

    @objc private func openMainWindow() {
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

