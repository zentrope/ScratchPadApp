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

    func relativeDescription() -> String {
        let seconds: Double = 60;
        let minutes: Double = 60 * 60
        let hours: Double = 24 * 60 * 60
        let days: Double = 3 * 24 * 60 * 60

        let duration = DateInterval(start: self, end: Date()).duration

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let doplerFormatter = DateComponentsFormatter()
        doplerFormatter.unitsStyle = .abbreviated

        switch duration {
        case 0..<seconds:
            doplerFormatter.allowedUnits = [.second]
        case 60..<minutes:
            doplerFormatter.allowedUnits = [.minute]
        case 0..<hours:
            doplerFormatter.allowedUnits = [.hour]
        case 0..<days:
            doplerFormatter.allowedUnits = [.day]
        default:
            return dateFormatter.string(from: self)
        }
        return doplerFormatter.string(from: duration) ?? dateFormatter.string(from: self)
    }

}
