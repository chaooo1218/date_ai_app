import 'package:flutter/material.dart';

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController(); // cm
  final _weightCtrl = TextEditingController();

  String _unit = 'kg'; // kg or lb

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24, width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white70, width: 1),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text("建立個人資料")),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: deco("名稱（可自訂）", hint: "例如：小宇 / Yuri / Alex"),
                validator: (v) => (v == null || v.trim().isEmpty) ? "請輸入名稱" : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _heightCtrl,
                keyboardType: TextInputType.number,
                decoration: deco("身高（cm）", hint: "例如：175"),
                validator: (v) {
                  final n = num.tryParse(v ?? "");
                  if (n == null || n <= 0) return "請輸入正確的身高";
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: deco("體重（$_unit）", hint: _unit == 'kg' ? "例如：68" : "例如：150"),
                      validator: (v) {
                        final n = num.tryParse(v ?? "");
                        if (n == null || n <= 0) return "請輸入正確的體重";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ToggleButtons(
                    isSelected: [_unit == 'kg', _unit == 'lb'],
                    onPressed: (i) {
                      setState(() => _unit = i == 0 ? 'kg' : 'lb');
                    },
                    borderRadius: BorderRadius.circular(12),
                    selectedColor: Colors.black,
                    fillColor: Colors.white,
                    color: Colors.white70,
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("kg")),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("lb")),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    // TODO: 送到後端 / 儲存本地
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("資料已儲存")));
                    Navigator.pop(context); // 返回或導到首頁
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text("開始使用", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
