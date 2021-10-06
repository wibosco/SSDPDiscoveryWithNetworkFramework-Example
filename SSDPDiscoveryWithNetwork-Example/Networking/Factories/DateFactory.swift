//
//  DateFactory.swift
//  SSDPDiscoveryWithNetwork-Example
//
//  Created by William Boles on 06/10/2021.
//  Copyright © 2021 William Boles. All rights reserved.
//

import Foundation

protocol DateFactoryProtocol {
    func currentDate() -> Date
}

class DateFactory: DateFactoryProtocol {
    
    // MARK: - Current
    
    func currentDate() -> Date {
        return Date()
    }
}
