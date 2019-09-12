//
//  PageBrowserViewController.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/11/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

class PageBrowserViewController: NSViewController {

    override func loadView() {
        let view = NSView(frame: .zero)

        let text = NSTextField(labelWithString: "place holder")
        text.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(text)
        NSLayoutConstraint.activate([
            text.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            text.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 500),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 400),
        ])

        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
