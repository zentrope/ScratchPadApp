//
//  PageBrowserVC.swift
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

    func isInteger() -> Bool {
        return self == .size
    }

    func kvoKey() -> String {
        switch self {
        case .name: return "name"
        case .created: return "dateCreated"
        case .updated: return "dateUpdated"
        case .size: return "size"
        case .snippet: return "snippet"
        }
    }
}

class PageBrowserVC: NSViewController {

    private var scrollView = NSScrollView()
    private var tableView = NSTableView()
    private var contextMenu = NSMenu()

    private var pages = [Page]()
    private var changeObserver: NSObjectProtocol?

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
            c.sortDescriptorPrototype = NSSortDescriptor(key: $0.kvoKey(), ascending: true)
            if $0.isInteger() {
                c.headerCell.alignment = .right
            }
            tableView.addTableColumn(c)
        }

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: -1),
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
        tableView.doubleAction = #selector(openPageOnDoubleClick(_:))
        tableView.menu = contextMenu
        setupContextMenu()

        reload()

        changeObserver = NotificationCenter.default.addObserver(forName: .localDatabaseDidChange, object: nil, queue: .main) {
            [weak self] msg in
            guard let info = msg.userInfo else { return }
            guard let packet = info["updates"] as? DataUpdatePacket else { return }
            self?.reload(packet: packet)
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        NotificationCenter.default.removeObserver(changeObserver)
    }

    private func reload(packet: DataUpdatePacket) {
        let updatesDict = packet.updates.reduce(into: [String:Page]()) { (accum, page) in accum[page.name] = page }

        let deleteDict = packet.deletes.reduce(into: [String:Page]()) { (accum, page) in accum[page.name] = page }

        let cols = IndexSet(integersIn: 0..<self.tableView.tableColumns.count)

        for (index, page) in self.pages.enumerated() {
            if let update = updatesDict[page.name] {
                self.pages[index] = update
                self.tableView.reloadData(forRowIndexes: [index], columnIndexes: cols)
            }
        }

        let rowsToDelete = self.pages.enumerated().compactMap( { deleteDict[$1.name] != nil ? $0 : nil })
        for row in rowsToDelete {
            self.tableView.removeRows(at: [row], withAnimation: .effectFade)
            self.pages.remove(at: row)
        }

        packet.inserts.forEach {
            self.pages.insert($0, at: 0)
            self.tableView.insertRows(at: [0], withAnimation: .effectFade)
        }

        // This ends up reloading the table anyway, but at least we get the animation before hand.
        tableView(tableView, sortDescriptorsDidChange: [])
    }

    private func reload() {
        let data = Environment.database.pages
        pages = data.sorted(by: { $0.dateUpdated > $1.dateUpdated })
        tableView.reloadData()
    }

    @objc private func openPageOnDoubleClick(_ sender: NSTableView) {
        guard sender.clickedRow > -1 else { return }
        let page = pages[sender.clickedRow]
        Environment.windows.open(name: page.name)
    }
}

// MARK: - Context Menu

extension PageBrowserVC {

    private var openPageMenuItem: NSMenuItem {
        let item = NSMenuItem()
        item.title = "Open page"
        item.action = #selector(openPageClicked(_:))
        item.target = self
        return item
    }

    private var deletePageMenuItem: NSMenuItem {
        let item = NSMenuItem()
        item.title = "Delete page"
        item.action = #selector(deletePageClicked(_:))
        item.target = self
        return item
    }

    @objc private func deletePageClicked(_ sender: NSMenuItem) {
        guard tableView.clickedRow > -1 else { return }
        let page = pages[tableView.clickedRow]
        let title = "Delete \(page.name.capitalized)"
        let question = "Delete the ScratchPad named '\(page.name)'?"
        self.view.window?.confirm(title: title, question: question, { affirmative in
            if affirmative {
                Environment.windows.disappear(pageNamed: page.name)
                Environment.database.delete(page: page)
            }
        })
    }

    @objc private func openPageClicked(_ sender: NSMenuItem) {
        let row = tableView.clickedRow
        guard row > -1 else { return }
        let name = pages[row].name
        Environment.windows.open(name: name)
    }

    private func setupContextMenu() {
        contextMenu.addItem(openPageMenuItem)
        contextMenu.addItem(deletePageMenuItem)
    }

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(deletePageClicked(_:)) else { return true }
        let clickedPageName = pages[tableView.clickedRow].name
        let mainPageName = Environment.database.mainPageName
        return !(clickedPageName == mainPageName)
    }
}

// MARK: - NSTableViewDelegate

extension PageBrowserVC: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier else { return nil }
        guard let column = ColumnId(rawValue: identifier.rawValue) else { return nil }

        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? Cell ?? {
            if column.isInteger() {
                return Cell(identifier: identifier, type: .integer)
            } else {
                return Cell(identifier: identifier)
            }
        }()

        let page = pages[row]

        switch column {
        case .name: cell.set(page.name)
        case .created: cell.set(page.dateCreated.dateAndTime)
        case .updated: cell.set(page.dateUpdated.dateAndTime)
        case .size: cell.set(page.size)
        case .snippet: cell.set(page.snippet)
        }
        return cell
    }

}

// MARK: - NSTableViewDataSource

extension PageBrowserVC: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return pages.count
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        pages = NSArray(array: pages).sortedArray(using: tableView.sortDescriptors) as! [Page]
        tableView.reloadData()
    }
}

// MARK: - Cell

class Cell: NSView {

    enum Kind {
        case string, integer
    }

    private let text = NSTextField(wrappingLabelWithString: "")

    convenience init(identifier: NSUserInterfaceItemIdentifier, type: Cell.Kind = .string) {
        self.init(frame: .zero)

        text.maximumNumberOfLines = 1
        text.lineBreakMode = .byTruncatingTail
        text.isSelectable = false
        text.translatesAutoresizingMaskIntoConstraints = false

        if type == .integer {
            text.alignment = .right
        }

        addSubview(text)

        NSLayoutConstraint.activate([
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])
    }

    func set(_ value: String) {
        text.stringValue = value
    }

    func set(_ value: Int) {
        text.integerValue = value
    }
}
