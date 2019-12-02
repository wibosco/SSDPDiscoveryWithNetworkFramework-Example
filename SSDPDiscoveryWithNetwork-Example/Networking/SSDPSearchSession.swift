//
//  SSDPSearchSession.swift
//  SSDP-Example
//
//  Created by William Boles on 17/02/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation
import Network
import os

enum SSDPSearchSessionError: Error {
    case addressCreationFailure
    case searchAborted(Error)
}

protocol SSDPSearchSessionDelegate: class {
    func searchSession(_ searchSession: SSDPSearchSession, didFindService service: SSDPService)
    func searchSession(_ searchSession: SSDPSearchSession, didAbortWithError error: SSDPSearchSessionError)
    func searchSessionDidStopSearch(_ searchSession: SSDPSearchSession, foundServices: [SSDPService])
}

//TODO: Look into https://forums.swift.org/t/socket-api/19971/9
class SSDPSearchSession {
    weak var delegate: SSDPSearchSessionDelegate?

    private let connection: NWConnection
    private let configuration: SSDPSearchSessionConfiguration
    private var isListening = false
    private let listeningQueue = DispatchQueue(label: "com.williamboles.listening")
    private var servicesFoundDuringSearch = [SSDPService]()
    private var broadcastTimer: Timer?
    private var timeoutTimer: Timer?
    
    // MARK: - Init
    
    init?(configuration: SSDPSearchSessionConfiguration) {
        guard let port = NWEndpoint.Port(rawValue: UInt16(configuration.port)) else {
            fatalError("Attempted to use an invalid port")
        }
        let host = NWEndpoint.Host(configuration.host)
        self.connection = NWConnection(host: host, port: port, using: .udp)
        self.configuration = configuration
    }
    
    deinit {
        stopSearch()
    }
    
    // MARK: - Search
    
    func startSearch() {
        os_log(.info, "SSDP search session starting")
        connection.stateUpdateHandler = stateDidChange(to:)
        connection.receiveMessage(completion: processResponse(data:context:isCompleted:error:))

//        connection.start(queue: DispatchQueue.main)
        connection.start(queue: listeningQueue)

//        broadcast()
    }
    
    private func searchTimedOut() {
        os_log(.info, "SSDP search timed out")
        close(dueToError: nil)
    }
    
    func stopSearch() {
        os_log(.info, "SSDP search session stopping")
        close(dueToError: nil)
    }
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .ready:
            os_log(.info, "Connection is a ready state")
            broadcast()
        case .waiting(_):
            os_log(.info, "Connection is a waiting state")
        case .setup:
            os_log(.info, "Connection is a setup state")
        case .cancelled:
            os_log(.info, "Connection is a cancelled state")
        case .preparing:
            os_log(.info, "Connection is a preparing state")
        case .failed(_):
            os_log(.info, "Connection is a failed state")
        @unknown default:
            os_log(.info, "Connection is an unknown state")
        }
    }
    
    // MARK: - Close
    
    private func close(dueToError error: SSDPSearchSessionError?) {
        guard isListening else {
            return
        }
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        isListening = false
        connection.cancel()

        if let error = error {
            delegate?.searchSession(self, didAbortWithError: error)
        } else {
            delegate?.searchSessionDidStopSearch(self, foundServices: servicesFoundDuringSearch)
        }
    }
    
    private func handleError(_ error: Error) {
        os_log(.error, "SSDP discovery error: %{public}@", error.localizedDescription)
        let wrappedError = SSDPSearchSessionError.searchAborted(error)
        close(dueToError: wrappedError)
    }
    
    // MARK: Write
    
    private func broadcast() {
        let searchTimeout = (TimeInterval(configuration.maximumBroadcastsBeforeClosing) * configuration.maximumWaitResponseTime) + 0.1
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: searchTimeout, repeats: false, block: { [weak self] (timer) in
            self?.searchTimedOut()
        })
        let runLoop = RunLoop.main
        runLoop.add(timeoutTimer, forMode: .common)
//        runLoop.run()
//
        self.timeoutTimer = timeoutTimer
        
        broadcastMultipleSearchRequests()
    }
    
    private func broadcastMultipleSearchRequests() {
        let searchMessage = self.searchMessage()
        let broadcastTimer = Timer.scheduledTimer(withTimeInterval: configuration.maximumWaitResponseTime, repeats: true, block: { [weak self] (timer) in
            self?.writeToConnection(searchMessage)
        })
        broadcastTimer.fire()
        
        let runLoop = RunLoop.main
        runLoop.add(broadcastTimer, forMode: .common)
        
        self.broadcastTimer = broadcastTimer
    }
    
    private func writeToConnection(_ datagram: String) {
        os_log(.info, "Writing to connection")
//        let data = datagram.data(using: .utf8)
//        connection.send(content: data, completion: .contentProcessed({ (_) in
//             os_log(.info, "Data sent")
//         }))
    }
    
    private func searchMessage() -> String {
        // Each line must end in `\r\n`
        return "M-SEARCH * HTTP/1.1\r\n" +
            "HOST: \(configuration.host):\(configuration.port)\r\n" +
            "MAN: \"ssdp:discover\"\r\n" +
            "ST: \(configuration.searchTarget)\r\n" +
            "MX: \(Int(configuration.maximumWaitResponseTime))\r\n" +
        "\r\n"
    }
    
    // MARK: - Read
    
    private func processResponse(data: Data?, context: NWConnection.ContentContext?, isCompleted: Bool, error: NWError?) {
        guard let data = data,
            error != nil else {
                if let error = error {
                    handleError(error)
                }
                return
        }
        
        guard let service = SSDPServiceParser.parse(data),
            searchedForService(service),
            !servicesFoundDuringSearch.contains(service) else {
                return
        }
        
        servicesFoundDuringSearch.append(service)

        delegate?.searchSession(self, didFindService: service)
    }
    
    private func searchedForService(_ service: SSDPService) -> Bool {
        return service.searchTarget.contains(configuration.searchTarget) || configuration.searchTarget == "ssdp:all"
    }
}
