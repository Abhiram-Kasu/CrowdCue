import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// --- Data Models (Placeholders - Define these properly) ---
class AuthResponse {
  final String token;
  final String? partyCode;

  AuthResponse({required this.token, this.partyCode});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(token: json['token'], partyCode: json['partyCode']);
  }
}

class CreatePartyRequest {
  final String username;
  final String partyName;

  CreatePartyRequest({required this.username, required this.partyName});

  Map<String, dynamic> toJson() => {
    'username': username,
    'partyName': partyName,
  };
}

class JoinPartyRequest {
  final String partyCode;
  final String username;

  JoinPartyRequest({required this.partyCode, required this.username});

  Map<String, dynamic> toJson() => {
    'partyCode': partyCode,
    'username': username,
  };
}

class Song {
  final String spotifyId;
  final String title;
  final String artist;
  final String? coverPhotoUrl;
  int votes;
  // final String? id; // If different from spotifyId

  Song({
    required this.spotifyId,
    required this.title,
    required this.artist,
    this.coverPhotoUrl,
    required this.votes,
    // this.id,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      spotifyId: json['spotifyId'],
      title: json['title'],
      artist: json['artist'],
      coverPhotoUrl: json['coverPhotoUrl'],
      votes: json['votes'] ?? 0,
      // id: json['id'],
    );
  }

  Map<String, dynamic> toJson() => {
    'spotifyId': spotifyId,
    'title': title,
    'artist': artist,
    'coverPhotoUrl': coverPhotoUrl,
    'votes': votes,
    // 'id': id,
  };
}

class PartyState {
  List<Song> songQueue;
  Song? currentSong;
  bool playing;
  int currentDuration; // in seconds or milliseconds, clarify

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
      playing: json['playing'] ?? false,
      currentDuration: json['currentDuration'] ?? 0,
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
  return null;
}

class PartyUpdate {
  final PartyUpdateType type;
  final String partyId;
  final dynamic payload; // Can be Song, bool, int

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
    return payload; // For bool, int, etc.
  }

  factory PartyUpdate.fromJson(Map<String, dynamic> json) {
    PartyUpdateType? type = partyUpdateTypeFromString(json['type'] as String?);
    if (type == null) {
      throw ArgumentError('Unknown PartyUpdateType: ${json['type']}');
    }

    dynamic parsedPayload;
    // Based on the Swift code, the payload within PartyUpdate (when received from SSE)
    // is already the specific object (Song, bool, int).
    // The `unwrapSong`, `unwrapBool` etc. in Swift were on `AnyCodable` payload.
    // Here, we assume `json['payload']` is the direct data.
    switch (type) {
      case PartyUpdateType.SONG_VOTE_UPDATE:
      case PartyUpdateType.SONG_QUEUE_ADDITION:
      case PartyUpdateType.CURRENT_SONG_UPDATE:
        parsedPayload = Song.fromJson(json['payload'] as Map<String, dynamic>);
        break;
      case PartyUpdateType.PLAYBACK_STATUS_UPDATE:
        parsedPayload = json['payload'] as bool;
        break;
      case PartyUpdateType.DURATION_UPDATE:
        parsedPayload = json['payload'] as int;
        break;
      default:
        parsedPayload = json['payload'];
    }

    return PartyUpdate(
      type: type,
      partyId: json['partyId'],
      payload: parsedPayload,
    );
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
  final dynamic data; // Can be PartyState, Song, bool, int, or Exception

  SSEEvent(this.type, this.data);
}

// --- CrowdCueHttpClient ---
class CrowdCueHttpClient extends ChangeNotifier {
  // Removed static _instance and instance getter
  // Removed _privateConstructor

  // Public constructor
  CrowdCueHttpClient();

  final String _baseURL = "http://192.168.10.33:8080"; // Ensure this is correct
  String? _authToken;

  // Add username and partyName properties if they are not already there
  // from previous suggestions.
  String? _username;
  String? get username => _username;
  set username(String? value) {
    _username = value;
    notifyListeners();
  }

  String? _partyName;
  String? get partyName => _partyName;
  set partyName(String? value) {
    _partyName = value;
    notifyListeners();
  }

