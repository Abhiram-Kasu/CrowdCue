import 'dart:async';
import 'dart:ui';

import 'package:crowdcue_frontend_flutter/components/code_copy_button.dart';
import 'package:crowdcue_frontend_flutter/services/spotify_service.dart';
import 'package:flutter/material.dart';
import 'package:crowdcue_frontend_flutter/remote/remote.dart'; // Adjust import path

class PartyPage extends StatefulWidget {
  static const String routeName = '/party'; // Example route name
  final CrowdCueHttpClient httpClient;

  const PartyPage({super.key, required this.httpClient});

  @override
  State<PartyPage> createState() => _PartyPageState();
}

class _PartyPageState extends State<PartyPage> {
  StreamSubscription<SSEEvent>? _sseSubscription;

  @override
  void initState() {
    super.initState();
    // Access properties from the passed httpClient instance
    print("Party Code: ${widget.httpClient.currentPartyCode}");
    print("Party Name: ${widget.httpClient.partyName}");
    print("Username: ${widget.httpClient.username}");

    _subscribeToRemoteEvents();
    _subscribeToSpotifyEvents();

    // Listen to changes in the httpClient if needed (e.g., for party state updates)
    widget.httpClient.addListener(_onHttpClientChanged);
  }

  void _onHttpClientChanged() {
    // React to changes in widget.httpClient.currentPartyState, etc.
    if (mounted) {
      setState(() {
        // For example, if you want to rebuild when party state changes
      });
    }
  }

  PartyState get _currentPartyState => widget.httpClient.currentPartyState;

  void _subscribeToRemoteEvents() {
    print("Subscribing to remote events");
    if (widget.httpClient.currentPartyCode != null) {
      _sseSubscription = widget.httpClient
          .subscribeToParty(widget.httpClient.currentPartyCode!)
          .listen(
            (event) {
              // Handle SSEEvent
              if (mounted) {
                switch (event.type) {
                  case SSEEventType.initialState:
                    widget.httpClient.currentPartyState =
                        event.data as PartyState;
                    break;
                  case SSEEventType.songQueueAddition:
                    final newSong = event.data as Song;
                    if (!widget.httpClient.currentPartyState.songQueue.any(
                      (s) => s.spotifyId == newSong.spotifyId,
                    )) {
                      widget.httpClient.currentPartyState.songQueue.add(
                        newSong,
                      );
                    }
                    break;
                  case SSEEventType.songVoteUpdate:
                    final updatedSong = event.data as Song;
                    final songInQueue = widget
                        .httpClient
                        .currentPartyState
                        .songQueue
                        .firstWhere(
                          (s) => s.spotifyId == updatedSong.spotifyId,
                          orElse: () => Song(
                            spotifyId: '',
                            title: '',
                            artist: '',
                            votes: 0,
                          ),
                        );

                    if (songInQueue.spotifyId.isNotEmpty) {
                      songInQueue.votes = updatedSong.votes;
                    } else if (widget
                            .httpClient
                            .currentPartyState
                            .currentSong
                            ?.spotifyId ==
                        updatedSong.spotifyId) {
                      widget.httpClient.currentPartyState.currentSong?.votes =
                          updatedSong.votes;
                    }
                    break;
                  default:
                    break;
                }

                setState(() {});
              }
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('SSE Error: ${error.toString()}')),
                );
              }
            },
          );
    }
  }

  @override
  void dispose() {
    widget.httpClient.removeListener(_onHttpClientChanged);
    _sseSubscription?.cancel();

    widget.httpClient.dispose();
    spotifyServiceInstance.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Party information at the top
                Column(
                  children: [
                    Text(
                      widget.httpClient.partyName ?? "Unknown",
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    CodeCopyButton(
                      code: widget.httpClient.currentPartyCode ?? "",
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Horizontal Music Player (iOS Control Center style)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image:
                          spotifyServiceInstance.coverImage?.image ??
                          Image.network(
                            "https://w0.peakpx.com/wallpaper/757/661/HD-wallpaper-black-screen-plain-noir-dark.jpg",
                          ).image,
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.6)
                              : Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            // Horizontal layout: Album cover + Song info + Controls
                            Row(
                              children: [
                                // Album cover (small, unblurred)
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image:
                                          spotifyServiceInstance
                                              .coverImage
                                              ?.image ??
                                          Image.network(
                                            "https://w0.peakpx.com/wallpaper/757/661/HD-wallpaper-black-screen-plain-noir-dark.jpg",
                                          ).image,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Song info (title and artist)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        spotifyServiceInstance
                                                .currentTrack
                                                ?.name ??
                                            'No Track Playing',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        spotifyServiceInstance
                                                .currentTrack
                                                ?.artist ??
                                            'Unknown Artist',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w400,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                // Music controls
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Previous button
                                    IconButton(
                                      onPressed: () => _skipPrevious(),
                                      icon: const Icon(
                                        Icons.skip_previous,
                                        size: 28,
                                      ),
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      padding: const EdgeInsets.all(8),
                                    ),

                                    // Play/Pause button
                                    IconButton(
                                      onPressed: () => _togglePlayPause(),
                                      icon: Icon(
                                        !spotifyServiceInstance.isPaused
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        size: 24,
                                      ),
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      padding: const EdgeInsets.all(8),
                                    ),

                                    // Next button
                                    IconButton(
                                      onPressed: () => _skipNext(),
                                      icon: const Icon(
                                        Icons.skip_next,
                                        size: 28,
                                      ),
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Progress bar with time labels
                            _buildProgressBar(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Song Queue Section
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey[850]
                        : const Color.fromARGB(255, 226, 226, 226),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Queue',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // Queue items
                        if (_currentPartyState.songQueue.isEmpty)
                          Container(
                            height: 100,
                            child: const Center(
                              child: Text(
                                'No songs in queue',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        else
                          ...List.generate(
                            _currentPartyState.songQueue.length,
                            (index) {
                              final song = _currentPartyState.songQueue[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.grey[800]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            song.artist,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${song.votes}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _subscribeToSpotifyEvents() {
    print("spt hash: ${identityHashCode(spotifyServiceInstance)}");
    print("Subscribing to Spotify events");
    spotifyServiceInstance.addListener(_rebuild);
    final res = spotifyServiceInstance == spotifyServiceInstance;
    print("Spotify service instance check: $res");
    Future.microtask(() => _rebuild());
  }

  void _rebuild() {
    print(
      "Rebuilding PartyPage due to Spotify event. New cover image: ${spotifyServiceInstance.coverImage != null}",
    );
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildProgressBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final currentPosition = spotifyServiceInstance.progressMs ?? 0;
    final totalDuration =
        spotifyServiceInstance.playerState?.track?.duration ?? 100;

    return Column(
      children: [
        LinearProgressIndicator(
          value: spotifyServiceInstance.progrsssPercentage,
          backgroundColor: Colors.white.withOpacity(0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          minHeight: 3,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(currentPosition),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _formatDuration(totalDuration),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _togglePlayPause() {
    spotifyServiceInstance.togglePlayPause();
  }

  void _skipPrevious() {
    spotifyServiceInstance.skipPrevious();
  }

  void _skipNext() {
    spotifyServiceInstance.skipNext();
  }
}
