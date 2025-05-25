import 'package:crowdcue_frontend_flutter/components/link_spotify_button.dart';
import 'package:crowdcue_frontend_flutter/pages/create_party_page.dart';
import 'package:crowdcue_frontend_flutter/services/spotify_service.dart';
import 'package:crowdcue_frontend_flutter/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class InititalPage extends StatefulWidget {
  const InititalPage({super.key});
  @override
  State<StatefulWidget> createState() => _InititalPageState();
  static const String routeName = '/initital_page';
}

class _InititalPageState extends State<InititalPage> {
  bool _isConnectedToSpotify = false;
  double _createPartyElevation = 0.1;
  @override
  void initState() {
    super.initState();
    spotifyServiceInstance.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    spotifyServiceInstance.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("CrowdCue")),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              LinkSpotifyButton(
                onPressed: () async {
                  final res = await spotifyServiceInstance.connect();
                  print(
                    "spt hash: ${identityHashCode(spotifyServiceInstance)}",
                  );
                  if (res) {
                    setState(() {
                      _isConnectedToSpotify = true;
                      _createPartyElevation = 1;
                    });
                  } else {
                    setState(() {
                      _isConnectedToSpotify = false;
                      _createPartyElevation = 0.1;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.1, end: _createPartyElevation),
                duration: Duration(seconds: 1),
                builder: (conext, value, child) => ElevatedButton.icon(
                  onPressed: spotifyServiceInstance.isConnectedToSpotify
                      ? () {
                          Navigator.pushNamed(
                            context,
                            CreatePartyPage.routeName,
                          );
                        }
                      : null,

                  label: Text("Create Party"),
                  icon: Icon(FontAwesomeIcons.plus),
                  style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                    elevation: WidgetStateProperty.resolveWith((state) {
                      if (state.contains(WidgetState.disabled)) {
                        return 0;
                      }
                      return value * 10;
                    }),
                    surfaceTintColor: WidgetStateProperty.all(
                      Colors.transparent,
                    ),
                    shadowColor: WidgetStateProperty.all(primaryColorBase),
                    backgroundColor: WidgetStateProperty.resolveWith((state) {
                      final disabledColor = Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(255 ~/ 2);
                      final enabledColor = Theme.of(context).primaryColor;
                      if (state.contains(WidgetState.disabled)) {
                        return disabledColor;
                      }

                      return Color.lerp(disabledColor, enabledColor, value);
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
