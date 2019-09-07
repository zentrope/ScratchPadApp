//
//  CKMetadataValueTransformer.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/2/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Cocoa
import CloudKit

@objc(CKMetadataValueTransformer)
class CKMetadataValueTransformer: ValueTransformer {

    override class func transformedValueClass() -> AnyClass {
        return CKRecord.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let record = value as? CKRecord else { return nil }
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }

        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }

        coder.requiresSecureCoding = true
        let record = CKRecord(coder: coder)
        coder.finishDecoding()
        return record
    }
}
