//
//  EditorWindowController.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

class EditorWindowController: NSWindowController {

    private var controller: EditorViewController
    private var pageName: String
    private var saveName: NSWindow.FrameAutosaveName

    init(page: Page) {
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
        print("\(pageName) window became main window")
    }

    func windowDidResignKey(_ notification: Notification) {
        print("\(pageName) window resigned key window position")
        controller.save()
    }

    func windowWillClose(_ notification: Notification) {
        controller.save()
        self.window?.saveFrame(usingName: saveName)
        WindowManager.shared.removeValue(forKey: pageName)
        print("\(WindowManager.shared.count) windows remaining")
    }
}
