//
//  CrowdCueHttpClient.swift
//  CrowdCue_Frontend_Ios
//
//  Created by Abhiram Kasu on 5/18/25.
//


import Foundation

// Combine is no longer needed for public interface, but URLSession.dataTaskPublisher might be used internally or replaced.
// For full async/await, we'll use URLSession.shared.data(for:)

@MainActor // Ensure @Published properties are updated on the main thread
class CrowdCueHttpClient: ObservableObject {
    private let baseURL = "http://192.168.10.33:8080" // Ensure this is your correct local IP or hostname
    private var authToken: String?
    
    // SSE related properties
    private var sseTask: URLSessionDataTask?
    private var sseDelegate: SSEStreamDelegate?

    @Published var currentPartyState = PartyState()
    @Published var isConnected = false
    @Published var errorMessage: String? // Keep for general errors if needed
    
    // Store party code after creation/joining
    @Published var currentPartyCode: String?
    
    // MARK: - Auth Methods
    
    func createParty(username: String, partyName: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/createParty") else {
            throw URLError(.badURL)
        }
        
        let requestPayload = CreatePartyRequest(username: username, partyName: partyName)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(requestPayload)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorData = String(data: data, encoding: .utf8) ?? "Unknown HTTP error"
            throw NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: ["message": errorData])
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.authToken = authResponse.token
        self.currentPartyCode = authResponse.partyCode
        return authResponse.partyCode ?? ""
    }
    
    func joinParty(partyCode: String, username: String) async throws {
        guard let url = URL(string: "\(baseURL)/auth/joinParty") else {
            throw URLError(.badURL)
        }
        
        let requestPayload = JoinPartyRequest(partyCode: partyCode, username: username)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(requestPayload)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorData = String(data: data, encoding: .utf8) ?? "Unknown HTTP error"
            throw NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: ["message": errorData])
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.authToken = authResponse.token
        self.currentPartyCode = partyCode // Use the provided partyCode for joining
    }
    
    // MARK: - SSE Methods
    
    func subscribeToParty(partyCode: String) -> AsyncThrowingStream<SSEEvent, Error> {
        return AsyncThrowingStream { continuation in
            guard let authToken = self.authToken else {
                continuation.finish(throwing: NSError(domain: "Auth", code: 401, userInfo: ["message": "Not authenticated"]))
                return
            }
            
            guard let url = URL(string: "\(baseURL)/realtime/\(partyCode)") else {
                continuation.finish(throwing: URLError(.badURL))
                return
            }
            
            var request = URLRequest(url: url)
            request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.timeoutInterval = TimeInterval(Int32.max) // Keep connection open for SSE

            // Create a new delegate for each subscription
            // sseDelegate and sseTask are @MainActor isolated, so their assignment should be on the main actor.
            // However, their creation and the session.dataTask can be prepared off the main actor.
            // The critical part is that the URLSession's delegate methods will be called on its delegateQueue.
            
            let delegate = SSEStreamDelegate(continuation: continuation, httpClient: self)
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: OperationQueue()) // Use a dedicated queue
            
            let task = session.dataTask(with: request)
            
            // Assign to main-actor isolated properties on the main actor
            Task { @MainActor in
                self.sseDelegate = delegate
                self.sseTask = task
                self.sseTask?.resume()
            }

            continuation.onTermination = { @Sendable _ in
                // Dispatch operations on sseTask and sseDelegate to the main actor
                Task { @MainActor in
                    self.sseTask?.cancel()
                    self.sseTask = nil
                    self.sseDelegate = nil
                    self.isConnected = false
                }
            }
        }
    }

    // This method is called by SSEStreamDelegate on the MainActor
    fileprivate func parseRawSSEEvent(eventName: String, data: Data) -> SSEEvent {
        let decoder = JSONDecoder()
        // IMPORTANT: This method runs on MainActor because it updates @Published currentPartyState
        switch eventName {
        case "initial-state":
            do {
                let state = try decoder.decode(PartyState.self, from: data)
                self.currentPartyState = state
                return .initialState(state)
            } catch { return .error(error) }
            
        case "song_vote_update":
            do {
                let partyUpdate = try decoder.decode(PartyUpdate.self, from: data)
                if let song = partyUpdate.payload.unwrapSong() {
                    if let index = self.currentPartyState.songQueue.firstIndex(where: { $0.spotifyId == song.spotifyId }) {
                        self.currentPartyState.songQueue[index].votes = song.votes
                    }
                     // If song is not in queue, the backend should handle consistency.
                    // Or, if it's the current song:
                    else if self.currentPartyState.currentSong?.spotifyId == song.spotifyId {
                         self.currentPartyState.currentSong?.votes = song.votes
                    }
                    return .songVoteUpdate(song)
                }
                return .error(NSError(domain: "SSEParse", code: 1, userInfo: ["message": "Failed to unwrap song from vote update"]))
            } catch { return .error(error) }
            
        case "song_queue_addition":
            do {
                let partyUpdate = try decoder.decode(PartyUpdate.self, from: data)
                if let song = partyUpdate.payload.unwrapSong() {
                    // Avoid duplicates if backend might send them
                    if !self.currentPartyState.songQueue.contains(where: { $0.id == song.id }) {
                        self.currentPartyState.songQueue.append(song)
                    }
                    return .songQueueAddition(song)
                }
                return .error(NSError(domain: "SSEParse", code: 2, userInfo: ["message": "Failed to unwrap song from queue addition"]))
            } catch { return .error(error) }
            
        case "current_song_update":
            do {
                let partyUpdate = try decoder.decode(PartyUpdate.self, from: data)
                if let song = partyUpdate.payload.unwrapSong() {
                    self.currentPartyState.currentSong = song
                    // If this new current song was in queue, remove it
                    self.currentPartyState.songQueue.removeAll(where: { $0.id == song.id })
                    return .currentSongUpdate(song)
                }
                return .error(NSError(domain: "SSEParse", code: 3, userInfo: ["message": "Failed to unwrap song from current song update"]))
            } catch { return .error(error) }
            
        case "playback_status_update":
            do {
                let partyUpdate = try decoder.decode(PartyUpdate.self, from: data)
                if let isPlaying = partyUpdate.payload.unwrapBool() {
                    self.currentPartyState.playing = isPlaying
                    return .playbackStatusUpdate(isPlaying)
                }
                return .error(NSError(domain: "SSEParse", code: 4, userInfo: ["message": "Failed to unwrap bool from playback status update"]))
            } catch { return .error(error) }
            
        case "duration_update":
            do {
                let partyUpdate = try decoder.decode(PartyUpdate.self, from: data)
                if let duration = partyUpdate.payload.unwrapInt() {
                    self.currentPartyState.currentDuration = duration
                    return .durationUpdate(duration)
                }
                return .error(NSError(domain: "SSEParse", code: 5, userInfo: ["message": "Failed to unwrap int from duration update"]))
            } catch { return .error(error) }
            
        default:
            print("Unknown SSE event type: \(eventName)")
            return .error(NSError(domain: "SSE", code: 0, userInfo: ["message": "Unknown event type: \(eventName)"]))
        }
    }
    
    func unsubscribeFromParty() {
        sseTask?.cancel() // This will trigger the onTermination block of the AsyncStream
        // sseTask = nil and sseDelegate = nil are handled in onTermination
    }
    
    // MARK: - Party Updates
    
    func sendPartyUpdate(partyCode: String, update: PartyUpdate) async throws {
        guard let authToken = authToken else {
            throw NSError(domain: "Auth", code: 401, userInfo: ["message": "Not authenticated"])
        }
        guard let url = URL(string: "\(baseURL)/realtime/\(partyCode)/update") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(update)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorData = String(data: data, encoding: .utf8) ?? "Unknown HTTP error during update"
            throw NSError(domain: "HTTPUpdate", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: ["message": errorData])
        }
        // Update sent successfully, no data expected in return for this endpoint typically
    }
    
    // Convenience methods for common updates
    
    func voteSong(partyCode: String, song: Song) async throws {
        let updatedSong = Song( // Assuming vote increments locally before sending, or backend handles it
            spotifyId: song.spotifyId,
            title: song.title,
            artist: song.artist,
            coverPhotoUrl: song.coverPhotoUrl,
            votes: song.votes // Backend should handle the increment logic based on user vote
        )
        let update = PartyUpdate(type: .SONG_VOTE_UPDATE, partyId: partyCode, payload: AnyCodable(updatedSong))
        try await sendPartyUpdate(partyCode: partyCode, update: update)
    }
    
    func addSongToQueue(partyCode: String, song: Song) async throws {
        let update = PartyUpdate(type: .SONG_QUEUE_ADDITION, partyId: partyCode, payload: AnyCodable(song))
        try await sendPartyUpdate(partyCode: partyCode, update: update)
    }
    
    func updateCurrentSong(partyCode: String, song: Song) async throws {
        let update = PartyUpdate(type: .CURRENT_SONG_UPDATE, partyId: partyCode, payload: AnyCodable(song))
        try await sendPartyUpdate(partyCode: partyCode, update: update)
    }
    
    func updatePlaybackStatus(partyCode: String, isPlaying: Bool) async throws {
        let update = PartyUpdate(type: .PLAYBACK_STATUS_UPDATE, partyId: partyCode, payload: AnyCodable(isPlaying))
        try await sendPartyUpdate(partyCode: partyCode, update: update)
    }
    
    func updateDuration(partyCode: String, duration: Int) async throws {
        let update = PartyUpdate(type: .DURATION_UPDATE, partyId: partyCode, payload: AnyCodable(duration))
        try await sendPartyUpdate(partyCode: partyCode, update: update)
    }
}

