//
//  EditorWindowController.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "EditorWindowController")

class EditorWindowController: NSWindowController {

    private var controller: EditorViewController
    private var pageName: String
    private var saveName: NSWindow.FrameAutosaveName

    init(page: Article) {
        let window = NSWindow(contentRect: .zero, styleMask: [.closable, .resizable, .titled, .miniaturizable], backing: .buffered, defer: true)

        self.pageName = page.index
        self.saveName = NSWindow.FrameAutosaveName("SPEditorWindow.\(pageName)")
        self.controller = EditorViewController(page: page)

        super.init(window: window)

        window.title = page.name
        window.titleVisibility = .visible
        window.contentViewController = self.controller
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName(saveName)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension EditorWindowController: NSWindowDelegate {

    func windowDidBecomeMain(_ notification: Notification) {
        os_log("%{public}s", log: logger, "'\(pageName)' window became key window'")
    }

    func windowDidResignKey(_ notification: Notification) {
        os_log("%{public}s", log: logger, "'\(pageName)' window resigned key window position")
        controller.save()
    }

    func windowWillClose(_ notification: Notification) {
        controller.save()
        self.window?.saveFrame(usingName: saveName)
        WindowManager.shared.removeValue(forKey: pageName)
        os_log("%{public}s", log: logger, "\(WindowManager.shared.count) windows remaining")
    }
}
