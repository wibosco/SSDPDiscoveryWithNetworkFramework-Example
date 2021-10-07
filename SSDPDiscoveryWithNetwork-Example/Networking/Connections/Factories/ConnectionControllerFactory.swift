//
//  ConnectionControllerFactory.swift
//  SSDPDiscoveryWithNetwork-Example
//
//  Created by William Boles on 07/10/2021.
//  Copyright © 2021 William Boles. All rights reserved.
//

import Foundation

protocol ConnectionControllerFactoryProtocol {
    func createMulticastConnectionController(host: String, port: UInt16, callbackQueue: DispatchQueue) -> MulticastConnectionControllerProtocol?
}

class ConnectionControllerFactory: ConnectionControllerFactoryProtocol {
    
    // MARK: - Multicast
    
    func createMulticastConnectionController(host: String, port: UInt16, callbackQueue: DispatchQueue) -> MulticastConnectionControllerProtocol? {
        MulticastConnectionController(host: host, port: port, callbackQueue: callbackQueue)
    }
}
