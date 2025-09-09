import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 登入前
import 'features/auth/welcome_page.dart';

// 登入後主分頁
import 'features/chat/chat_page.dart';
import 'features/outfit/outfit_page.dart';
import 'features/subscribe/subscribe_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android 放好 android/app/google-services.json 後，可直接呼叫
  // （若你用 FlutterFire CLI 產生了 firebase_options.dart，改為傳入 options）
  await Firebase.initializeApp();

  runApp(const DateAiApp());
}

class DateAiApp extends StatelessWidget {
  const DateAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Date Ai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      // 用 auth 狀態決定進入頁：未登入→Welcome；已登入→Main
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasData) {
            return const MainPage();
          }
          return const WelcomePage();
        },
      ),
    );
  }
}

/// 登入後的主框架（底部 3 分頁）
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final _pages = const [
    ChatPage(),
    OutfitPage(),
    SubscribePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Date Ai"), backgroundColor: Colors.black),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "聊天"),
          BottomNavigationBarItem(icon: Icon(Icons.checkroom), label: "穿搭"),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: "訂閱"),
        ],
      ),
    );
  }
}
