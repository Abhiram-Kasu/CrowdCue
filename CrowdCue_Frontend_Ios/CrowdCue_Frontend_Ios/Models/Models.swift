//
//  Song.swift
//  CrowdCue_Frontend_Ios
//
//  Created by Abhiram Kasu on 5/18/25.
//


import Foundation
import Combine

// MARK: - Models

struct Song: Codable, Identifiable {
    let spotifyId: String
    let title: String
    let artist: String
    let coverPhotoUrl: String
    var votes: Int
    
    var id: String { spotifyId }
}

struct PartyState: Codable {
    let id: String?
    let title: String?
    let description: String?
    var songQueue: [Song]
    var currentSong: Song?
    var currentDuration: Int
    var playing: Bool
    
    init(id: String? = nil, title: String? = nil, description: String? = nil, songQueue: [Song] = [], currentSong: Song? = nil, currentDuration: Int = 0, playing: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.songQueue = songQueue
        self.currentSong = currentSong
        self.currentDuration = currentDuration
        self.playing = playing
    }
}



struct PartyUpdate: Codable {
    let type: UpdateType
    let partyId: String
    let payload: AnyCodable
}

// MARK: - Authentication Models

struct CreatePartyRequest: Codable {
    let username: String
    let partyName: String
}

struct JoinPartyRequest: Codable {
    let partyCode: String
    let username: String
}

struct AuthResponse: Codable {
    let token: String
    let partyCode: String?
}

// MARK: - AnyCodable (for handling dynamic payload types)

struct AnyCodable: Codable {
    private let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else if let song = try? container.decode(Song.self) {
            self.value = song
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self.value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let song as Song:
            try container.encode(song)
        default:
            throw EncodingError.invalidValue(self.value, EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable cannot encode value"
            ))
        }
    }
    
    func unwrapSong() -> Song? {
        return value as? Song
    }
    
    func unwrapBool() -> Bool? {
        return value as? Bool
    }
    
    func unwrapInt() -> Int? {
        return value as? Int
    }
}

// MARK: - SSE Event Handling

enum SSEEvent {
    case initialState(PartyState)
    case songVoteUpdate(Song)
    case songQueueAddition(Song)
    case currentSongUpdate(Song)
    case playbackStatusUpdate(Bool)
    case durationUpdate(Int)
    case error(Error)
}

// MARK: - HTTP Client



// MARK: - SSE Notification Extension

extension Notification.Name {
    static let sseDataReceived = Notification.Name("SSEDataReceived")
}
