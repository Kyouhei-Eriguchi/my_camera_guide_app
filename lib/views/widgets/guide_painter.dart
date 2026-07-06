import 'package:flutter/material.dart';

class GuidePainter extends CustomPainter {
  final String shapeType;
  final Map<String, dynamic> shapeParams;
  final bool isHorizontal;

  GuidePainter({
    required this.shapeType,
    required this.shapeParams,
    this.isHorizontal = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isHorizontal ? Colors.greenAccent : Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    switch (shapeType) {
      case 'circle':
        // 【王道：真上俯瞰】
        final double ratio = shapeParams['size_ratio']?.toDouble() ?? 0.6;
        final double radius = (size.width < size.height ? size.width : size.height) * ratio / 2;
        final center = Offset(size.width / 2, size.height / 2);
        _drawDashedCircle(canvas, center, radius, paint);
        break;

      case 'center_cross':
        // 🌟【改善：人物・仲良しローアングル】
        // 画面中央の下寄りに、並ぶ2人の「顔の輪郭」と「肩のライン」をなぞり線で描画
        final centerX = size.width / 2;
        final centerY = size.height * 0.55; // ローアングルなので少し上を見上げる位置

        // 1人目の頭と肩（左側）
        _drawDashedCircle(canvas, Offset(centerX - 50, centerY - 40), 35, paint); // 顔
        _drawDashedArc(canvas, Rect.fromCenter(center: Offset(centerX - 50, centerY + 30), width: 100, height: 60), 3.14, 3.14, paint); // 肩

        // 2人目の頭と肩（右側・少し首を傾けてる風）
        _drawDashedCircle(canvas, Offset(centerX + 50, centerY - 30), 35, paint); // 顔
        _drawDashedArc(canvas, Rect.fromCenter(center: Offset(centerX + 50, centerY + 40), width: 100, height: 60), 3.14, 3.14, paint); // 肩
        
        // 楽しそうな目線が交差するセンター十字
        _drawThirdsGrid(canvas, size, paint..color = Colors.white12);
        break;

      case 'thirds_target':
        // 🌟【改善：料理・極上のシズル感】
        // 右下に「斜め45度でグッと近づいた楕円のお皿」と「左から伸びるお箸/フォーク」を表現
        _drawThirdsGrid(canvas, size, paint..color = Colors.white24);
        
        final targetX = size.width * 0.7;
        final targetY = size.height * 0.65;

        // 傾いたお皿（横長の楕円）をドアップのサイズ感で描画
        final dishRect = Rect.fromCenter(center: Offset(targetX, targetY), width: size.width * 0.6, height: size.width * 0.4);
        _drawDashedArc(canvas, dishRect, 0, 2 * 3.1415, paint);

        // お肉や主役が乗るべき「シズルゾーン」のターゲット内円
        canvas.drawCircle(Offset(targetX, targetY), 20, paint);

        // 左上からお皿に向かって伸びる「お箸・フォーク」のなぞり線（ストーリー性）
        _drawDashedLine(canvas, Offset(size.width * 0.2, size.height * 0.3), Offset(targetX - 40, targetY - 20), paint);
        break;

      default:
        _drawThirdsGrid(canvas, size, paint..color = Colors.white24);
        break;
    }
  }

  // --- なぞり線を表現するためのカスタム描画関数 ---

  // 点線の丸・楕円
  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    _drawDashedArc(canvas, Rect.fromCircle(center: center, radius: radius), 0, 2 * 3.1415, paint);
  }

  // 点線の弧（肩やお皿のカーブ用）
  void _drawDashedArc(Canvas canvas, Rect rect, double startAngle, double sweepAngle, Paint paint) {
    const int dashCount = 30;
    final double dashAngle = sweepAngle / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      canvas.drawArc(rect, startAngle + (i * dashAngle), dashAngle, false, paint);
    }
  }

  // 点線の直線（お箸やガイド用）
  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 10;
    const double dashSpace = 8;
    
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = Offset(dx, dy).distance;
    
    final int dashCount = (distance / (dashWidth + dashSpace)).floor();
    
    final double xStep = dx / distance;
    final double yStep = dy / distance;
    
    for (int i = 0; i < dashCount; i++) {
      final double startX = p1.dx + (i * (dashWidth + dashSpace)) * xStep;
      final double startY = p1.dy + (i * (dashWidth + dashSpace)) * yStep;
      final double endX = startX + dashWidth * xStep;
      final double endY = startY + dashWidth * yStep;
      
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  // うっすらとした三分割線
  void _drawThirdsGrid(Canvas canvas, Size size, Paint paint) {
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant GuidePainter oldDelegate) {
    return oldDelegate.isHorizontal != isHorizontal || oldDelegate.shapeType != shapeType;
  }
}