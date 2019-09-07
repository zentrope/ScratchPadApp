//
//  NSImage+Extension.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/7/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

extension NSImage {

    func resized(to destSize: NSSize) -> NSImage {
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        self.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height), from: NSMakeRect(0, 0, self.size.width, self.size.height), operation: NSCompositingOperation.sourceOver, fraction: CGFloat(1))
        newImage.unlockFocus()
        newImage.size = destSize
        return NSImage(data: newImage.tiffRepresentation!)!
    }

    func scaled(toHeight height: CGFloat) -> NSImage {
        let width = height / self.size.height * self.size.width
        return resized(to: NSMakeSize(width, height))
    }
}
