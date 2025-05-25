import 'dart:async';

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/models/track.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

class CurrentTrack {
  final String id;
  final String name;
  final String artist;

  CurrentTrack({required this.id, required this.name, required this.artist});
}

final SpotifyService spotifyServiceInstance = SpotifyService();

class SpotifyService extends ChangeNotifier {
  factory SpotifyService() => _instance;

  static final SpotifyService _instance = SpotifyService._internal();
  SpotifyService._internal() {
    // Any initialization code goes here
    print("SpotifyService singleton created: ${identityHashCode(this)}");
  }

  static const String _clientId =
      "a48d17d11fe54936b7a6d1a9ca6863f3"; // Your Spotify Client ID
  static const String _redirectUrl = "crowdcue://callback"; // Your Redirect URI

  // --- State ---
  bool _isConnectedToSpotify = false;
  bool get isConnectedToSpotify => _isConnectedToSpotify;

  String _trackName = "";
  String get trackName => _trackName;

  String _artistName = "";
  String get artistName => _artistName;

  Image? _coverImage;
  Image? get coverImage => _coverImage;

  bool _isPaused = true;
  bool get isPaused => _isPaused;

  String _currentTrackId = "";
  String get currentTrackId => _currentTrackId;

  PlayerState? _playerState;
  PlayerState? get playerState => _playerState;

  CurrentTrack? get currentTrack {
    if (_trackName.isEmpty || _artistName.isEmpty || _currentTrackId.isEmpty) {
      return null;
    }
    return CurrentTrack(
      id: _currentTrackId,
      name: _trackName,
      artist: _artistName,
    );
  }

  String? _accessToken;
  String? get accessToken => _accessToken;

  StreamSubscription<PlayerState>? _playerStateSubscription;

  int _progressMs = 0;
  int get progressMs => _progressMs;

  Timer? timeTicker;

  Timer genTimer() => Timer.periodic(Duration(seconds: 1), (timer) {
    if (_playerState != null && _playerState!.track != null) {
      print("Updating progress: $_progressMs ms");
      _progressMs += 1000; // Increment progress by 1 second
      notifyListeners(); // Notify listeners about the progress update
    }
  });

  double get progrsssPercentage {
    if (_playerState == null || _playerState!.track == null) return 0.0;
    final durationMs = _playerState!.track!.duration;

    if (durationMs <= 0) return 0.0; // Avoid division by zero
    return _progressMs / durationMs;
  }

  // --- Connection & Authentication ---
  Future<bool> connect() async {
    try {
      _accessToken = await SpotifySdk.getAccessToken(
        clientId: _clientId,
        redirectUrl: _redirectUrl,
        scope:
            'app-remote-control, '
            'user-read-playback-state, '
            'user-modify-playback-state, '
            'playlist-read-private, '
            'playlist-read-collaborative, '
            'user-library-read, '
            'user-read-email, '
            'user-read-private', // Add scopes as needed
      );

      if (_accessToken != null && _accessToken!.isNotEmpty) {
        // The spotify_sdk's getAccessToken handles the connection implicitly
        // if it successfully retrieves a token.
        // For more explicit connection management if needed by the SDK version:
        // bool result = await SpotifySdk.connectToSpotifyRemote(clientId: _clientId, redirectUrl: _redirectUrl);
        // if (result) {
        //   _isConnectedToSpotify = true;
        // } else {
        //   _isConnectedToSpotify = false;
        //   _accessToken = null; // Clear token if connection failed
        // }
        // For current versions, getting a token usually means you are "connected" for API calls.
        // The concept of a persistent "connection" like SPTAppRemote is slightly different.
        // We'll use the player state subscription to confirm active playback control.

        _isConnectedToSpotify = true; // Assume connected if token is received
        _subscribeToPlayerState();
        notifyListeners();
        return true;
      }
    } catch (e) {
      print("Spotify connection/auth error: $e");
      _isConnectedToSpotify = false;
      _accessToken = null;
      notifyListeners();
    }
    return false;
  }

