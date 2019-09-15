//
//  EditorWC.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "EditorWC")

class EditorWC: NSWindowController {

    private var controller: EditorVC
    private var pageName: String
    private var saveName: NSWindow.FrameAutosaveName

    init(page: Page) {
        let position = NSMakeRect(200, 200, 600, 600)
        let window = NSWindow(contentRect: position, styleMask: [.closable, .resizable, .titled, .miniaturizable], backing: .buffered, defer: true)

        self.pageName = page.name
        self.saveName = Environment.windows.makeAutosaveName(forPageNamed: pageName)
        self.controller = EditorVC(page: page)

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

extension EditorWC: NSWindowDelegate {

    func windowWillClose(_ notification: Notification) {
        self.window?.saveFrame(usingName: saveName)
        Environment.windows.close(pageNamed: pageName)
    }
}
