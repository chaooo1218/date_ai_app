import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class StarTrailsBackground extends StatefulWidget {
  const StarTrailsBackground({
    super.key,
    this.speedFactor = 0.1,     // 速度（1.0=原速；0.01≈原速1%）
    this.lineLengthFactor = 1.0, // 線長倍率（1.0=以螢幕寬為基準）
  });

  final double speedFactor;
  final double lineLengthFactor;

  @override
  State<StarTrailsBackground> createState() => _StarTrailsBackgroundState();
}

class _StarTrailsBackgroundState extends State<StarTrailsBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _elapsed = 0; // 以秒為單位的累積時間
  final _rng = Random(42);

  late final List<_Trail> _trails;

  // 流星
  double _meteorX = -200, _meteorY = -200, _meteorSpeed = 0, _meteorLen = 0, _meteorThick = 0;

  @override
  void initState() {
    super.initState();
    // 先用預估高度生成（實際繪製時用 yRatio 換算，不會跳）
    _trails = _generateTrails(800.0);

    _ticker = createTicker((d) {
      _elapsed = d.inMilliseconds / 1000.0; // 秒
      // 偶發流星（低機率）
      if (_rng.nextDouble() < 0.0025 && _meteorSpeed == 0) {
        final h = context.size?.height ?? 800;
        final w = context.size?.width ?? 400;
        _meteorX = -150;
        _meteorY = 60 + _rng.nextDouble() * (h - 120);
        _meteorSpeed = 250 + _rng.nextDouble() * 350; // px/秒
        _meteorLen = (w * (0.4 + _rng.nextDouble() * 0.5)).clamp(120, 600);
        _meteorThick = 0.8 + _rng.nextDouble() * 1.2;
      }
      if (_meteorSpeed > 0) {
        _meteorX += _meteorSpeed / 60.0; // 以約 60fps 推進
        final w = context.size?.width ?? 400;
        if (_meteorX - _meteorLen > w + 150) _meteorSpeed = 0;
      }
      setState(() {});
    })..start();
  }

  List<_Trail> _generateTrails(double height) {
    final total = (height / 8).clamp(60, 140).toInt();
    final list = <_Trail>[];
    for (var i = 0; i < total; i++) {
      final yRatio = (i + 1) / (total + 1);         // 固定高度（0~1）
      final thickness = 0.3 + _rng.nextDouble() * 1.6;
      final opacity = 0.25 + _rng.nextDouble() * 0.35;
      final speed = (20 + _rng.nextInt(40)).toDouble(); // 基礎速度單位：px/秒（會再乘 speedFactor）
      final baseLenRatio = 0.7 + _rng.nextDouble() * 0.6; // 0.7~1.3 寬度
      final phase = _rng.nextDouble(); // 0~1 初相位
      list.add(_Trail(
        yRatio: yRatio,
        thickness: thickness,
        opacity: opacity,
        speed: speed,
        baseLenRatio: baseLenRatio,
        phase: phase,
      ));
    }
    return list;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarTrailsPainter(
        elapsed: _elapsed,
        trails: _trails,
        speedFactor: widget.speedFactor,
        lineLengthFactor: widget.lineLengthFactor,
        meteorX: _meteorX,
        meteorY: _meteorY,
        meteorSpeed: _meteorSpeed,
        meteorLen: _meteorLen,
        meteorThick: _meteorThick,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _Trail {
  final double yRatio, thickness, opacity, speed, baseLenRatio, phase;
  const _Trail({
    required this.yRatio,
    required this.thickness,
    required this.opacity,
    required this.speed,
    required this.baseLenRatio,
    required this.phase,
  });
}

class _StarTrailsPainter extends CustomPainter {
  final double elapsed, speedFactor, lineLengthFactor;
  final List<_Trail> trails;
  final double meteorX, meteorY, meteorSpeed, meteorLen, meteorThick;

  _StarTrailsPainter({
    required this.elapsed,
    required this.trails,
    required this.speedFactor,
    required this.lineLengthFactor,
    required this.meteorX,
    required this.meteorY,
    required this.meteorSpeed,
    required this.meteorLen,
    required this.meteorThick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    for (final t in trails) {
      final y = t.yRatio * size.height;               // 固定高度 → 不跳
      final baseLen = size.width * t.baseLenRatio * lineLengthFactor;
      final span = size.width + baseLen;

      // 位置：以秒為基礎的平滑位移，左進右出
      final pxPerSec = t.speed * speedFactor;
      final travel = (elapsed * pxPerSec + t.phase * span) % span;
      final x = travel - baseLen;

      final p = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(t.opacity),
            Colors.white.withOpacity(0),
          ],
        ).createShader(Rect.fromLTWH(x, y - 1, baseLen, 2))
        ..strokeCap = StrokeCap.round
        ..strokeWidth = t.thickness;

      canvas.drawLine(Offset(x, y), Offset(x + baseLen, y), p);
    }

    // 流星
    if (meteorSpeed > 0) {
      final m = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.35),
            Colors.white.withOpacity(0),
          ],
          stops: const [0, 0.5, 0.85, 1],
        ).createShader(Rect.fromLTWH(meteorX - meteorLen, meteorY - meteorThick,
            meteorLen, meteorThick * 2))
        ..strokeCap = StrokeCap.round
        ..strokeWidth = meteorThick;
      canvas.drawLine(Offset(meteorX - meteorLen, meteorY), Offset(meteorX, meteorY), m);
    }
  }

  @override
  bool shouldRepaint(covariant _StarTrailsPainter old) => true;
}
