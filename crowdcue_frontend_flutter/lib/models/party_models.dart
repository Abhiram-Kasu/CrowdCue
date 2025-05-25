// filepath: lib/models/party_models.dart
import 'package:flutter/foundation.dart';

class Song {
  final String spotifyId;
  final String title;
  final String artist;
  final String? coverPhotoUrl;
  int votes;

  Song({
    required this.spotifyId,
    required this.title,
    required this.artist,
    this.coverPhotoUrl,
    required this.votes,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      spotifyId: json['spotifyId'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
      votes: json['votes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'spotifyId': spotifyId,
    'title': title,
    'artist': artist,
    'coverPhotoUrl': coverPhotoUrl,
    'votes': votes,
  };
}

class PartyState {
  List<Song> songQueue;
  Song? currentSong;
  bool playing;
  int currentDuration;

  PartyState({
    this.songQueue = const [],
    this.currentSong,
    this.playing = false,
    this.currentDuration = 0,
  });

  factory PartyState.initial() => PartyState();

  factory PartyState.fromJson(Map<String, dynamic> json) {
    return PartyState(
      songQueue:
          (json['songQueue'] as List<dynamic>?)
              ?.map((item) => Song.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      currentSong: json['currentSong'] != null
          ? Song.fromJson(json['currentSong'] as Map<String, dynamic>)
          : null,
      playing: json['playing'] as bool? ?? false,
      currentDuration: json['currentDuration'] as int? ?? 0,
    );
  }
}

enum PartyUpdateType {
  SONG_VOTE_UPDATE,
  SONG_QUEUE_ADDITION,
  CURRENT_SONG_UPDATE,
  PLAYBACK_STATUS_UPDATE,
  DURATION_UPDATE,
}

String partyUpdateTypeToString(PartyUpdateType type) {
  switch (type) {
    case PartyUpdateType.SONG_VOTE_UPDATE:
      return 'song_vote_update';
    case PartyUpdateType.SONG_QUEUE_ADDITION:
      return 'song_queue_addition';
    case PartyUpdateType.CURRENT_SONG_UPDATE:
      return 'current_song_update';
    case PartyUpdateType.PLAYBACK_STATUS_UPDATE:
      return 'playback_status_update';
    case PartyUpdateType.DURATION_UPDATE:
      return 'duration_update';
  }
}

PartyUpdateType? partyUpdateTypeFromString(String? typeString) {
  if (typeString == null) return null;
  for (PartyUpdateType type in PartyUpdateType.values) {
    if (partyUpdateTypeToString(type) == typeString) {
      return type;
    }
  }
  debugPrint('Unknown PartyUpdateType string: $typeString');
  return null;
}

class PartyUpdate {
  final PartyUpdateType type;
  final String partyId;
  final dynamic payload;

  PartyUpdate({
    required this.type,
    required this.partyId,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
    'type': partyUpdateTypeToString(type),
    'partyId': partyId,
    'payload': _payloadToJson(payload),
  };

  static dynamic _payloadToJson(dynamic payload) {
    if (payload is Song) {
      return payload.toJson();
    }
    return payload;
  }
}

enum SSEEventType {
  initialState,
  songVoteUpdate,
  songQueueAddition,
  currentSongUpdate,
  playbackStatusUpdate,
  durationUpdate,
  error,
  unknown,
}

class SSEEvent {
  final SSEEventType type;
  final dynamic data;

  SSEEvent(this.type, this.data);
}
