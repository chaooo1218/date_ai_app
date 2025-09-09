import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 用 Firebase Provider 直接走 Google（不需 google_sign_in 套件）
  Future<UserCredential?> signInWithGoogle() async {
    final googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    // 如需每次都選帳號，可加：
    // googleProvider.setCustomParameters({'prompt': 'select_account'});
    return _auth.signInWithProvider(googleProvider);
  }

  Future<UserCredential?> signInWithFacebook() async {
    final res = await FacebookAuth.instance.login(permissions: ['email']);
    if (res.status != LoginStatus.success || res.accessToken == null) return null;
    final cred = FacebookAuthProvider.credential(res.accessToken!.tokenString);
    return _auth.signInWithCredential(cred);
  }

  Future<UserCredential?> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) return null;
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    final oauth = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken,
      accessToken: apple.authorizationCode,
    );
    return _auth.signInWithCredential(oauth);
  }

  User? get currentUser => _auth.currentUser;
  Future<void> signOut() => _auth.signOut();
}
