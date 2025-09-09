import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../common/api_client.dart';

class OutfitPage extends StatefulWidget {
  const OutfitPage({super.key});

  @override
  State<OutfitPage> createState() => _OutfitPageState();
}

class _OutfitPageState extends State<OutfitPage> {
  final _picker = ImagePicker();
  final _api = ApiClient(baseUrl: 'https://<你的雲端函式URL>'); // TODO
  File? _file;
  String? _advise;
  bool _loading = false;

  Future<void> _pick() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    setState(() {
      _file = File(img.path);
      _advise = null;
    });
  }

  Future<void> _analyze() async {
    if (_file == null || _loading) return;
    setState(() => _loading = true);
    try {
      final b64 = base64Encode(await _file!.readAsBytes());
      final reply = await _api.outfitAdvise(
        prompt: "請就此穿搭給出建議，並推薦 2~3 個購買連結（台灣可買）",
        imageBase64: b64,
      );
      setState(() => _advise = reply);
    } catch (e) {
      setState(() => _advise = '（系統忙線，請稍後再試）');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_file != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_file!, height: 200, fit: BoxFit.cover),
          )
        else
          Container(
            height: 200,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text('請先選擇圖片'),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.photo),
              label: const Text('選擇圖片'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _analyze,
              icon: const Icon(Icons.auto_awesome),
              label: _loading ? const Text('分析中...') : const Text('產生建議'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_advise != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(_advise!),
          ),
      ],
    );
  }
}
