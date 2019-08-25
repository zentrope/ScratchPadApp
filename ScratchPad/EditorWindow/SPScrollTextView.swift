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
        case textDidChange(NSAttributedString)
    }

    var action: ((Event) -> Void)?

    private let scrollView = NSScrollView()
    private let textView = SPTextView()

    var attributedString: NSAttributedString = NSAttributedString() {
        didSet {
            textView.textStorage?.setAttributedString(attributedString)
            render()
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

extension NSMenu {
    func removeItemIfPresent(_ item: NSMenuItem) {
        if self.item(withTag: item.tag) != nil {
            self.removeItem(item)
        }
    }
}

extension SPScrollTextView: NSTextViewDelegate {

    @objc func makeNewPageLink(_ sender: NSMenuItem) {
        let range = textView.selectedRange()
        if let newPage = textView.textStorage?.attributedSubstring(from: range).string {
            WindowManager.shared.open(name: newPage)
            let newRange = NSMakeRange(range.location, 0)
            textView.setSelectedRange(newRange)
            render()
        }
    }

    private var connectMenu: NSMenuItem {
        let item = NSMenuItem()
        item.title = "Connect"
        item.tag = 666
        item.target = self
        item.action = #selector(makeNewPageLink(_:))
        return item
    }

    private var connectSep: NSMenuItem {
        let sep = NSMenuItem.separator()
        sep.tag = 667
        return sep
    }

    func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        menu.removeItemIfPresent(connectMenu)
        menu.removeItemIfPresent(connectSep)

        let range = view.selectedRange()
        let isLinkable = range.length > 0

        if !isLinkable {
            return menu
        }

        if let selection = view.textStorage?.attributedSubstring(from: range).string {
            if !WindowManager.shared.isValidLinkName(selection) {
                return menu
            }
        }

        menu.insertItem(connectMenu, at: 0)
        menu.insertItem(connectSep, at: 1)

        return menu
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let link = link as? String else { return false }
        if WindowManager.shared.isScratchPadLink(link: link) {
            WindowManager.shared.open(link: link)
            return true
        }
        return false
    }

    func render() {
        guard let source = textView.textStorage else { return }

        // TODO: This will remove legit http links, too. Hm.
        // Use: func enumerateAttribute(_ attrName: NSAttributedString.Key, in enumerationRange: NSRange, options opts: NSAttributedString.EnumerationOptions = [], using block: (Any?, NSRange, UnsafeMutablePointer<ObjCBool>) -> Void)
        source.removeAttribute(.link, range: NSMakeRange(0, source.length))
        for title in Store.shared.names {
            let link = WindowManager.shared.makeLink(title)
            do {
                try source.addLink(word: title, link: link)
            }

            catch {
                print("🔥 \(error)")
            }
        }
    }

    func textDidChange(_ notification: Notification) {
        render()
        action?(.textDidChange(textView.attributedString()))
    }
}

extension NSMutableAttributedString {

    func addLink(word: String, link: String) throws {
        let pattern = #"\b\#(word)\b"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])

        let matches = regex.matches(in: self.string, options: [], range: NSMakeRange(0, self.length))

        matches.forEach { m in
            self.addAttribute(.link, value: "\(link)", range: m.range)
        }
    }

}
