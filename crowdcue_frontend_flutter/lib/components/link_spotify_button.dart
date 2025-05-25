import 'package:crowdcue_frontend_flutter/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LinkSpotifyButton extends StatelessWidget {
  const LinkSpotifyButton({super.key, required this.onPressed});

  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).brightness == Brightness.dark
        ? spotifyBlack
        : spotifyGreen;
    final bg = Theme.of(context).brightness == Brightness.dark
        ? spotifyGreen
        : spotifyBlack;

    return ElevatedButton.icon(
      onPressed: onPressed,

      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        shadowColor: bg,
        elevation: 10,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        padding: const EdgeInsets.symmetric(vertical: 20),
      ),
      label: Text("Link Spotify"),
      icon: Icon(FontAwesomeIcons.spotify, color: fg, size: 25),
    );
  }
}
