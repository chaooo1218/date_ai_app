import 'package:flutter/material.dart';
import '../../widgets/startrails_background.dart';
import 'signin_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  void _goSignIn(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignInPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 動態星軌背景（已降速；如需再慢可把 speedFactor 改更小）
          const StarTrailsBackground(speedFactor: 7, lineLengthFactor: 1.2),

          // 讓整個畫面可點，並在中央顯示文案
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _goSignIn(context),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Welcome Date Ai !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '點一下繼續',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,                    // 更小
                        color: Colors.white.withOpacity(0.55), // 更灰
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
