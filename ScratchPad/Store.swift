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

    // Serialize attempts to update (in case we update the same object twice).
    // Use a timer to periodically update pages.
    private let updateQueue = DispatchQueue(label: "cloudkit.update.com.zentrope.ScratchPad")

    // Cache
    private var pages = [String:Article]()
    private var meta = [String:Data]()

    // Properties
    var names: [String] {
        get {
            return Array(pages.keys)
        }
    }

    func mainPage() -> Article {

        return self[mainArticle]
    }

    subscript(index: String) -> Article {
        get {
            if let page = pages[index.lowercased()] {
                return page
            }
            let newPage = self.newPage(index)
            pages[index] = newPage
            return newPage
        }
        set (newPage) {
            pages[newPage.index.lowercased()] = newPage
        }
    }

    func update(articleId id: String, page: Article, metadata: Data) {
        pages[id] = page
        meta[id] = metadata
    }

    func update(_ page: Article) {
        // The problem here is that ALL updates are serialized, even if they
        // can be applied in parallel. Maybe it doesn't matter for this app.
        pages[page.index] = page

        updateQueue.async {
            CloudData.shared.update(page: page, metadata: self.meta[page.index])
        }
    }

    private func newPage(_ name: String) -> Article {
        let article = makeArticle(name: name)
        DispatchQueue.global().async {
            CloudData.shared.save(page: article)
        }
        return article
    }

    private func makeArticle(name: String) -> Article {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16.0),
            .foregroundColor: NSColor.controlTextColor
        ]
        let index = name.lowercased()
        let message = index == mainArticle.lowercased() ? "Welcome!\n\n" : "\(name)\n\n"
        let body = NSAttributedString(string: message, attributes: attrs)
        return Article(name: name, body: body)
    }
}
