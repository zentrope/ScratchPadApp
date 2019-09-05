//
//  WindowManager.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "WindowManager")

class WindowManager {

    static let linkSchema = "scratchpad://" // Defined in info.plist, probably should be pulled from Bundle in an extension

    private var windows = [String:EditorWindowController]()

    private var store: Store

    var count: Int {
        get { return windows.count }
    }

    init(store: Store) {
        self.store = store
    }

    func isScratchPadLink(link: String) -> Bool {
        return link.lowercased().hasPrefix(WindowManager.linkSchema)
    }

    func makeLink(_ name: String) -> String {
        return "\(WindowManager.linkSchema)\(name)"
    }

    func open(link urlStr: String) {
        if !isScratchPadLink(link: urlStr) { return }
        let name = unlink(urlStr)
        if isValidLinkName(name) {
            open(name: name)
        }
    }

    func open(name: String) {
        if let win = windows[name] {
            os_log("%{public}s", log: logger, type: .debug, "Making \(name) window key")
            win.window?.makeKeyAndOrderFront(self)
        } else {
            os_log("%{public}s", log: logger, type: .debug, "Spawning new '\(name)' window")
            spawn(store.find(index: name))
        }
    }

    func spawnMainPage() {
        spawn(store.mainPage())
    }

    func spawn(_ page: PageValue) {
        let c = EditorWindowController(store: store, page: page, windowManager: self)
        c.window?.makeKeyAndOrderFront(self)
        windows[page.name] = c
    }

    func close(forPageNamed name: String) {
        windows.removeValue(forKey: name)
    }

    func isValidLinkName(_ name: String) -> Bool {
        if name.contains("//:") || name.isEmpty {
            return false
        }
        if name.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            return false
        }
        return true
    }

    private func unlink(_ link: String) -> String {
        return link.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: WindowManager.linkSchema, with: "")
    }
}