  PartyState _currentPartyState = PartyState.initial();
  PartyState get currentPartyState => _currentPartyState;
  set currentPartyState(PartyState value) {
    _currentPartyState = value;
    notifyListeners();
  }

  bool _isConnected = false;
  bool get isConnected => _isConnected;
  set isConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  set errorMessage(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  String? _currentPartyCode;
  String? get currentPartyCode => _currentPartyCode;
  set currentPartyCode(String? value) {
    _currentPartyCode = value;
    notifyListeners();
  }

  // SSE related
  http.Client? _sseClient;
  StreamSubscription<String>? _sseSubscription;
  StreamController<SSEEvent>? _sseEventsController;

  String _sseEventBuffer = '';
  String _sseCurrentEventName = '';
  List<String> _sseCurrentDataLines = [];

  Future<Map<String, String>> _getHeaders({
    bool includeAuth = true,
    bool isSse = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (includeAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (isSse) {
      headers['Accept'] = 'text/event-stream';
      headers['Cache-Control'] = 'no-cache';
    }
    return headers;
  }

  // MARK: - Auth Methods
  Future<String> createParty({
    required String username,
    required String partyName,
  }) async {
    final url = Uri.parse('$_baseURL/auth/createParty');
    final requestPayload = CreatePartyRequest(
      username: username,
      partyName: partyName,
    );

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(includeAuth: false),
        body: jsonEncode(requestPayload.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        _authToken = authResponse.token;
        currentPartyCode = authResponse.partyCode; // Setter notifies
        this.username = username; // Set instance property, setter notifies
        this.partyName = partyName; // Set instance property, setter notifies
        // No need to call notifyListeners() explicitly here if setters do it.
        return authResponse.partyCode ?? "";
      } else {
        final errorData = jsonDecode(response.body)['message'] ?? response.body;
        throw Exception(
          'Failed to create party (${response.statusCode}): $errorData',
        );
      }
    } catch (e) {
      errorMessage = e.toString(); // Setter notifies
      // Consider rethrowing a more specific error or just the original
      throw Exception('Failed to create party: $e');
    }
  }

  Future<void> joinParty({
    required String partyCode,
    required String username,
  }) async {
    final url = Uri.parse('$_baseURL/auth/joinParty');
    final requestPayload = JoinPartyRequest(
      partyCode: partyCode,
      username: username,
    );

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(includeAuth: false),
        body: jsonEncode(requestPayload.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        _authToken = authResponse.token;
        currentPartyCode = partyCode; // Setter notifies
        this.username = username; // Set instance property, setter notifies
        // partyName is not typically known when joining unless backend sends it
        // No need to call notifyListeners() explicitly here if setters do it.
      } else {
        final errorData = jsonDecode(response.body)['message'] ?? response.body;
        throw Exception(
          'Failed to join party (${response.statusCode}): $errorData',
        );
      }
    } catch (e) {
      errorMessage = e.toString(); // Setter notifies
      throw Exception('Failed to join party: $e');
    }
  }

  // MARK: - SSE Methods
  Stream<SSEEvent> subscribeToParty(String partyCode) {
    if (_authToken == null) {
      throw Exception('Not authenticated');
    }
    if (_sseEventsController != null && !_sseEventsController!.isClosed) {
      // Already subscribed or controller not properly closed
      unsubscribeFromParty(); // Clean up previous one
    }
    _sseEventsController = StreamController<SSEEvent>.broadcast();

    final url = Uri.parse('$_baseURL/realtime/$partyCode');
    _sseClient = http.Client();

    final request = http.Request('GET', url);
    request.headers.addAll({
      'Authorization': 'Bearer $_authToken',
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache', // Important for SSE
    });

    Future<void> connect() async {
      try {
        final streamedResponse = await _sseClient!.send(request);

        if (streamedResponse.statusCode != 200) {
          final body = await streamedResponse.stream.bytesToString();
          _sseEventsController!.addError(
            Exception(
              'SSE connection failed (${streamedResponse.statusCode}): $body',
            ),
          );
          await _closeSseResources();
          return;
        }

        isConnected = true;

        _sseSubscription = streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                _processSseLine(line);
              },
              onError: (error, stackTrace) {
                if (!_sseEventsController!.isClosed) {
                  _sseEventsController!.addError(error, stackTrace);
                }
                _closeSseResources();
              },
              onDone: () {
                _closeSseResources();
              },
              cancelOnError: true,
            );
      } catch (e, s) {
        if (_sseEventsController != null && !_sseEventsController!.isClosed) {
          _sseEventsController!.addError(e, s);
        }
        await _closeSseResources();
      }
    }

