import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl; // 例如 https://us-central1-<project>.cloudfunctions.net
  final String? idToken; // 如果之後用 Firebase Auth，可帶 token 做鑑權

  ApiClient({required this.baseUrl, this.idToken});

  Future<String> chat(String message) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        if (idToken != null) HttpHeaders.authorizationHeader: 'Bearer $idToken',
      },
      body: jsonEncode({"message": message}),
    );
    if (res.statusCode != 200) throw Exception('Chat failed: ${res.body}');
    return jsonDecode(res.body)['reply'] as String;
  }

  Future<String> outfitAdvise({
    required String prompt,
    required String imageBase64, // from ImagePicker
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/outfit'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        if (idToken != null) HttpHeaders.authorizationHeader: 'Bearer $idToken',
      },
      body: jsonEncode({
        "prompt": prompt,
        "image_base64": imageBase64,
      }),
    );
    if (res.statusCode != 200) throw Exception('Outfit failed: ${res.body}');
    return jsonDecode(res.body)['reply'] as String;
  }
}
