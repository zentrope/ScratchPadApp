//
//  SPScrollTextView.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

class EditorTextView: NSView {

    enum Event {
        case textDidChange(NSAttributedString)
    }

    var action: ((Event) -> Void)?

    private let scrollView = NSScrollView()
    let textView = NSTextView()

    var attributedString: NSAttributedString = NSAttributedString() {
        didSet {
            textView.textStorage?.setAttributedString(attributedString)
        }
    }

    convenience init() {
        self.init(frame: .zero)

        setupTextView()

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func setupTextView() {
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 16)
        textView.textContainerInset = NSMakeSize(5, 5)
        textView.autoresizingMask = [.width, .height]
        textView.isRichText = true
        textView.isAutomaticDataDetectionEnabled = true
        textView.isAutomaticLinkDetectionEnabled = true
    }
}
