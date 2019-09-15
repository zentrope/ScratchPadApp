//
//  NSWindow+Ext.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/14/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

extension NSWindow {

    func confirm(title: String, question: String, _ completion: @escaping (Bool) -> Void) {
        confirm(title: "\(title)?", question: question, yes: title, no: "Cancel", style: .warning, completion)
    }

    func confirm(title: String, question: String, yes: String, no: String, style: NSAlert.Style = .critical, _ completion: @escaping (Bool) -> Void) {

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = question
        alert.addButton(withTitle: yes)
        alert.addButton(withTitle: no)
        alert.alertStyle = style

        alert.beginSheetModal(for: self) { response in
            completion(response == .alertFirstButtonReturn)
        }
    }

    func alert(message: String, info: String? = nil, _ completion: (() -> Void)? = nil) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = message
        if let info = info {
            alert.informativeText = info
        }
        alert.beginSheetModal(for: self) { _ in
            completion?()
        }
    }
}
