//
//  PageBrowserWindowController.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/11/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

class PageBrowserWindowController: NSWindowController {

    private let autoSaveName = "SPBrowserWindow"
    private let viewController: PageBrowserViewController

    private static var windowController: PageBrowserWindowController?

    static func open() {
        guard windowController == nil else { return }

        let controller = PageBrowserWindowController()
        controller.window?.makeKeyAndOrderFront(nil)
        windowController = controller
    }

    private static func close() {
        PageBrowserWindowController.windowController = nil
    }

    init() {
        self.viewController = PageBrowserViewController()

        let mask: NSWindow.StyleMask = [.closable, .resizable, .titled, .miniaturizable]
        let place = NSMakeRect(300, 300, 300+500, 300+400)
        let window = NSWindow(contentRect: place, styleMask: mask, backing: .buffered, defer: true)

        super.init(window: window)

        window.delegate = self
        window.contentViewController = viewController
        window.title = "Page Browser"
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName(autoSaveName)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }
}

extension PageBrowserWindowController: NSWindowDelegate {

    func windowWillClose(_ notification: Notification) {
        self.window?.saveFrame(usingName: autoSaveName)
        PageBrowserWindowController.close()
    }
}
