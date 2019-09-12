//
//  Date+Extension.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/11/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

extension Date {

    static var shortFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd @ hh:mm a"
        return f
    }

    var dateAndTime: String {
        return Date.shortFormatter.string(from: self)
    }
}
