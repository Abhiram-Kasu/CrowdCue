import 'package:flutter/material.dart';
import 'package:crowdcue_frontend_flutter/remote/remote.dart'; // Adjust import path
import 'party_page.dart'; // Your PartyPage

class CreatePartyPage extends StatefulWidget {
  static const String routeName = '/create_party'; // Example route name
  const CreatePartyPage({super.key});

  @override
  State<CreatePartyPage> createState() => _CreatePartyPageState();
}

class _CreatePartyPageState extends State<CreatePartyPage> {
  final _usernameController = TextEditingController();
  final _partyNameController = TextEditingController();
  bool _isLoading = false;

  // Instance of the client for this creation flow
  late CrowdCueHttpClient _httpClient;

  @override
  void initState() {
    super.initState();
    _httpClient = CrowdCueHttpClient(); // Create a new instance
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _partyNameController.dispose();

    super.dispose();
  }

  Future<void> _createParty() async {
    if (_usernameController.text.isEmpty || _partyNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username and Party Name are required.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use the instance method
      final partyCode = await _httpClient.createParty(
        username: _usernameController.text,
        partyName: _partyNameController.text,
      );

      if (mounted) {
        // Navigate to PartyPage and pass the httpClient instance
        Navigator.pushReplacementNamed(
          context,
          PartyPage.routeName,
          arguments: _httpClient, // Pass the instance
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create party: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Party')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Your Username'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _partyNameController,
              decoration: const InputDecoration(labelText: 'Party Name'),
            ),
            Spacer(),

            ElevatedButton(
              onPressed: _createParty,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Party'),
            ),
          ],
        ),
      ),
    );
  }
}
