// Service: AuthService
// Gestiona el inicio de sesión y autenticación con Google.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_desktop/google_sign_in_desktop.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;

import 'storage_service.dart';
import 'token_store.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  bool _initialized = false;
  bool _isConfigured = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isConfigured => _isConfigured;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final creds = StorageService().loadOAuthCredentials();
    if (creds != null && creds['client_id']!.isNotEmpty && creds['client_secret']!.isNotEmpty) {
      _configure(creds['client_id']!, creds['client_secret']!);
    }
  }

  void _configure(String clientId, String clientSecret) {
    if (GoogleSignInPlatform.instance case GoogleSignInDesktop instance) {
      instance.clientSecret = clientSecret;
      instance.tokenDataStore = SecureTokenStore();
    }
    
    _googleSignIn = GoogleSignIn(
      clientId: clientId,
      scopes: [
        'https://www.googleapis.com/auth/drive.appdata',
      ],
    );
    _isConfigured = true;
    
    _googleSignIn!.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      notifyListeners();
    });
    
    // Intento silencioso de login al iniciar
    try {
      _googleSignIn!.signInSilently();
    } catch (_) {
      // Ignorar errores si no hay red
    }
  }

  Future<void> updateCredentials(String clientId, String clientSecret) async {
    StorageService().saveOAuthCredentials(clientId, clientSecret);
    _configure(clientId, clientSecret);
    notifyListeners();
  }

  Future<GoogleSignInAccount?> signIn() async {
    if (!_isConfigured) {
      throw StateError('Google Sign-In no está configurado con Client ID y Secret.');
    }
    try {
      final account = await _googleSignIn!.signIn();
      _currentUser = account;
      notifyListeners();
      return account;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (_googleSignIn != null) {
      await _googleSignIn!.signOut();
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<Map<String, String>?> getAuthHeaders() async {
    if (_currentUser == null) return null;
    return await _currentUser!.authHeaders;
  }

  // Retorna un cliente HTTP autenticado
  Future<http.Client?> getAuthenticatedClient() async {
    final headers = await getAuthHeaders();
    if (headers == null) return null;
    return AuthenticatedClient(headers);
  }
}

// Cliente HTTP envoltorio que adjunta cabeceras de autorización automáticamente
class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final Map<String, String> _headers;

  AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
