//
//  SpotifyManager.swift
//  CrowdCue_Frontend_Ios
//
//  Created by Abhiram Kasu on 5/14/25.
//

// SpotifyManager.swift

import Foundation
import SpotifyiOS
import UIKit

class SpotifyManager: NSObject, ObservableObject {
    static let shared = SpotifyManager()

    // MARK: – Auth & Connection

    private let clientID = "a48d17d11fe54936b7a6d1a9ca6863f3"
    private let redirectURI = URL(string: "crowdcue://callback")!
    private let playURI = ""

    @Published var isConnectedToSpotify = false

    lazy var configuration: SPTConfiguration = {
        let c = SPTConfiguration(clientID: clientID, redirectURL: redirectURI)
        c.playURI = playURI
        return c
    }()

    lazy var appRemote: SPTAppRemote = {
        let r = SPTAppRemote(configuration: configuration, logLevel: .debug)
        r.delegate = self
        return r
    }()

    private var accessToken: String? {
        didSet { appRemote.connectionParameters.accessToken = accessToken }
    }

    func connect(onComplete: @escaping (Bool) -> Void) {
        appRemote.authorizeAndPlayURI(playURI) { success in
            DispatchQueue.main.async { onComplete(success) }
        }
    }

    func handleURL(_ url: URL) {
        let params = appRemote.authorizationParameters(from: url)
        if let token = params?[SPTAppRemoteAccessTokenKey] {
            accessToken = token
            appRemote.connect()
        }
    }

    // MARK: – Published Playback State

    @Published private(set) var trackName: String = ""
    @Published private(set) var artistName: String = ""
    @Published private(set) var coverImage: UIImage?
    @Published private(set) var isPaused: Bool = true
    
    // MARK: - Current Track Data
    
    // Add a computed property to access the current track
    var currentTrack: CurrentTrack? {
        guard !trackName.isEmpty, !artistName.isEmpty else {
            return nil
        }
        
        return CurrentTrack(
            id: currentTrackId,
            name: trackName,
            artist: artistName
        )
    }
    
    // Track ID from Spotify
    private(set) var currentTrackId: String = ""

    // MARK: – Controls

    func togglePlayPause() {
        guard let api = appRemote.playerAPI else { return }
        if isPaused { api.resume(nil) } else { api.pause(nil) }
    }

    func skipNext() {
        appRemote.playerAPI?.skip(toNext: nil)
    }

    func skipPrevious() {
        appRemote.playerAPI?.skip(toPrevious: nil)
    }
}

// MARK: - Current Track Model

struct CurrentTrack {
    let id: String
    let name: String
    let artist: String
}

// MARK: – SPTAppRemoteDelegate & PlayerState Delegate

extension SpotifyManager: SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    func appRemoteDidEstablishConnection(_ remote: SPTAppRemote) {
        DispatchQueue.main.async { self.isConnectedToSpotify = true }
        remote.playerAPI?.delegate = self
        remote.playerAPI?.subscribe(toPlayerState: { _, error in
            if let e = error { print("Subscription error:", e) }
        })
    }

    func appRemote(_ remote: SPTAppRemote, didDisconnectWithError error: Error?) {
        DispatchQueue.main.async { self.isConnectedToSpotify = false }
    }

    func appRemote(_ remote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        DispatchQueue.main.async { self.isConnectedToSpotify = false }
    }

    func playerStateDidChange(_ state: SPTAppRemotePlayerState) {
        DispatchQueue.main.async {
            self.trackName = state.track.name
            self.artistName = state.track.artist.name
            self.isPaused = state.isPaused
            self.currentTrackId = state.track.uri.split(separator: ":").last.map(String.init) ?? ""
        }
        // fetch cover
        appRemote.imageAPI?.fetchImage(
            forItem: state.track,
            with: CGSize(width: 300, height: 300)
        ) { image, error in
            if let img = image as? UIImage {
                DispatchQueue.main.async { self.coverImage = img }
            }
        }
    }
}
