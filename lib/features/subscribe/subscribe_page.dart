import 'package:flutter/material.dart';

class SubscribePage extends StatelessWidget {
  const SubscribePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("訂閱方案(You are my Daddy!)", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _PlanCard(title: "月方案", price: "NTD 399 / 月", desc: "首月免費使用"),
          const SizedBox(height: 12),
          _PlanCard(title: "年方案", price: "NTD 4000 / 年", desc: "比月付省 788（約 16.45%）"),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // 之後在這裡串 IAP
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("尚未串接付款，之後接 IAP")),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text("立即訂閱", style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title, price, desc;
  const _PlanCard({required this.title, required this.price, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}