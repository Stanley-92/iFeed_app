import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';

class AuthService {
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '648857401957-ls155kc1i0uqqkc2jofkmklasklgomd5.apps.googleusercontent.com',
  );

  // Email + password login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final r = await apiPost('/auth/login', {
      'email': email,
      'password': password,
    });
    final body = expectJson(r);
    await saveTokens(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
      userId: (body['user'] as Map)['id'] as String,
    );
    return body['user'] as Map<String, dynamic>;
  }

  // Email + password register
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final r = await apiPost('/auth/register', {
      'email': email,
      'password': password,
      if (displayName != null) 'displayName': displayName,
    });
    final body = expectJson(r);
    await saveTokens(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
      userId: (body['user'] as Map)['id'] as String,
    );
    return body['user'] as Map<String, dynamic>;
  }

  // Google Sign-In
  Future<Map<String, dynamic>> loginWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in cancelled');

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw Exception('No Google ID token');

    final r = await apiPost('/auth/google', {'idToken': idToken});
    final body = expectJson(r);
    await saveTokens(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
      userId: (body['user'] as Map)['id'] as String,
    );
    return body['user'] as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await _googleSignIn.signOut().catchError((_) {});
    await clearTokens();
  }
}
