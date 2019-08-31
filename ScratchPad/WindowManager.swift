//
//  WindowManager.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

class WindowManager {

    // NOTE: Could create Store object here and pass it in to windows to
    //       facilitate testing.

    static let linkSchema = "scratchpad://" // Set in info.plist
    static let shared = WindowManager()

    private var windows = [String:EditorWindowController]()

    var count: Int {
        get { return windows.count }
    }

    init() {
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
            win.window?.makeKeyAndOrderFront(self)
        } else {
            spawn(Store.shared[name])
        }
    }

    func spawn(_ page: Article) {
        let c = EditorWindowController(page: page)
        c.window?.makeKeyAndOrderFront(self)
        windows[page.index] = c
    }

    func removeValue(forKey name: String) {
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