  Future<void> disconnect() async {
    try {
      await SpotifySdk.disconnect();
    } catch (e) {
      print("Spotify disconnect error: $e");
    }
    _isConnectedToSpotify = false;
    _playerStateSubscription?.cancel();
    _clearPlayerState();
    notifyListeners();
  }

  void _clearPlayerState() {
    print("Clearing player state");
    _trackName = "";
    _artistName = "";
    _coverImage = null;
    _isPaused = true;
    _currentTrackId = "";
  }

  // --- Player State ---
  void _subscribeToPlayerState() {
    _playerStateSubscription?.cancel(); // Cancel any existing subscription
    _playerStateSubscription = SpotifySdk.subscribePlayerState().listen(
      (PlayerState playerState) async {
        _trackName = playerState.track?.name ?? "";
        _artistName = playerState.track?.artist.name ?? "";
        _isPaused = playerState.isPaused;
        _currentTrackId = playerState.track?.uri.split(':').last ?? "";

        _playerState = playerState; // Update the player state

        _progressMs = playerState.playbackPosition;

        // Updae timer if needed
        if (playerState.isPaused) {
          timeTicker?.cancel();
        } else {
          //make sure that timer is running by deleting the old one and restarting it after updating the progress
          timeTicker?.cancel();
          timeTicker = genTimer();
          _progressMs = playerState.playbackPosition;
        }

        assert(spotifyServiceInstance._trackName == _trackName);
        assert(spotifyServiceInstance._artistName == _artistName);
        assert(spotifyServiceInstance._isPaused == _isPaused);
        assert(spotifyServiceInstance._currentTrackId == _currentTrackId);
        print("assertions passed");

        print(
          "Player State Updated: "
          "Track: $_trackName, "
          "Artist: $_artistName, "
          "Paused: $_isPaused, "
          "Track ID: $_currentTrackId",
        );

        try {
          if (playerState.track != null) {
            print("fetching cover image for track: ${playerState.track!.name}");
            await _fetchCoverImage(playerState.track!);
          } else {
            _coverImage = null;
          }
          // If we get a player state, we can be more certain about the "connection"
          if (!_isConnectedToSpotify && playerState.track != null) {
            _isConnectedToSpotify = true;
          }
        } finally {
          print("notifying listeners");
          notifyListeners();
        }
      },
      onError: (error) {
        print("PlayerState Subscription Error: $error");
        _isConnectedToSpotify = false; // Potentially disconnected
        _clearPlayerState();
        notifyListeners();
      },
    );
  }

  Future<void> _fetchCoverImage(Track track) async {
    try {
      Uint8List? imageData = await SpotifySdk.getImage(
        imageUri: track.imageUri,
        dimension: ImageDimension.large, // Or other sizes
      );
      if (imageData != null) {
        print("Cover image fetched for track: ${track.name}");
        _coverImage = Image.memory(imageData);
      } else {
        print("No cover image data found for track: ${track.name}");
        _coverImage = null;
      }
      notifyListeners();
    } catch (e) {
      print("Error fetching cover image: $e");
      _coverImage = null;
      notifyListeners();
    }
  }

  // --- Controls ---
  Future<void> togglePlayPause() async {
    if (!_isConnectedToSpotify) return;
    try {
      if (_isPaused) {
        await SpotifySdk.resume();
      } else {
        await SpotifySdk.pause();
      }
    } catch (e) {
      print("Error toggling play/pause: $e");
    }
  }

  Future<void> skipNext() async {
    if (!_isConnectedToSpotify) return;
    try {
      await SpotifySdk.skipNext();
    } catch (e) {
      print("Error skipping next: $e");
    }
  }

  Future<void> skipPrevious() async {
    if (!_isConnectedToSpotify) return;
    try {
      await SpotifySdk.skipPrevious();
    } catch (e) {
      print("Error skipping previous: $e");
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    timeTicker?.cancel();
    super.dispose();
  }
}
