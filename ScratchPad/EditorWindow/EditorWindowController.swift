//
//  EditorWindowController.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa



class EditorWindowController: NSWindowController {

    // Should be name of doc:windowcontroller
    static var windows = [EditorWindowController]()

    static func spawn() {
        let c = EditorWindowController()
        c.window?.makeKeyAndOrderFront(self)
        windows.append(c)
    }

    convenience init() {
        let window = NSWindow(contentRect: .zero, styleMask: [.closable, .resizable, .titled, .miniaturizable], backing: .buffered, defer: true)
        self.init(window: window)
        setupWindow(window: window)
    }

    private func setupWindow(window: NSWindow) {
        window.title = "ScratchPad"
        window.titleVisibility = .visible
        window.contentViewController = EditorViewController()
        window.isReleasedWhenClosed = false
        window.delegate = self
    }

    override func close() {
        print("close called on window")
        super.close()
    }
}

extension EditorWindowController: NSWindowDelegate {

    func windowWillClose(_ notification: Notification) {
        print("window will close", EditorWindowController.windows.count)
        EditorWindowController.windows.removeAll(where: { $0 == self })
    }

}
