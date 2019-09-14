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

    func addLink(word: String, link: String) throws {
        let pattern = #"\b\#(word)\b"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])

        let matches = regex.matches(in: self.string, options: [], range: NSMakeRange(0, self.length))

        matches.forEach { m in
            self.addAttribute(.link, value: "\(link)", range: m.range)
        }
    }
}
