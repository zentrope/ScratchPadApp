//
//  PageBrowserViewController.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/11/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa

fileprivate enum ColumnId: String, CaseIterable {
    case name = "Name"
    case created = "Created"
    case updated = "Updated"
    case size = "Size"
    case snippet = "Snippet"

    func uiid() -> NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier(rawValue: self.rawValue)
    }
}

class PageBrowserViewController: NSViewController {

    private var scrollView = NSScrollView()
    private var tableView = NSTableView()

    var pages = [Page]()

    override func loadView() {
        let view = NSView(frame: .zero)

        tableView.gridStyleMask = [.dashedHorizontalGridLineMask]
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = false
        tableView.allowsColumnSelection = false
        tableView.rowSizeStyle = .default

        ColumnId.allCases.forEach {
            let c = NSTableColumn(identifier: $0.uiid())
            c.title = $0.rawValue
            c.headerCell.isBordered = true
            tableView.addTableColumn(c)
        }

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 500),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 400),
        ])

        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        reload()

        NotificationCenter.default.addObserver(forName: .cloudDataChanged, object: nil, queue: .main) {
            [weak self] _ in
            self?.reload()
        }
    }

    private func reload() {
        let data = Environment.shared.localDB?.fetch() ?? [Page]()
        pages = data.sorted(by: { $0.dateUpdated > $1.dateUpdated })
        tableView.reloadData()
    }
}

extension PageBrowserViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier else { return nil }
        guard let column = ColumnId(rawValue: identifier.rawValue) else { return nil }

        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? Cell ?? Cell(identifier: identifier)

        let page = pages[row]

        let text: String = {
            switch column {
            case .name: return page.name
            case .created: return page.dateCreated.dateAndTime
            case .updated: return page.dateUpdated.dateAndTime
            case .size: return "\(page.body.length)"
            case .snippet: return page.body.string.clean().trim(toSize: 300)
            }
        }()

        cell.text.stringValue = text
        return cell
    }

}

extension PageBrowserViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return pages.count
    }
}

class Cell: NSTableCellView {

    let text = NSTextField(wrappingLabelWithString: "")

    convenience init(identifier: NSUserInterfaceItemIdentifier) {
        self.init(frame: .zero)

        text.maximumNumberOfLines = 1
        text.lineBreakMode = .byTruncatingTail
        text.isSelectable = false
        text.translatesAutoresizingMaskIntoConstraints = false

        addSubview(text)

        NSLayoutConstraint.activate([
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])

    }
}
