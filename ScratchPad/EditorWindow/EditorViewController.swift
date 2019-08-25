//
//  EditorViewController.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/22/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

class EditorViewController: NSViewController {

    private let editor = SPScrollTextView()

    private var page: Page

    init(page: Page) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
        editor.attributedString = page.body
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

        editor.action = { [weak self] event in
            self?.dispatchEvent(event)
        }
    }

    private func dispatchEvent(_ event: SPScrollTextView.Event) {
        switch event {
        case let .textDidChange(attributedString):
            page.update(attributedString)
            Store.shared.save(page)
        }
    }
}