    connect();
    return _sseEventsController!.stream;
  }

  void _processSseLine(String line) {
    if (line.isEmpty) {
      // Event terminator
      if (_sseCurrentEventName.isNotEmpty && _sseCurrentDataLines.isNotEmpty) {
        final jsonDataString = _sseCurrentDataLines.join('');
        try {
          // Assuming the 'data:' field contains JSON that needs to be parsed
          final decodedJsonData = jsonDecode(jsonDataString);
          final sseEvent = _parseRawSSEEvent(
            _sseCurrentEventName,
            decodedJsonData,
          );
          if (!_sseEventsController!.isClosed) {
            _sseEventsController!.add(sseEvent);
          }
        } catch (e) {
          if (!_sseEventsController!.isClosed) {
            _sseEventsController!.addError(
              Exception(
                'Failed to parse SSE data for event $_sseCurrentEventName: $e',
              ),
            );
          }
        }
      }
      _sseCurrentEventName = '';
      _sseCurrentDataLines = [];
      return;
    }

    if (line.startsWith('event:')) {
      _sseCurrentEventName = line.substring('event:'.length).trim();
    } else if (line.startsWith('data:')) {
      _sseCurrentDataLines.add(line.substring('data:'.length).trim());
    }
    // id and retry fields are ignored for now
  }

  SSEEvent _parseRawSSEEvent(String eventName, dynamic eventDataJson) {
    // eventDataJson is the decoded content of the 'data:' field from SSE.
    // Based on Swift, for some events, this 'eventDataJson' is a PartyUpdate map,
    // for 'initial-state', it's a PartyState map.
    try {
      switch (eventName) {
        case 'initial-state':
          final state = PartyState.fromJson(
            eventDataJson as Map<String, dynamic>,
          );
          currentPartyState = state; // Setter handles notifyListeners
          return SSEEvent(SSEEventType.initialState, state);

        case 'song_vote_update':
        case 'song_queue_addition':
        case 'current_song_update':
        case 'playback_status_update':
        case 'duration_update':
          // In these cases, eventDataJson is a PartyUpdate object's JSON representation
          final partyUpdate = PartyUpdate.fromJson(
            eventDataJson as Map<String, dynamic>,
          );
          final tempState = PartyState(
            songQueue: List.from(_currentPartyState.songQueue),
            currentSong: _currentPartyState
                .currentSong, // Create copies or handle immutability
            playing: _currentPartyState.playing,
            currentDuration: _currentPartyState.currentDuration,
          );

          SSEEventType eventType;

          switch (partyUpdate.type) {
            case PartyUpdateType.SONG_VOTE_UPDATE:
              eventType = SSEEventType.songVoteUpdate;
              final song = partyUpdate.payload as Song;
              final index = tempState.songQueue.indexWhere(
                (s) => s.spotifyId == song.spotifyId,
              );
              if (index != -1) {
                tempState.songQueue[index].votes = song.votes;
              } else if (tempState.currentSong?.spotifyId == song.spotifyId) {
                tempState.currentSong?.votes = song.votes;
              }
              currentPartyState = tempState;
              return SSEEvent(eventType, song);

            case PartyUpdateType.SONG_QUEUE_ADDITION:
              eventType = SSEEventType.songQueueAddition;
              final song = partyUpdate.payload as Song;
              if (!tempState.songQueue.any(
                (s) => s.spotifyId == song.spotifyId,
              )) {
                // Assuming spotifyId is unique key
                tempState.songQueue.add(song);
              }
              currentPartyState = tempState;
              return SSEEvent(eventType, song);

            case PartyUpdateType.CURRENT_SONG_UPDATE:
              eventType = SSEEventType.currentSongUpdate;
              final song = partyUpdate.payload as Song;
              tempState.currentSong = song;
              tempState.songQueue.removeWhere(
                (s) => s.spotifyId == song.spotifyId,
              );
              currentPartyState = tempState;
              return SSEEvent(eventType, song);

            case PartyUpdateType.PLAYBACK_STATUS_UPDATE:
              eventType = SSEEventType.playbackStatusUpdate;
              final isPlaying = partyUpdate.payload as bool;
              tempState.playing = isPlaying;
              currentPartyState = tempState;
              return SSEEvent(eventType, isPlaying);

            case PartyUpdateType.DURATION_UPDATE:
              eventType = SSEEventType.durationUpdate;
              final duration = partyUpdate.payload as int;
              tempState.currentDuration = duration;
              currentPartyState = tempState;
              return SSEEvent(eventType, duration);
            default:
              return SSEEvent(
                SSEEventType.unknown,
                'Unknown PartyUpdate type: ${partyUpdate.type}',
              );
          }
        default:
          debugPrint('Unknown SSE event type: $eventName');
          return SSEEvent(
            SSEEventType.unknown,
            'Unknown event type: $eventName',
          );
      }
    } catch (e, s) {
      debugPrint('Error parsing SSE event $eventName: $e\n$s');
      return SSEEvent(SSEEventType.error, e);
    }
  }

  Future<void> _closeSseResources() async {
    isConnected = false;
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _sseClient?.close();
    _sseClient = null;
    if (_sseEventsController != null && !_sseEventsController!.isClosed) {
      _sseEventsController!.close();
    }
    _sseEventsController = null;
    _sseEventBuffer = '';
    _sseCurrentEventName = '';
    _sseCurrentDataLines = [];
  }

  void unsubscribeFromParty() {
    _closeSseResources();
    notifyListeners(); // To update isConnected status
  }

  // MARK: - Party Updates
  Future<void> sendPartyUpdate({
    required String partyCode,
    required PartyUpdate update,
  }) async {
    if (_authToken == null) {
      throw Exception('Not authenticated');
    }
    final url = Uri.parse('$_baseURL/realtime/$partyCode/update');

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(update.toJson()),
      );

      if (!(response.statusCode >= 200 && response.statusCode < 300)) {
        final errorData = jsonDecode(response.body)['message'] ?? response.body;
        throw Exception(
          'Failed to send party update (${response.statusCode}): $errorData',
        );
      }
      // Update sent successfully
    } catch (e) {
      errorMessage = e.toString();
      throw Exception('Failed to send party update: $e');
    }
  }

  // Convenience methods for common updates
  Future<void> voteSong({required String partyCode, required Song song}) async {
    // The Swift code implies the backend handles vote increment.
    // We send the song, and backend updates its votes.
    final update = PartyUpdate(
      type: PartyUpdateType.SONG_VOTE_UPDATE,
      partyId: partyCode,
      payload: song,
    ); // Send the song object
    await sendPartyUpdate(partyCode: partyCode, update: update);
  }

  Future<void> addSongToQueue({
    required String partyCode,
    required Song song,
  }) async {
    final update = PartyUpdate(
      type: PartyUpdateType.SONG_QUEUE_ADDITION,
      partyId: partyCode,
      payload: song,
    );
    await sendPartyUpdate(partyCode: partyCode, update: update);
  }

  Future<void> updateCurrentSong({
    required String partyCode,
    required Song song,
  }) async {
    final update = PartyUpdate(
      type: PartyUpdateType.CURRENT_SONG_UPDATE,
      partyId: partyCode,
      payload: song,
    );
    await sendPartyUpdate(partyCode: partyCode, update: update);
  }

  Future<void> updatePlaybackStatus({
    required String partyCode,
    required bool isPlaying,
  }) async {
    final update = PartyUpdate(
      type: PartyUpdateType.PLAYBACK_STATUS_UPDATE,
      partyId: partyCode,
      payload: isPlaying,
    );
    await sendPartyUpdate(partyCode: partyCode, update: update);
  }

  Future<void> updateDuration({
    required String partyCode,
    required int duration,
  }) async {
    final update = PartyUpdate(
      type: PartyUpdateType.DURATION_UPDATE,
      partyId: partyCode,
      payload: duration,
    );
    await sendPartyUpdate(partyCode: partyCode, update: update);
  }

  @override
  void dispose() {
    unsubscribeFromParty();
    super.dispose();
  }
}
