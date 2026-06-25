// Service: SecureTokenStore
// Implementa el almacén de tokens para google_sign_in_desktop.

import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in_desktop/google_sign_in_desktop.dart';
import 'package:path/path.dart' as p;

class SecureTokenStore implements GoogleSignInDesktopStore<GoogleSignInDesktopTokenData> {
  final File _tokenFile;

  SecureTokenStore()
      : _tokenFile = File(p.join(
          Platform.environment['APPDATA'] ?? '',
          'Tab2Go',
          'oauth_tokens.json',
        ));

  @override
  Future<GoogleSignInDesktopTokenData?> get() async {
    if (!_tokenFile.existsSync()) return null;
    try {
      final jsonStr = await _tokenFile.readAsString();
      final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
      return GoogleSignInDesktopTokenData(
        accessToken: jsonMap['accessToken'] as String,
        idToken: jsonMap['idToken'] as String?,
        refreshToken: jsonMap['refreshToken'] as String?,
        expiration: jsonMap['expiration'] != null
            ? DateTime.parse(jsonMap['expiration'] as String)
            : null,
        scopes: (jsonMap['scopes'] as List?)?.cast<String>(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> set(GoogleSignInDesktopTokenData? value) async {
    if (value == null) {
      if (_tokenFile.existsSync()) {
        await _tokenFile.delete();
      }
      return;
    }
    try {
      final jsonMap = {
        'accessToken': value.accessToken,
        'idToken': value.idToken,
        'refreshToken': value.refreshToken,
        'expiration': value.expiration?.toIso8601String(),
        'scopes': value.scopes,
      };
      await _tokenFile.writeAsString(json.encode(jsonMap));
    } catch (_) {
      // Ignorar errores de escritura
    }
  }
}
