//
//  SPTextView.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

class SPTextView: NSTextView {

    convenience init() {
        self.init(frame: .zero)
        isEditable = true
        isSelectable = true
        allowsUndo = true
        font = NSFont.systemFont(ofSize: 16)
        textContainerInset = NSMakeSize(5, 5)
        autoresizingMask = [.width, .height]
        isRichText = true
        isAutomaticDataDetectionEnabled = true
        isAutomaticLinkDetectionEnabled = true
        
    }
}
