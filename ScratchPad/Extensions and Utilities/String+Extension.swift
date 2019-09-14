//
//  String+Extension.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/11/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

extension String {

    func clean() -> String {
        return self.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    func trim(toSize: Int) -> String {
        if self.count < toSize {
            return self
        }

        return String(self.dropLast(self.count - toSize))
    }
}
