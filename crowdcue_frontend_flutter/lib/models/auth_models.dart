import 'package:flutter/foundation.dart'; // For @required if you use it, or general utilities

class AuthResponse {
  final String token;
  final String? partyCode;

  AuthResponse({required this.token, this.partyCode});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      partyCode: json['partyCode'] as String?,
    );
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
