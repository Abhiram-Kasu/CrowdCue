import 'package:crowdcue_frontend_flutter/pages/create_party_page.dart';
import 'package:crowdcue_frontend_flutter/pages/party_page.dart';
import 'package:crowdcue_frontend_flutter/remote/remote.dart';
import 'package:crowdcue_frontend_flutter/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:crowdcue_frontend_flutter/pages/initial_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: InititalPage.routeName,
      routes: {
        InititalPage.routeName: (context) => const InititalPage(),
        CreatePartyPage.routeName: (context) => CreatePartyPage(),
        PartyPage.routeName: (context) {
          final httpClient =
              ModalRoute.of(context)!.settings.arguments as CrowdCueHttpClient;
          return PartyPage(httpClient: httpClient);
        },
        // Add other routes here
      },
    );
  }
}
