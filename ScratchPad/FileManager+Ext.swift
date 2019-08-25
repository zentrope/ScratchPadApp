//
//  FileManager+Extension.swift
//  ScratchPad
//
//  Created by Keith Irwin on 8/24/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

extension FileManager {

    private func applicationSupport() -> URL {
        var url = self.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url.appendPathComponent(Bundle.main.bundleIdentifier!)
        return url
    }

    private func appSupportFile(_ fname: String) -> URL {
        return applicationSupport().appendingPathComponent(fname)
    }

    private func appSupportDir(_ dir: String) -> URL {
        return applicationSupport().appendingPathComponent(dir)
    }

    private func create(pathAt url: URL) throws {
        try self.createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
    }
}
