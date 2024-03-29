//
//  Windows.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "WindowManager")

class Windows {

    static let linkSchema = "scratchpad://" // Defined in info.plist, probably should be pulled from Bundle in an extension

    private var windows = [String:EditorWC]()

    var count: Int {
        get { return windows.count }
    }

    init() {
    }

    func makeAutosaveName(forPageNamed name: String) -> String {
        return "SPEditorWindow.\(name)"
    }

    func removeAutosave(forPageNamed name: String) {
        Environment.preferences.removeWindowFramePosition(withName: makeAutosaveName(forPageNamed: name))
    }

    func isScratchPadLink(link: String) -> Bool {
        return link.lowercased().hasPrefix(Windows.linkSchema)
    }

    func makeLink(_ name: String) -> String {
        return "\(Windows.linkSchema)\(name)"
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
            os_log("%{public}s", log: logger, type: .debug, "Making '\(name)' window key")
            win.window?.makeKeyAndOrderFront(self)
        } else {
            os_log("%{public}s", log: logger, type: .debug, "Spawning new '\(name)' window")
            spawn(Environment.database.find(index: name))
        }
    }

    func open(page: Page) {
        if let win = windows[page.name] {
            win.window?.makeKeyAndOrderFront(self)
        } else {
            spawn(page)
        }
    }

    func spawnMainPage() {
        open(page: Environment.database.mainPage())
    }

    func spawn(_ page: Page) {
        let c = EditorWC(page: page)
        c.window?.makeKeyAndOrderFront(self)
        windows[page.name] = c
    }

    func closeAll() {
        for (name, _) in windows {
            if let win = windows[name] {
                win.close()
            }
        }
    }

    func disappear(pageNamed name: String) {
        if let win = windows[name]?.window {
            if win.isVisible {
                win.close()
            }
        }
    }

    // The semantics here are messed up, i.e., confusing.
    func close(pageNamed name: String) {
        os_log("%{public}s", log: logger, type: .debug, "Closing '\(name)' window.")
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
            .replacingOccurrences(of: Windows.linkSchema, with: "")
    }
}
