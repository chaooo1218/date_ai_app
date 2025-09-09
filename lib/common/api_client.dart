import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// 切換：本機 emulator / 雲端
class ApiConfig {
  // 本機 emulator：Android 模擬器請用 10.0.2.2
  static const localBase =
      'http://10.0.2.2:5001/date-ai-16d09/asia-east1/api';

  // 雲端（部署後把 <project-id> 換掉）
  static const prodBase =
      'https://asia-east1-date-ai-16d09.cloudfunctions.net/api';

  // 開發時改這個
  static const useLocal = true;

  static String get baseUrl => useLocal ? localBase : prodBase;
}

class ApiClient {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, String>> _headers() async {
    final user = _auth.currentUser;
    final token = user != null ? await user.getIdToken(true) : null;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<String> chat(String message, {bool newChat = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({'message': message, 'newChat': newChat}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return (j['reply'] as String?) ?? '…';
    }
    throw Exception('API /chat error: ${res.statusCode} ${res.body}');
  }

  Future<String> outfitAdvise({
    required String prompt,
    required String imageBase64,
    bool newChat = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/outfit');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({
        'prompt': prompt,
        'image_base64': imageBase64,
        'newChat': newChat,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return (j['reply'] as String?) ?? '…';
    }
    throw Exception('API /outfit error: ${res.statusCode} ${res.body}');
  }
}
