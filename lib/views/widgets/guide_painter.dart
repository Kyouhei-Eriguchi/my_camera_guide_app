import 'package:flutter/material.dart';

class GuidePainter extends CustomPainter {
  final String shapeType;
  final Map<String, dynamic> shapeParams;
  final bool isHorizontal; // スマホが水平かどうか（連動用ギミック）

  GuidePainter({
    required this.shapeType,
    required this.shapeParams,
    this.isHorizontal = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 点線の基本設定（水平なら緑、そうでなければ白）
    final paint = Paint()
      ..color = isHorizontal ? Colors.greenAccent : Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    switch (shapeType) {
      case 'circle':
        // 【ど定番：丸皿・俯瞰用】画面中央に綺麗な点線の丸を描く
        final double ratio = shapeParams['size_ratio']?.toDouble() ?? 0.6;
        final double radius = (size.width < size.height ? size.width : size.height) * ratio / 2;
        final center = Offset(size.width / 2, size.height / 2);
        
        _drawDashedCircle(canvas, center, radius, paint);
        break;

      case 'center_cross':
        // 【ど定番：集合写真用】中央を意識させるための大きな十字と補助枠
        final center = Offset(size.width / 2, size.height / 2);
        // 中央の小さなターゲット十字
        canvas.drawLine(Offset(center.dx - 20, center.dy), Offset(center.dx + 20, center.dy), paint);
        canvas.drawLine(Offset(center.dx, center.dy - 20), Offset(center.dx, center.dy + 20), paint);
        // ガイド用の緩やかな四角枠
        final rectSize = size.width * 0.7;
        final rect = Rect.fromCenter(center: center, width: rectSize, height: rectSize * 0.6);
        _drawDashedRect(canvas, rect, paint);
        break;

      case 'thirds_target':
        // 【アレンジ：シズル感用】三分割のグリッド線を引きつつ、右下の交点にターゲットマークを描く
        _drawThirdsGrid(canvas, size, paint);
        
        // 右下の交点（縦2/3, 横2/3の位置）を計算
        final targetX = size.width * 2 / 3;
        final targetY = size.height * 2 / 3;
        
        // ターゲットマーク（二重円）を描く
        canvas.drawCircle(Offset(targetX, targetY), 15, paint);
        canvas.drawCircle(Offset(targetX, targetY), 5, paint..style = PaintingStyle.fill);
        break;

      default:
        // 該当がない場合はうっすら三分割線だけ表示
        _drawThirdsGrid(canvas, size, paint..color = Colors.white24);
        break;
    }
  }

  // --- 以下、点線を描画するための便利サブ関数群 ---

  // 点線の丸を描く
  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const int dashCount = 40;
    for (int i = 0; i < dashCount; i++) {
      final double angle1 = (i * 2 * 3.1415) / dashCount;
      final double angle2 = ((i * 2 + 1) * 3.1415) / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle1,
        angle2 - angle1,
        false,
        paint,
      );
    }
  }

  // 点線の四角を描く
  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const double dashWidth = 10;
    const double dashSpace = 8;

    // 上辺
    double x = rect.left;
    while (x < rect.right) {
      canvas.drawLine(Offset(x, rect.top), Offset(x + dashWidth > rect.right ? rect.right : x + dashWidth, rect.top), paint);
      x += dashWidth + dashSpace;
    }
    // 下辺
    x = rect.left;
    while (x < rect.right) {
      canvas.drawLine(Offset(x, rect.bottom), Offset(x + dashWidth > rect.right ? rect.right : x + dashWidth, rect.bottom), paint);
      x += dashWidth + dashSpace;
    }
    // 左辺
    double y = rect.top;
    while (y < rect.bottom) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.left, y + dashWidth > rect.bottom ? rect.bottom : y + dashWidth), paint);
      y += dashWidth + dashSpace;
    }
    // 右辺
    y = rect.top;
    while (y < rect.bottom) {
      canvas.drawLine(Offset(rect.right, y), Offset(rect.right, y + dashWidth > rect.bottom ? rect.bottom : y + dashWidth), paint);
      y += dashWidth + dashSpace;
    }
  }

  // うっすらとした三分割線を描く
  void _drawThirdsGrid(Canvas canvas, Size size, Paint paint) {
    final gridPaint = Paint()
      ..color = paint.color.withOpacity(0.3)
      ..strokeWidth = 1.0;

    // 縦線2本
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), gridPaint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), gridPaint);
    // 横線2本
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), gridPaint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), gridPaint);
  }

  @override
  bool shouldRepaint(covariant GuidePainter oldDelegate) {
    return oldDelegate.isHorizontal != isHorizontal || oldDelegate.shapeType != shapeType;
  }
}