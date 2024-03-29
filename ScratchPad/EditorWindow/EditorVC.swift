//
//  EditorVC.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/22/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "EditorViewController")

final class EditorVC: NSViewController {

    private let editor = EditorTextView()

    private var page: Page
    private var changeObserver: NSObjectProtocol?
    private var remoteChangeObserver: NSObjectProtocol?

    init(page: Page) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
        editor.attributedString = page.body
        render(editor.textView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let view = NSView(frame: .zero)
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

        remoteChangeObserver = NotificationCenter.default.addObserver(forName: .cloudDatabaseDidChange, object: nil, queue: .main, using: { [weak self] _ in
            self?.reloadFromStore()
        })

        changeObserver = NotificationCenter.default.addObserver(forName: .localDatabaseDidChange, object: nil, queue: .main) { [weak self] msg in
            guard let self = self else { return }
            self.render(self.editor.textView)
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        NotificationCenter.default.removeObservers([changeObserver, remoteChangeObserver])
    }

    private func updateText(_ string: NSAttributedString) {
        Environment.database.update(page: page.name, withText: string)
    }

    private func reloadFromStore() {
        // Should only be invoked when a cloud sync comes in.
        self.page = Environment.database.find(index: page.name)
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

// MARK: - NSTextViewDelegate

extension EditorVC: NSTextViewDelegate {

    @objc private func makeNewPageLink(_ sender: NSMenuItem) {
        let range = editor.textView.selectedRange()
        if let newPage = editor.textView.textStorage?.attributedSubstring(from: range).string {
            Environment.windows.open(name: newPage)
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

    private var revertItem: NSMenuItem {
        return NSMenuItem(title: "Revert Appearance",
                          action: #selector(EditorTextView.revertSelectionToStandardAppearance(_:)),
                          keyEquivalent: "",
                          tag: 668)
    }

    func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        menu.removeItemIfPresent(connectMenu)
        menu.removeItemIfPresent(revertItem)
        menu.removeItemIfPresent(connectSep)

        let range = view.selectedRange()

        if range.length < 1 {
            return menu
        }

        guard let selection = view.textStorage?.attributedSubstring(from: range).string else { return menu }

        if !Environment.windows.isValidLinkName(selection) {
            menu.insertItem(revertItem, at: 0)
            menu.insertItem(connectSep, at: 1)
            return menu
        }

        menu.insertItem(connectMenu, at: 0)
        menu.insertItem(revertItem, at: 1)
        menu.insertItem(connectSep, at: 2)
        return menu
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let link = link as? String else { return false }
        if Environment.windows.isScratchPadLink(link: link) {
            Environment.windows.open(link: link)
            return true
        }
        return false
    }

    private func render(_ textView: NSTextView) {
        guard let source = textView.textStorage else { return }

        source.removeLinks(scheme: "scratchpad")

        do {
            try source.addLink(scheme: Windows.linkSchema, words: Environment.database.names)
        }

        catch {
            os_log("%{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }

    func textDidChange(_ notification: Notification) {
        if let textView = notification.object as? NSTextView {
            render(textView)
            updateText(textView.attributedString())
        }
    }
}
