//
//  EditorViewController.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/22/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

class EditorViewController: NSViewController {

    private let editor = EditorTextView()

    private var page: Article

    init(page: Article) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
        editor.attributedString = page.body
        render(editor.textView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let view = NSView()
        editor.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editor)

        NSLayoutConstraint.activate([
            editor.topAnchor.constraint(equalTo: view.topAnchor),
            editor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editor.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 640.0),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 480.0),
        ])

        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        editor.textView.delegate = self

        NotificationCenter.default.addObserver(forName: .cloudDataChanged, object: nil, queue: .main) { [weak self] _ in
            self?.reloadFromStore()
        }
    }

    private func updateText(_ string: NSAttributedString) {
        page.update(string)
        Store.shared.update(article: page)
    }

    private func reloadFromStore() {
        // What if there are local changes not found in the updated version? How
        // do you merge these?
        self.page = Store.shared.find(index: page.index)
        editor.attributedString = page.body
    }
}

extension NSMenu {
    func removeItemIfPresent(_ item: NSMenuItem) {
        if self.item(withTag: item.tag) != nil {
            self.removeItem(item)
        }
    }
}

extension EditorViewController: NSTextViewDelegate {

    @objc func makeNewPageLink(_ sender: NSMenuItem) {
        let range = editor.textView.selectedRange()
        if let newPage = editor.textView.textStorage?.attributedSubstring(from: range).string {
            WindowManager.shared.open(name: newPage)
            let newRange = NSMakeRange(range.location, 0)
            editor.textView.setSelectedRange(newRange)
            render(editor.textView)
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

    func render(_ textView: NSTextView) {
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
        if let textView = notification.object as? NSTextView {
            render(textView)
            updateText(textView.attributedString())
        }
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
