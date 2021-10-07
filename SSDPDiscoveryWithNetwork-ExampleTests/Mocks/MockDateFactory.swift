//
//  MockDateFactory.swift
//  SSDPDiscoveryWithNetwork-ExampleTests
//
//  Created by William Boles on 07/10/2021.
//  Copyright © 2021 William Boles. All rights reserved.
//

import Foundation
@testable import SSDPDiscoveryWithNetwork_Example

class MockDateFactory: DateFactoryProtocol {
    var currentDateClosure: (() -> Void)?
    
    var currentDateToBeReturned: Date = Date.distantPast
    
    func currentDate() -> Date {
        return currentDateToBeReturned
    }
}
