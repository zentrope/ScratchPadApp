//
//  PageBrowserWC.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/11/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

class PageBrowserWC: NSWindowController {

    private let autoSaveName = "SPBrowserWindow"
    private let viewController: PageBrowserVC

    private static var windowController: PageBrowserWC?

    static func open() {
        guard windowController == nil else { return }

        let controller = PageBrowserWC()
        controller.window?.makeKeyAndOrderFront(nil)
        windowController = controller
    }

    private static func close() {
        PageBrowserWC.windowController = nil
    }

    init() {
        self.viewController = PageBrowserVC()

        let mask: NSWindow.StyleMask = [.closable, .resizable, .titled, .miniaturizable]
        let place = NSMakeRect(300, 300, 300+500, 300+400)
        let window = NSWindow(contentRect: place, styleMask: mask, backing: .buffered, defer: true)

        super.init(window: window)

        window.delegate = self
        window.contentViewController = viewController
        window.title = "ScratchPad Browser"
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

extension PageBrowserWC: NSWindowDelegate {

    func windowWillClose(_ notification: Notification) {
        self.window?.saveFrame(usingName: autoSaveName)
        PageBrowserWC.close()
    }
}
