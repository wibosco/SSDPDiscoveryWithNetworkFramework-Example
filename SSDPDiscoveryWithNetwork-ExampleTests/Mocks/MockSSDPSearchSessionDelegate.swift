//
//  MockSSDPSearchSessionDelegate.swift
//  SSDPDiscoveryWithNetwork-ExampleTests
//
//  Created by William Boles on 07/10/2021.
//  Copyright © 2021 William Boles. All rights reserved.
//

import Foundation
@testable import SSDPDiscoveryWithNetwork_Example

class MockSSDPSearchSessionDelegate: SSDPSearchSessionDelegate {
    var didFindServiceClosure: ((SSDPSearchSession, SSDPService) -> Void)?
    var didEncounterErrorClosure:((SSDPSearchSession, SSDPSearchSessionError) -> Void)?
    var didStopSearchClosure: ((SSDPSearchSession, [SSDPService]) -> Void)?
    
    func searchSession(_ searchSession: SSDPSearchSession, didFindService service: SSDPService) {
        didFindServiceClosure?(searchSession, service)
    }
    
    func searchSession(_ searchSession: SSDPSearchSession, didEncounterError error: SSDPSearchSessionError) {
        didEncounterErrorClosure?(searchSession, error)
    }
    
    func searchSessionDidStopSearch(_ searchSession: SSDPSearchSession, foundServices: [SSDPService]) {
        didStopSearchClosure?(searchSession, foundServices)
    }
}
