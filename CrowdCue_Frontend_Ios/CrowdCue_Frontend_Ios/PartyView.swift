//
//  PartyView.swift
//  CrowdCue_Frontend_Ios
//
//  Created by Abhiram Kasu on 5/15/25.
//

import SwiftUI
import SpotifyiOS
import Foundation
import Combine

// 1) A simple UIViewRepresentable for a customizable blur:
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

@MainActor // ViewModel interacts with UI, so good to be on MainActor
final class PartyViewModel: ObservableObject {
    private let httpClient = CrowdCueHttpClient()
    // private var cancellables = Set<AnyCancellable>() // No longer needed
    private var partyEventsTask: Task<Void, Never>? // Task for SSE stream

    @Published var partyState: PartyState = PartyState()
    @Published var isConnected = false // Reflects SSE connection status
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var partyCode: String = ""
    @Published var shouldNavigateBack = false
    @Published var codeCopied = false
    
    var isAuthenticated: Bool { // This can now check httpClient's currentPartyCode directly
        return httpClient.currentPartyCode != nil
    }
    
    // MARK: - Party Creation
    
    func createParty(username: String, partyName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let receivedPartyCode = try await httpClient.createParty(username: username, partyName: partyName)
            self.partyCode = receivedPartyCode
            self.isLoading = false // Set before starting SSE subscription
            await subscribeToPartyUpdates(partyCode: receivedPartyCode)
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            // Consider a brief delay before navigating back to allow user to see error
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.shouldNavigateBack = true
            }
        }
    }
    
    func copyCodeToClipboard() {
        UIPasteboard.general.string = partyCode
        codeCopied = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.codeCopied = false
        }
    }
    
    func joinParty(partyCode: String, username: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await httpClient.joinParty(partyCode: partyCode, username: username)
            self.partyCode = partyCode // httpClient.currentPartyCode is set
            self.isLoading = false
            await subscribeToPartyUpdates(partyCode: partyCode)
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.shouldNavigateBack = true
            }
        }
    }
    
    // MARK: - Party Updates
    
    private func subscribeToPartyUpdates(partyCode: String) async {
        partyEventsTask?.cancel() // Cancel any existing task

        partyEventsTask = Task { // Task runs on a background thread by default
            do {
                let stream = httpClient.subscribeToParty(partyCode: partyCode)
                for try await event in stream {
                    // Process events on the MainActor as they update @Published properties
                    await MainActor.run {
                        self.handleSSEEvent(event)
                    }
                }
            } catch {
                // Handle stream errors (e.g., connection lost)
                await MainActor.run {
                    self.errorMessage = "Party connection lost: \(error.localizedDescription)"
                    self.isConnected = false // Update connection status
                    // Optionally navigate back if connection is critical
                    // DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    //     self.shouldNavigateBack = true
                    // }
                }
            }
        }
    }

    private func handleSSEEvent(_ event: SSEEvent) {
        // This method is already called on MainActor from subscribeToPartyUpdates
        // httpClient.currentPartyState is the source of truth, updated by httpClient itself on MainActor
        
        switch event {
        case .initialState(let state):
            self.partyState = state // Or self.partyState = httpClient.currentPartyState
            self.isConnected = true // httpClient.isConnected should also be true
        case .songVoteUpdate, .songQueueAddition:
            // These events modify arrays within partyState.
            // Re-assigning from httpClient.currentPartyState ensures SwiftUI sees the change.
            self.partyState = httpClient.currentPartyState
        case .currentSongUpdate(let song):
            self.partyState.currentSong = song // Or httpClient.currentPartyState.currentSong
        case .playbackStatusUpdate(let isPlaying):
            self.partyState.playing = isPlaying // Or httpClient.currentPartyState.playing
        case .durationUpdate(let duration):
            self.partyState.currentDuration = duration // Or httpClient.currentPartyState.currentDuration
        case .error(let error): // Error during parsing a specific event
            self.errorMessage = "Party event error: \(error.localizedDescription)"
            // isConnected status is more tied to the stream's health
        }
        // Reflect httpClient's connection status
        self.isConnected = httpClient.isConnected
    }
    
    func disconnect() {
        partyEventsTask?.cancel()
        partyEventsTask = nil
        httpClient.unsubscribeFromParty() // This will terminate the stream and update httpClient.isConnected
        self.isConnected = false // Explicitly set here too
    }
    
    // MARK: - User Actions (now async)
    
    func voteSong(_ song: Song) async {
        guard let currentPartyCode = httpClient.currentPartyCode else {
            errorMessage = "No active party"
            return
        }
        do {
            try await httpClient.voteSong(partyCode: currentPartyCode, song: song)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func addSongToQueue(_ song: Song) async {
        guard let currentPartyCode = httpClient.currentPartyCode else {
            errorMessage = "No active party"
            return
        }
        do {
            try await httpClient.addSongToQueue(partyCode: currentPartyCode, song: song)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func updateCurrentSong(_ song: Song) async {
        guard let currentPartyCode = httpClient.currentPartyCode else {
            errorMessage = "No active party"
            return
        }
        do {
            try await httpClient.updateCurrentSong(partyCode: currentPartyCode, song: song)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func updatePlaybackStatus(isPlaying: Bool) async {
        guard let currentPartyCode = httpClient.currentPartyCode else {
            errorMessage = "No active party"
            return
        }
        do {
            try await httpClient.updatePlaybackStatus(partyCode: currentPartyCode, isPlaying: isPlaying)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func updateDuration(duration: Int) async {
        guard let currentPartyCode = httpClient.currentPartyCode else {
            errorMessage = "No active party"
            return
        }
        do {
            try await httpClient.updateDuration(partyCode: currentPartyCode, duration: duration)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

struct PartyView: View {
    let partyName: String
    let username: String
    let blurRadius: CGFloat = 5
    let cardWidth: CGFloat = 300
    let cardHeight: CGFloat = 180
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @Environment(\.colorScheme) private var colorScheme
    
    @StateObject private var partyViewModel: PartyViewModel = .init()
    
    private var possessiveUsername: String {
        username.hasSuffix("s") ? "\(username)'" : "\(username)'s"
    }
    
    var body: some View {
        VStack {
            // Title + party code
            VStack(spacing: 12) {
                Text("\(possessiveUsername) \(partyName)")
                    .font(.title2).bold()
                
                if !partyViewModel.partyCode.isEmpty {
                    Button(action: {
                        partyViewModel.copyCodeToClipboard() // This is not async, so no Task needed
                    }) {
                        HStack {
                            Text("Party Code: \(partyViewModel.partyCode)")
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                            
                            if partyViewModel.codeCopied {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                                    .transition(.opacity)
                            } else {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(colorScheme == .dark ? Color.white : Color.black)
                        .cornerRadius(8)
                    }
                    .animation(.easeInOut(duration: 0.2), value: partyViewModel.codeCopied)
                }
            }
            .padding(.top, 16)
            
            // Fixed‐size "player card"
            ZStack {
                // 2) Background album art fills entire card:
                if let img = spotifyManager.coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: cardHeight)
                        .blur(radius: blurRadius)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Color.gray.opacity(0.3)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                Color(.systemBackground)
                    .opacity(0.4)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // 4) Foreground content
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // small art thumbnail
                        if let img = spotifyManager.coverImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        // track + artist
                        VStack(alignment: .leading, spacing: 4) {
                            Text(spotifyManager.trackName)
                                .font(.headline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(spotifyManager.artistName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    // controls row
                    HStack(spacing: 40) {
                        Button {
                            spotifyManager.skipPrevious()
                        } label: {
                            Image(systemName: "backward.fill")
                                .renderingMode(.template)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                        
                        Button {
                            spotifyManager.togglePlayPause()
                            Task { // Update playback status in the party
                                await partyViewModel.updatePlaybackStatus(isPlaying: !spotifyManager.isPaused)
                            }
                        } label: {
                            Image(systemName: spotifyManager.isPaused ? "play.fill" : "pause.fill")
                                .renderingMode(.template)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                        
                        Button {
                            spotifyManager.skipNext()
                        } label: {
                            Image(systemName: "forward.fill")
                                .renderingMode(.template)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                    }
                    .font(.title2)
                }
                .padding()
                .frame(width: cardWidth, height: cardHeight, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(width: cardWidth, height: cardHeight)
            .padding(.top, 8)
            
            if partyViewModel.isLoading {
                Spacer()
                ProgressView("Creating party...")
                Spacer()
            } else if !partyViewModel.partyState.songQueue.isEmpty {
                Text("Song Queue")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                
                List {
                    ForEach(partyViewModel.partyState.songQueue) { song in
                        SongRow(song: song) {
                            Task { // Wrap async call in Task
                                await partyViewModel.voteSong(song)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            } else {
                Spacer()
                Text("No songs in queue")
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            Task { // Create party when view appears
                await partyViewModel.createParty(username: username, partyName: partyName)
            }
            
            // Re-subscribe if needed
            if spotifyManager.appRemote.isConnected {
                spotifyManager.appRemote.playerAPI?.delegate = spotifyManager
                spotifyManager.appRemote.playerAPI?.subscribe(toPlayerState: nil)
            }
            
            // Update current song info to the party when Spotify state changes
            if let currentTrack = spotifyManager.currentTrack {
                let song = Song(
                    spotifyId: currentTrack.id,
                    title: currentTrack.name,
                    artist: currentTrack.artist,
                    coverPhotoUrl: "", // You'd need to get this from Spotify
                    votes: 0
                )
                Task { // Wrap async calls in Task
                    await partyViewModel.updateCurrentSong(song)
                    await partyViewModel.updatePlaybackStatus(isPlaying: !spotifyManager.isPaused)
                }
            }
        }
        .onDisappear {
            partyViewModel.disconnect() // This is not async, so no Task needed
        }
        .alert(isPresented: Binding<Bool>(
            get: { partyViewModel.errorMessage != nil },
            set: { if !$0 { partyViewModel.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(partyViewModel.errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
        // Updated onChange modifier
        .onChange(of: partyViewModel.shouldNavigateBack) { oldValue, newValue in
            if newValue { // Use newValue to check the new state
                self.presentationMode.wrappedValue.dismiss()
                // Optionally reset shouldNavigateBack if needed, though dismissing might make it irrelevant
                // partyViewModel.shouldNavigateBack = false
            }
        }
    }
}

struct SongRow: View {
    let song: Song
    let onVote: () -> Void // onVote itself is synchronous, the Task is in PartyView
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onVote) { // onVote is called synchronously here
                HStack {
                    Text("\(song.votes)")
                    Image(systemName: "hand.thumbsup")
                }
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.vertical, 8)
    }
}
