//
//  SSEHandler.swift
//  CrowdCue_Frontend_Ios
//
//  Created by Abhiram Kasu on 5/18/25.
//


import Foundation

class SSEHandler: NSObject, URLSessionDataDelegate {
    private var eventBuffer = ""
    private var currentEventName: String?
    private var mimeType: String?
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if mimeType == nil, let response = dataTask.response as? HTTPURLResponse {
            mimeType = response.mimeType
        }
        
        // Only process if mime type is correct for SSE
        guard mimeType == "text/event-stream" else { return }
        
        if let receivedString = String(data: data, encoding: .utf8) {
            processEventData(receivedString)
        }
    }
    
    private func processEventData(_ string: String) {
        // Append new data to buffer
        eventBuffer += string
        
        // Process complete events (separated by two newlines)
        while let eventEnd = eventBuffer.range(of: "\n\n") {
            let eventString = eventBuffer[..<eventEnd.lowerBound]
            
            // Parse the event
            var event = [String: String]()
            for line in eventString.split(separator: "\n") {
                if let colonIndex = line.firstIndex(of: ":") {
                    let field = String(line[..<colonIndex])
                    // Trim the space after colon if present
                    let valueStartIndex = line.index(after: colonIndex)
                    let value: String
                    if valueStartIndex < line.endIndex && line[valueStartIndex] == " " {
                        value = String(line[line.index(after: valueStartIndex)...])
                    } else {
                        value = String(line[valueStartIndex...])
                    }
                    event[field] = value
                }
            }
            
            // Handle the event
            if let eventName = event["event"], let dataStr = event["data"] {
                if let data = dataStr.data(using: .utf8) {
                    // Post notification
                    NotificationCenter.default.post(
                        name: .sseDataReceived,
                        object: nil,
                        userInfo: ["event": eventName, "data": data]
                    )
                }
            }
            
            // Remove the processed event from buffer
            eventBuffer.removeSubrange(..<eventEnd.upperBound)
        }
    }
}

// Extension to URLSession to support SSE
extension URLSession {
    static func createSSESession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(Int32.max)
        configuration.timeoutIntervalForResource = TimeInterval(Int32.max)
        
        let sseHandler = SSEHandler()
        return URLSession(configuration: configuration, delegate: sseHandler, delegateQueue: nil)
    }
}