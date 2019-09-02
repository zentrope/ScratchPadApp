//
//  Page+CoreDataProperties.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/1/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//
//

import Foundation
import CoreData


extension Page {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Page> {
        return NSFetchRequest<Page>(entityName: "Page")
    }

    @NSManaged public var body: NSAttributedString
    @NSManaged public var dateCreated: Date
    @NSManaged public var dateUpdated: Date
    @NSManaged public var name: String

}
