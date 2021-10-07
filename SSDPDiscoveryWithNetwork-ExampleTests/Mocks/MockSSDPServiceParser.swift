//
//  MockSSDPServiceParser.swift
//  SSDPDiscoveryWithNetwork-ExampleTests
//
//  Created by William Boles on 07/10/2021.
//  Copyright © 2021 William Boles. All rights reserved.
//

import Foundation
@testable import SSDPDiscoveryWithNetwork_Example

class MockSSDPServiceParser: SSDPServiceParserProtocol {
    var parseClosure: ((Data) -> Void)?
    
    var serviceToBeReturned: SSDPService?
    
    func parse(_ data: Data) -> SSDPService? {
        parseClosure?(data)
        
        return serviceToBeReturned
    }
}
