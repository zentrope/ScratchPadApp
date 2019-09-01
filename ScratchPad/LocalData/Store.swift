//
//  Store.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa
import os.log

fileprivate let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Store")

class Store {

    static let shared = Store()

    private let mainArticleIndex = "Main"

    // Cache
    private var pages = Atomic([String:Article]())
    private var changes = Atomic(Set<String>())

    // Check for changed articles needing to be pushed to the server
    private var updateTimer: Timer?

    // Names are used to create links in the body text of articles for navigation
    var names: [String] {
        get {
            return Array(pages.deref().keys)
        }
    }

    init() {
        startChangeUploader()
    }

    /// Return the main/initial article
    func mainPage() -> Article {
        return find(index: mainArticleIndex)
    }

    /// Return an article with the given index, creating it if necessary.
    /// If the article isn't found, it'll be created in iCloud as well as the local cache.
    /// - Parameter index: The index of the article to find or create.
    func find(index: String) -> Article {
        if let page = pages.deref()[index.lowercased()] {
            return page
        }
        let newPage = self.newPage(index)
        pages.swap { $0[index] = newPage }
        return newPage
    }

    /// Replace the current version of the article with a new version.
    /// - Note: This does not attempt to synchronize with the cloud.
    /// - Parameter article: The new version of the article.
    func replace(article: Article) {
        pages.swap { $0[article.index] = article }
        changes.swap { $0.remove(article.index) }
    }

    /// Schedule an article for an update.
    ///
    /// The article is updated in the local cache immediately but is scheduled for a cloud update at a later time.
    ///
    /// - Parameter article: The article to be updated
    func update(article: Article) {
        pages.swap { $0[article.index] = article }
        changes.swap { $0.insert(article.index) }
    }

    private func startChangeUploader() {
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 5) { [ weak self] in
            self?.scheduleChangesForUpload()
        }
    }

    private func scheduleChangesForUpload() {
        let articleIndexes = self.changes.deref()
        if articleIndexes.isEmpty {
            self.startChangeUploader()
            return
        }
        let articles = self.pages.deref()
        let indexes = articleIndexes.compactMap { articles[$0] }
        os_log("%{public}s", log: logger, type: .debug, "Scheduling articles: '\(articleIndexes)', for iCloud update.")
        CloudData.shared.update(articles: indexes) { indexes in
            os_log("%{public}s", log: logger, type: .debug, "Articles updated: \(indexes.count).")
            self.changes.swap { $0.subtract(indexes) }
            self.startChangeUploader()
        }
    }

    private func newPage(_ name: String) -> Article {
        let article = makeArticle(name: name)
        CloudData.shared.create(article: article)
        return article
    }

    private func makeArticle(name: String) -> Article {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16.0),
            .foregroundColor: NSColor.controlTextColor
        ]
        let index = name.lowercased()
        let message = index == mainArticleIndex.lowercased() ? "Welcome!\n\n" : "\(name)\n\n"
        let body = NSAttributedString(string: message, attributes: attrs)
        return Article(name: name, body: body)
    }
}
