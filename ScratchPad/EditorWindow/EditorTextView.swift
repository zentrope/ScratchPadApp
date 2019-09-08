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

        textView.usesInspectorBar = false
        textView.usesRuler = true
        textView.usesFindBar = true

        textView.font = NSFont.systemFont(ofSize: 16)
        textView.textContainerInset = NSMakeSize(10, 10)
        textView.autoresizingMask = [.width, .height]

        textView.isRichText = true
        textView.isAutomaticDataDetectionEnabled = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
    }

    @objc func toggleInspectorBar(_ sender: Any) {
        textView.usesInspectorBar.toggle()
    }

    static let defaultAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 16.0),
        .foregroundColor: NSColor.controlTextColor,
        .backgroundColor: NSColor.controlBackgroundColor
    ]

    @objc func revertSelectionToStandardAppearance(_ sender: Any) {
        guard let storage = textView.textStorage,
            let delegate = textView.delegate else { return }

        let range = textView.selectedRange()
        storage.setAttributes(EditorTextView.defaultAttributes, range: range)

        let msg = Notification(name: NSText.didChangeNotification, object: textView)
        delegate.textDidChange?(msg)
    }
}

