//
//  InitialView.swift
//  CrowdCue_Frontend_Ios
//
//  Created by Abhiram Kasu on 5/14/25.
//

import Foundation
import SwiftUI
import SpotifyiOS


struct InitialView: View {
    let onCreateParty : (String, String) -> Void
    
    @Environment(\.colorScheme) private var colorScheme : ColorScheme
    
    @State private var showSpotifyFailedToast = false
    let spotifyGreen: Color = Color(red: 29/255.0, green: 185/255.0, blue: 84/255.0)
    let spotifyBlack: Color = Color(red: 25/255.0, green: 20/255.0, blue: 20/255.0)
    let errorColor: Color = Color(red: 0.9, green: 0.1, blue: 0.1)
    
    @EnvironmentObject var spotifyManager: SpotifyManager
    
    @State private var isPresentingCreatePartySheet = false
    
    @State private var partyName: String = ""
    @State private var username: String = ""
    
    private func showSpotifyFailedToastMessage(for seconds: Double) {
        withAnimation {
            showSpotifyFailedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            withAnimation {
                showSpotifyFailedToast = false
            }
        }
    }
    
    private func openCreatePartySheet() {
        isPresentingCreatePartySheet = true
    }
    
    var body: some View {
        ZStack {
            VStack {
                Text("Crowd Cue").fontWeight(.bold).font(.system(size: 30))
                Spacer()
                
                VStack(spacing: 20) {
                    Button(action: {
                        openCreatePartySheet()
                    }) {
                        Text("Create Party")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(colorScheme == ColorScheme.dark ? .black : .white)
                            .background(colorScheme == ColorScheme.dark ? .white: .black)
                            .cornerRadius(10)
                            .fontWeight(.bold)
                    }
                    .disabled(!spotifyManager.isConnectedToSpotify)
                    
                    Button(action: {
                        spotifyManager.connect { succ in
                            if !succ {
                                showSpotifyFailedToastMessage(for: 2)
                            }
                        }
                    }) {
                        Text("Link Spotify")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(spotifyBlack)
                            .foregroundColor(spotifyGreen)
                            .cornerRadius(10)
                            .fontWeight(.bold)
                    }
                }
                .padding(.bottom, 30.0)
            }
            
           
            
            ZStack {
                if showSpotifyFailedToast {
                    toastView()
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            )
                        )
                }
            }
            .animation(.easeInOut(duration: 0.4), value: showSpotifyFailedToast)
        }
        .padding(.all, 10)
        .sheet(isPresented: $isPresentingCreatePartySheet, onDismiss: {
            
            guard !partyName.isEmpty && !username.isEmpty else { return }
            
            
                
                onCreateParty(partyName, username)
            
        }) {
            CreatePartySheet(partyName: $partyName, username: $username, isPresented: $isPresentingCreatePartySheet)
        }
        
    }
    
    @ViewBuilder
    private func toastView() -> some View {
        VStack {
            Spacer()
            Text("Failed to Link Spotify")
                .padding()
                .background(.ultraThinMaterial)
                .foregroundColor(.black)
                .fontWeight(.bold)
                .cornerRadius(12)
                .padding(.bottom, 40)
        }
    }
}
struct CreatePartySheet: View {
    @Binding var partyName: String
    @Binding var username: String
    @Binding var isPresented: Bool

    @State private var inputName: String = ""
    @State private var inputUsername: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Party Details")) {
                    TextField("Party Name", text: $inputName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Username", text: $inputUsername)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    HStack {
                        Button("Cancel") {
                            isPresented = false
                        }
                        Spacer()
                        Button("Create") {
                            partyName = inputName
                            username = inputUsername
                            isPresented = false
                        }
                        .disabled(inputName.isEmpty || inputUsername.isEmpty)
                    }
                }
            }
            .navigationTitle("Create Party")
            .onAppear {
                // seed the inputs if you want to edit existing values
                inputName = partyName
                inputUsername = username
            }
        }
    }
}
#Preview {
    //InitialView().environmentObject(SpotifyManager.shared)
}
