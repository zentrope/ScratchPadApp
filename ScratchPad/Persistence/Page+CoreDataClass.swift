//
//  Page+CoreDataClass.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/1/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Page)
public class Page: NSManagedObject {

    var bodyString: String? {
        get {
            if let data = bodyData {
                return String(data: data, encoding: .utf8)
            }
            return nil
        }
    }

    var bodyData: Data? {
        get {
            do {
                return try body.data(from: NSMakeRange(0, body.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            }
            catch {
                print("Attributed String to Data Error: \(error)")
                return nil
            }
        }
    }

}
