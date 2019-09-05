//
//  MetadataValue.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/4/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation
import CloudKit

struct MetadataValue {

    var name: String
    var record: CKRecord // shouldn't this be data?

    static func fromManagedObject(metadata: RecordMetadataMO) -> MetadataValue {
        let name = metadata.name!
        let record = metadata.record as! CKRecord
        return MetadataValue(name: name, record: record)
    }

}
