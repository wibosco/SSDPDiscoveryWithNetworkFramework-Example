//
//  SSDPSearchSession.swift
//  SSDPDiscoveryWithNetwork-Example
//
//  Created by William Boles on 20/11/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation
import Network
import os

enum SSDPSearchSessionError: Error {
    case searchAborted(Error)
}

protocol SSDPSearchSessionDelegate: AnyObject {
    func searchSession(_ searchSession: SSDPSearchSession, didFindService service: SSDPService)
    func searchSession(_ searchSession: SSDPSearchSession, didEncounterError error: SSDPSearchSessionError)
    func searchSessionDidStopSearch(_ searchSession: SSDPSearchSession, foundServices: [SSDPService])
}

protocol SSDPSearchSessionProtocol {
    var delegate: SSDPSearchSessionDelegate? { get set }
    
    func startSearch()
    func stopSearch()
}

class SSDPSearchSession: SSDPSearchSessionProtocol {
    weak var delegate: SSDPSearchSessionDelegate?
    
    private let connectionGroup: NWConnectionGroup
    private let configuration: SSDPSearchSessionConfiguration
    private let parser: SSDPServiceParserProtocol
    
    private let listeningQueue = DispatchQueue(label: "com.williamboles.listening.queue",  attributes: .concurrent)
    
    private var servicesFoundDuringSearch = [SSDPService]()
    
    private let searchTimeout: TimeInterval
    
    private var broadcastTimer: Timer?
    private var timeoutTimer: Timer?
    
    private lazy var mSearchMessage = {
        // Each line must end in `\r\n`
        return "M-SEARCH * HTTP/1.1\r\n" +
            "HOST: \(configuration.host):\(configuration.port)\r\n" +
            "MAN: \"ssdp:discover\"\r\n" +
            "ST: \(configuration.searchTarget)\r\n" +
            "MX: \(Int(configuration.maximumWaitResponseTime))\r\n" +
        "\r\n"
    }()
    
    // MARK: - Init
    
    init?(configuration: SSDPSearchSessionConfiguration, parser: SSDPServiceParserProtocol = SSDPServiceParser()) {
        guard let port = NWEndpoint.Port(rawValue: UInt16(configuration.port)) else {
            fatalError("Attempted to use an invalid port")
        }
        let host = NWEndpoint.Host(configuration.host)
        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        
        guard let multicastGroup = try? NWMulticastGroup(for: [endpoint]) else {
            fatalError("Failed to create multicast group")
        }
        
        self.connectionGroup = NWConnectionGroup(with: multicastGroup, using: .udp)
        
        self.configuration = configuration
        self.parser = parser
        self.searchTimeout = (TimeInterval(configuration.maximumBroadcastsBeforeClosing) * configuration.maximumWaitResponseTime) + 0.1
    }
    
    // MARK: - Search
    
    func startSearch() {
        guard configuration.maximumBroadcastsBeforeClosing > 0 else {
            delegate?.searchSessionDidStopSearch(self, foundServices: servicesFoundDuringSearch)
            return
        }
        
        os_log(.info, "SSDP search session starting")
        connectionGroup.stateUpdateHandler = connectionStateDidChange(to:)
        connectionGroup.setReceiveHandler(maximumMessageSize: 8767, rejectOversizedMessages: true) { message, content, isComplete in
            self.messageReceived(message: message, content: content, isComplete: isComplete)
        }
        connectionGroup.start(queue: listeningQueue)
        
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: searchTimeout, repeats: false, block: { [weak self] (timer) in
            self?.searchTimedOut()
        })
    }
    
    private func searchTimedOut() {
        os_log(.info, "SSDP search timed out")
        stopSearch()
    }
    
    func stopSearch() {
        os_log(.info, "SSDP search session stopping")
        close()
        
        delegate?.searchSessionDidStopSearch(self, foundServices:servicesFoundDuringSearch)
    }
    
    // MARK: - StateChange
    
    private func connectionStateDidChange(to state: NWConnectionGroup.State) {
        switch state {
        case .ready:
            os_log(.info, "Connection is in the `ready` state")
            sendMSearchMessages()
        case .waiting(_):
            os_log(.info, "Connection is in the `waiting` state")
        case .setup:
            os_log(.info, "Connection is in the `setup` state")
        case .cancelled:
            os_log(.info, "Connection is in the `cancelled` state")
        case .failed(let error):
            os_log(.info, "Connection is in the `failed` state")
            let wrappedError = SSDPSearchSessionError.searchAborted(error)
            delegate?.searchSession(self, didEncounterError: wrappedError)
            close()
        @unknown default:
            os_log(.info, "Connection is in an `unknown` state")
        }
    }
    
    // MARK: - Close
    
    private func close() {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        
        connectionGroup.cancel()
    }
    
    // MARK: Write
    
    private func sendMSearchMessages() {
        let message = mSearchMessage
        
        if configuration.maximumBroadcastsBeforeClosing > 1 {
            let window = searchTimeout - configuration.maximumWaitResponseTime
            let interval = window / TimeInterval((configuration.maximumBroadcastsBeforeClosing - 1))
            
            broadcastTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { [weak self] (timer) in
                self?.writeMessageToConnection(message)
            })
        }
                
        writeMessageToConnection(message)
    }
    
    private func writeMessageToConnection(_ message: String) {
        os_log(.info, "Writing to connection: \r%{public}@", message)
        
        let data = message.data(using: .utf8)
        connectionGroup.send(content: data) { error in
            guard let error = error else {
                return
            }
            os_log(.info, "Encountered error with sending: \r%{public}@", error.localizedDescription)
        }
    }
    
    // MARK: - Read
    
    private func messageReceived(message: NWConnectionGroup.Message, content: Data?, isComplete: Bool) {
        guard let content = content,
            !content.isEmpty,
            let service = parser.parse(content),
            searchedForService(service),
            !servicesFoundDuringSearch.contains(service) else {
                return
        }
        
        os_log(.info, "Received a valid service response")
        
        servicesFoundDuringSearch.append(service)
        
        delegate?.searchSession(self, didFindService: service)
    }
    
    private func searchedForService(_ service: SSDPService) -> Bool {
        return service.searchTarget.contains(configuration.searchTarget) || configuration.searchTarget == "ssdp:all"
    }
}
