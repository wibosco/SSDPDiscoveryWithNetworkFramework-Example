//
//  MulticastConnectionController.swift
//  SSDPDiscoveryWithNetwork-Example
//
//  Created by William Boles on 07/10/2021.
//  Copyright © 2021 William Boles. All rights reserved.
//

import Foundation
import Network
import os

protocol MulticastConnectionControllerDelegate: AnyObject {
    func controller(_ controller: MulticastConnectionControllerProtocol, didReceiveResponse response: Data)
    func controller(_ controller: MulticastConnectionControllerProtocol, didEncounterError error: Error)
}

protocol MulticastConnectionControllerProtocol: AnyObject {
    var delegate: MulticastConnectionControllerDelegate? { get set }
    
    func sendMessage(_ message: String)
    func close()
}

class MulticastConnectionController: MulticastConnectionControllerProtocol {
    weak var delegate: MulticastConnectionControllerDelegate?
    
    private let callbackQueue: DispatchQueue
    private let connectionGroup: NWConnectionGroup
    
    // MARK: - Init
    
    init?(host: String, port: UInt16, callbackQueue: DispatchQueue) {
        guard let multicastGroup = try? NWMulticastGroup(for: [.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))]) else {
            os_log(.info, "Failed to create multicast group")
            return nil
        }
        
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        self.connectionGroup = NWConnectionGroup(with: multicastGroup, using: parameters)
        self.callbackQueue = callbackQueue
        
        connectionGroup.setReceiveHandler(handler: responseReceivedFromConnection(message:content:isComplete:))
        connectionGroup.stateUpdateHandler = connectionStateDidChange(to:)
        
        connectionGroup.start(queue: callbackQueue)
    }
    
    private func connectionStateDidChange(to state: NWConnectionGroup.State) {
        switch state {
        case .ready:
            os_log(.info, "Connection is in the `ready` state")
        case .waiting(_):
            os_log(.info, "Connection is in the `waiting` state")
        case .setup:
            os_log(.info, "Connection is in the `setup` state")
        case .cancelled:
            os_log(.info, "Connection is in the `cancelled` state")
        case .failed(let error):
            os_log(.info, "Connection is in the `failed` state")
            self.delegate?.controller(self, didEncounterError: error)
        @unknown default:
            os_log(.info, "Connection is in an `unknown` state")
        }
    }
    
    private func responseReceivedFromConnection(message: NWConnectionGroup.Message, content: Data?, isComplete: Bool) {
        guard let content = content else {
            return
        }
        
        self.delegate?.controller(self, didReceiveResponse: content)
    }
    
    // MARK: - Send
    
    func sendMessage(_ message: String) {
        guard connectionGroup.ableToSendOrReceiveMessages else {
            os_log(.info, "Attempting to write to a closed connection group")
            return
        }
        
        // If `connectionGroup` isn't in the `ready` state, `send` queues any messages.
        // Once `connectionGroup` is in the `ready` state, queued messages are sent
        let data = message.data(using: .utf8)
        connectionGroup.send(content: data) { error in
            guard let error = error else {
                return
            }
            self.delegate?.controller(self, didEncounterError: error)
        }
    }
    
    // MARK: - Close
    
    func close() {
        connectionGroup.cancel()
    }
}

private extension NWConnectionGroup.State {
    var isSetup: Bool {
        self == .setup
    }
    
    var isReady: Bool {
        self == .ready
    }
    
    var isWaiting: Bool {
        guard case .waiting(_) = self else {
            return false
        }
        return true
    }
    
    var isCancelled: Bool {
        self == .cancelled
    }
    
    var isFailed: Bool {
        guard case .failed(_) = self else {
            return false
        }
        return true
    }
}

private extension NWConnectionGroup {
    var ableToSendOrReceiveMessages: Bool {
        state.isReady || state.isSetup
    }
}
