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
    private var broker: DataBroker!
    private var windowManager: WindowManager!

    init(broker: DataBroker, page: Page, windowManager: WindowManager) {
        self.windowManager = windowManager
        self.broker = broker
        let window = NSWindow(contentRect: .zero, styleMask: [.closable, .resizable, .titled, .miniaturizable], backing: .buffered, defer: true)

        self.pageName = page.name
        self.saveName = NSWindow.FrameAutosaveName("SPEditorWindow.\(pageName)")
        self.controller = EditorViewController(broker: broker, page: page, windowManager: windowManager)

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

    func windowWillClose(_ notification: Notification) {
        self.window?.saveFrame(usingName: saveName)
        windowManager.close(pageNamed: pageName)
    }
}
