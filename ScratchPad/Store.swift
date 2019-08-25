//
//  Store.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

class Store {

    static let shared = Store()

    private let mainArticle = "Main"

    private var pages = [String:Page]()

    var names: [String] {
        get {
            return pages.keys.map { $0 }
        }
    }

    func mainPage() -> Page {
        return self[mainArticle]
    }

    subscript(index: String) -> Page {
        get {
            return pages[index.lowercased()] ?? newPage(index)
        }
        set (newValue) {
            pages[index.lowercased()] = newValue
        }
    }

    func save(_ page: Page) {
        self[page.name] = page
    }

    private func newPage(_ name: String) -> Page {
        let index = name.lowercased()
        let message = index == mainArticle.lowercased() ? "Welcome!\n\n" : "\(name)\n\n"
        let body = NSAttributedString(string: message, attributes: [.font: NSFont.systemFont(ofSize: 16.0)])
        let page = Page(name: name, body: body)
        pages[index] = page
        return page
    }
}
