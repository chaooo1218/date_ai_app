import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../common/services/auth_service.dart';
import '../profile/profile_form_page.dart';
import '../../widgets/startrails_background.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _auth = AuthService();
  bool _loading = false;

  Future<void> _doSignIn(Future<UserCredential?> Function() fn) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final cred = await fn();                  // 執行實際登入
      final user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;

      if (cred == null || user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('尚未登入或使用者取消')),
        );
        return;
      }

      // 顯示登入結果（幫你確認真的登入成功）
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('歡迎 ${user.displayName ?? user.email ?? user.uid}')),
      );

      // 成功才導向個資表單（或你的 MainPage）
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileFormPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登入失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _btn({required IconData icon, required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: _loading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white30, width: 0.7),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white70),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showApple = Platform.isIOS || Platform.isMacOS;
    return Scaffold(
      body: Stack(
        children: [
          const StarTrailsBackground(speedFactor: 0.05, lineLengthFactor: 1.2),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                children: [
                  const Spacer(),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: CircularProgressIndicator(),
                    ),
                  _btn(
                    icon: Icons.g_mobiledata,
                    text: '使用 Google 登入',
                    onTap: () => _doSignIn(() => _auth.signInWithGoogle()),
                  ),
                  const SizedBox(height: 12),
                  if (showApple) ...[
                    _btn(
                      icon: Icons.apple, text: '使用 Apple 登入',
                      onTap: () => _doSignIn(() => _auth.signInWithApple()),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _btn(
                    icon: Icons.facebook,
                    text: '使用 Facebook 登入',
                    onTap: () => _doSignIn(() => _auth.signInWithFacebook()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
