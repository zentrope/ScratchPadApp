//
//  Environment.swift
//  ScratchPad
//
//  Created by Keith Irwin on 9/11/19.
//  Copyright © 2019 Zentrope. All rights reserved.
//

import Foundation

class Environment {

    static let shared = Environment()

    var dataBroker: DataBroker?
    var windowManager: WindowManager?

    init() {
    }
}
