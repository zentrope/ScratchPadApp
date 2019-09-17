//
//  NSAttributedString+Extension.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/4/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

extension NSAttributedString {

    var rtfString: String? {
        if let data = self.rtf {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    var rtf: Data? {
        do {
            return try self.data(from: NSMakeRange(0, length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        }
        catch {
            return nil
        }
    }
}

extension NSMutableAttributedString {

    enum LinkError: Error, LocalizedError {
        case invalidUrl

        var localizedDescription: String {
            switch self {
            case .invalidUrl: return "Unable to form a ScratchPad URL."
            }
        }
    }

    func removeLinks(scheme: String) {
        self.enumerateAttribute(.link, in: NSMakeRange(0, self.length), options: []) { (link, range, stop) in
            if let link = link as? URL, link.scheme == scheme {
                self.removeAttribute(.link, range: range)
            }
            stop.pointee = false
        }
    }

    func addLink(scheme: String, words: [String]) throws {
        for word in words {
            try addLink(word: word, link: "\(scheme)://\(word)")
        }
    }

    func addLink(word: String, link: String) throws {
        guard let url = URL(string: link) else { throw LinkError.invalidUrl }
        let pattern = #"\b\#(word)\b"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])

        let matches = regex.matches(in: self.string, options: [], range: NSMakeRange(0, self.length))
        matches.forEach { m in
            self.addAttribute(.link, value: url, range: m.range)
        }
    }
}
