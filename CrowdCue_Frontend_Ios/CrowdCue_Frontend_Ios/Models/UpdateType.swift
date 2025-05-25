//
//  UpdateType.swift
//  CrowdCue_Frontend_Ios
//
//  Created by Abhiram Kasu on 5/18/25.
//


import Foundation
import Combine

enum UpdateType: String, Codable {
    case SONG_VOTE_UPDATE
    case SONG_QUEUE_ADDITION
    case CURRENT_SONG_UPDATE
    case PLAYBACK_STATUS_UPDATE
    case DURATION_UPDATE
}