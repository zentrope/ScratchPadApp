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

    private var isInspectorVisible: Bool = true {
        didSet {
            guard let win = window else { return }
            if win.titlebarAccessoryViewControllers.count > 0 {
                win.titlebarAccessoryViewControllers[0].isHidden = !isInspectorVisible
            }
        }
    }

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

    func windowDidBecomeKey(_ notification: Notification) {
        // Hide then show the inspector bar because somehow there's a 26pt gap
        // between the inspector and the contentView if we don't. Some sort of
        // layout issue due to the way I'm programatticaly creating the window
        // and the content view?

        isInspectorVisible = false
        isInspectorVisible = true
    }

    func windowWillClose(_ notification: Notification) {
        self.window?.saveFrame(usingName: saveName)
        WindowManager.shared.close(forArticle: pageName)
    }
}