// MARK: - SSEStreamDelegate
// This delegate will handle the SSE connection and forward events to the AsyncThrowingStream's continuation.
private class SSEStreamDelegate: NSObject, URLSessionDataDelegate {
    private var eventBuffer = ""
    private let continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation
    private weak var httpClient: CrowdCueHttpClient?

    init(continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation, httpClient: CrowdCueHttpClient) {
        self.continuation = continuation
        self.httpClient = httpClient
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            continuation.finish(throwing: NSError(domain: "SSE", code: 0, userInfo: ["message": "Invalid response type"]))
            completionHandler(.cancel)
            return
        }

        if httpResponse.statusCode != 200 {
            continuation.finish(throwing: NSError(domain: "SSEConnect", code: httpResponse.statusCode, userInfo: ["message": "HTTP error \(httpResponse.statusCode)"]))
            completionHandler(.cancel)
            return
        }
        Task { @MainActor in self.httpClient?.isConnected = true }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let receivedString = String(data: data, encoding: .utf8) {
            eventBuffer += receivedString
            processBufferedEvents()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Don't finish if it's a cancellation error, as onTermination handles it.
            // However, URLSession may report cancellation as an error.
            // Let onTermination handle the cleanup if sseTask.cancel() was called.
            // If it's a genuine network error, then finish.
            let nsError = error as NSError
            if !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) {
                continuation.finish(throwing: error)
            }
        } else {
            continuation.finish() // Normal completion (server closed connection)
        }
        Task { @MainActor in self.httpClient?.isConnected = false }
    }

    private func processBufferedEvents() {
        guard let client = httpClient else {
            continuation.finish(throwing: NSError(domain: "SSE", code: 0, userInfo: ["message": "HTTPClient deallocated"]))
            return
        }
        while let eventEndRange = eventBuffer.range(of: "\n\n") {
            let eventBlock = String(eventBuffer[..<eventEndRange.lowerBound])
            eventBuffer.removeSubrange(..<eventEndRange.upperBound)

            var eventName: String?
            var dataLines = [String]()

            eventBlock.enumerateLines { line, _ in
                if line.hasPrefix("event:") {
                    eventName = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    dataLines.append(String(line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)))
                }
                // id and retry fields are ignored for now
            }
            
            let jsonDataString = dataLines.joined() // If data is multi-line

            if let name = eventName, let data = jsonDataString.data(using: .utf8) {
                Task { @MainActor in // Ensure parsing and state update happens on MainActor
                    let parsedEvent = client.parseRawSSEEvent(eventName: name, data: data)
                    continuation.yield(parsedEvent)
                }
            }
        }
    }
}

// Note: SSEEvent, PartyState, Song, Auth Models, etc., remain the same.
// AnyCodable also remains the same.
// Notification.Name.sseDataReceived is no longer needed.
