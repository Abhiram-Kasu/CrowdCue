//
//  ContentView.swift
//  CrowdCue_Frontend_Ios
//
//  Created by Abhiram Kasu on 5/14/25.
//

import SwiftUI

// Three screens,
// One for linking with spotify
// One for creation of party
// One for the actual party screen

enum AppRoute: Hashable {
  case party(partyName: String, username: String)
}
struct ContentView: View {
  @State private var path: [AppRoute] = []

  var body: some View {
    NavigationStack(path: $path) {
      // Root is InitialView
        
      InitialView {partyName, username in
          
                             path.append(.party(partyName: partyName, username: username))
                              }
      .environmentObject(SpotifyManager.shared)
      .onOpenURL { url in
        SpotifyManager.shared.handleURL(url)
      }.navigationDestination(for: AppRoute.self) { route in
        switch route {
        case .party(let partyName, let username):
            PartyView(partyName: partyName, username: username).environmentObject(SpotifyManager.shared)
        }
      }
    }
  }
}

#Preview {
    ContentView()
}
