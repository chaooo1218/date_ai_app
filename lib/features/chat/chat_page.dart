import 'package:flutter/material.dart';
import '../../common/api_client.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _ctrl = TextEditingController();
  final _msgs = <_Bubble>[];
  final _api = ApiClient(baseUrl: 'https://<你的雲端函式URL>'); // TODO

  bool _loading = false;

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _msgs.add(_Bubble.me(text));
      _loading = true;
    });
    _ctrl.clear();
    try {
      final reply = await _api.chat(text);
      setState(() => _msgs.add(_Bubble.ai(reply)));
    } catch (e) {
      setState(() => _msgs.add(_Bubble.ai('（系統忙線，請稍後再試）')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length,
            itemBuilder: (_, i) => Align(
              alignment:
                  _msgs[i].fromMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _msgs[i].fromMe ? Colors.white12 : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(_msgs[i].text),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    hintText: '輸入訊息...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator())
                    : const Icon(Icons.send),
                onPressed: _send,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble {
  final String text;
  final bool fromMe;
  _Bubble.me(this.text) : fromMe = true;
  _Bubble.ai(this.text) : fromMe = false;
}
