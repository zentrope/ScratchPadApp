//
//  SPScrollTextView.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

class SPScrollTextView: NSView {

    enum Event {
        case textDidChange
    }

    var action: ((Event) -> Void)?

    private let scrollView = NSScrollView()
    private let textView = SPTextView()

    var attributedString: NSAttributedString = NSAttributedString() {
        didSet {
            textView.textStorage?.setAttributedString(attributedString)
        }
    }

    convenience init() {
        self.init(frame: .zero)

        textView.delegate = self

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
}

extension SPScrollTextView: NSTextViewDelegate {

    func textDidChange(_ notification: Notification) {
        action?(.textDidChange)
    }
}
