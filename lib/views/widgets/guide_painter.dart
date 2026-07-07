import 'package:flutter/material.dart';
import 'dart:ui'; // 🌟 139行・143行の PathMetric の赤線を消すために必須のインポート

class GuidePainter extends CustomPainter {
  // 新しいマスターJSON構造（Mapオブジェクト全体）を受け取るように変更
  final Map<String, dynamic> designGuide;
  final bool isHorizontal;

  GuidePainter({
    required this.designGuide,
    this.isHorizontal = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 基本となるペイント設定（スマホの向きによって色を最適化）
    final paint = Paint()
      ..color = isHorizontal ? Colors.greenAccent : Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // 2. 基本仕様：三分割グリッドをうっすら背景に必ず描画（show_gridフラグがfalseでなければ描く）
    if (designGuide['show_grid'] != false) {
      // 🌟 Paintに copyWith はないので、新しくPaintオブジェクトを作って色を上書き指定します（23行目の修正）
      final gridPaint = Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..strokeWidth = paint.strokeWidth
        ..style = paint.style;
      _drawThirdsGrid(canvas, size, gridPaint);
    }

    // 3. 新JSON構造の「guide_shapes」（お弁当箱の四角枠、ケーキの楕円など）をすべてループ処理で描画
    if (designGuide['guide_shapes'] != null && designGuide['guide_shapes'] is List) {
      final List shapes = designGuide['guide_shapes'];
      for (var shape in shapes) {
        final String type = shape['type'] ?? '';
        final double cx = (shape['center_x']?.toDouble() ?? 0.5) * size.width;
        final double cy = (shape['center_y']?.toDouble() ?? 0.5) * size.height;
        final double w = (shape['width']?.toDouble() ?? 0.4) * size.width;
        final double h = (shape['height']?.toDouble() ?? 0.4) * size.height;

        // 🌟 Paintに copyWith はないので、個別に線の太さを設定したPaintを再生成（37行目の修正）
        final shapePaint = Paint()
          ..color = paint.color
          ..strokeWidth = shape['stroke_width']?.toDouble() ?? paint.strokeWidth
          ..style = paint.style;

        if (type == 'rect' || type == 'rrect') {
          // 四角形または角丸四角形（お弁当箱の枠などに使用）
          final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
          if (type == 'rrect') {
            final double radius = shape['corner_radius']?.toDouble() ?? 12.0;
            // 点線の角丸四角形を描画
            _drawDashedRRect(canvas, RRect.fromRectAndRadius(rect, Radius.circular(radius)), shapePaint);
          } else {
            // 通常の点線四角形
            _drawDashedRect(canvas, rect, shapePaint);
          }
        } else if (type == 'circle' || type == 'ellipse') {
          // 円または楕円（ケーキの上面・底面、お皿などに使用）
          final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
          _drawDashedArc(canvas, rect, 0, 2 * 3.14159265, shapePaint);
          
          // シズルゾーンや中心点などのターゲット指定があれば内円を描く
          if (shape['draw_center_target'] == true) {
            canvas.drawCircle(Offset(cx, cy), 15, shapePaint);
          }
        }
      }
    }

    // 4. 新JSON構造の「guide_lines」（参道のパース線、アングル斜め線、フォークなど）をすべてループ描画
    if (designGuide['guide_lines'] != null && designGuide['guide_lines'] is List) {
      final List lines = designGuide['guide_lines'];
      for (var line in lines) {
        final double x1 = (line['start_x']?.toDouble() ?? 0.0) * size.width;
        final double y1 = (line['start_y']?.toDouble() ?? 0.0) * size.height;
        final double x2 = (line['end_x']?.toDouble() ?? 1.0) * size.width;
        final double y2 = (line['end_y']?.toDouble() ?? 1.0) * size.height;

        // 🌟 Paintに copyWith はないので、個別に線の太さを設定したPaintを再生成（74行目の修正）
        final linePaint = Paint()
          ..color = paint.color
          ..strokeWidth = line['stroke_width']?.toDouble() ?? paint.strokeWidth
          ..style = paint.style;

        _drawDashedLine(canvas, Offset(x1, y1), Offset(x2, y2), linePaint);
      }
    }

    // 5. 後方互換性：もし古いJSON（shape_typeが直接指定されているもの）が来ても動くようにフォールバック処理を残す
    final String legacyShapeType = designGuide['shape_type'] ?? '';
    if (legacyShapeType.isNotEmpty) {
      final Map<String, dynamic> legacyParams = designGuide['shape_params'] ?? {};
      
      if (legacyShapeType == 'circle') {
        final double ratio = legacyParams['size_ratio']?.toDouble() ?? 0.6;
        final double radius = (size.width < size.height ? size.width : size.height) * ratio / 2;
        final center = Offset(size.width / 2, size.height / 2);
        _drawDashedCircle(canvas, center, radius, paint);
      } else if (legacyShapeType == 'center_cross') {
        final centerX = size.width / 2;
        final centerY = size.height * 0.55;
        _drawDashedCircle(canvas, Offset(centerX - 50, centerY - 40), 35, paint);
        _drawDashedArc(canvas, Rect.fromCenter(center: Offset(centerX - 50, centerY + 30), width: 100, height: 60), 3.14, 3.14, paint);
        _drawDashedCircle(canvas, Offset(centerX + 50, centerY - 30), 35, paint);
        _drawDashedArc(canvas, Rect.fromCenter(center: Offset(centerX + 50, centerY + 40), width: 100, height: 60), 3.14, 3.14, paint);
      } else if (legacyShapeType == 'thirds_target') {
        final targetX = size.width * 0.7;
        final targetY = size.height * 0.65;
        final dishRect = Rect.fromCenter(center: Offset(targetX, targetY), width: size.width * 0.6, height: size.width * 0.4);
        _drawDashedArc(canvas, dishRect, 0, 2 * 3.1415, paint);
        canvas.drawCircle(Offset(targetX, targetY), 20, paint);
        _drawDashedLine(canvas, Offset(size.width * 0.2, size.height * 0.3), Offset(targetX - 40, targetY - 20), paint);
      }
    }
  }

  // --- なぞり線を表現するためのカスタム描画関数 ---

  // 点線の丸・楕円
  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    _drawDashedArc(canvas, Rect.fromCircle(center: center, radius: radius), 0, 2 * 3.1415, paint);
  }

  // 点線の弧（肩やお皿のカーブ、楕円用）
  void _drawDashedArc(Canvas canvas, Rect rect, double startAngle, double sweepAngle, Paint paint) {
    const int dashCount = 40; // 楕円を滑らかに表現するために少し分割数を最適化
    final double dashAngle = sweepAngle / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      canvas.drawArc(rect, startAngle + (i * dashAngle), dashAngle, false, paint);
    }
  }

  // 点線の四角形（お弁当箱などの枠線用）
  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    // 4つの辺をそれぞれ点線でつなぐ
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLeft(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  // 後方互換・タイポ対策用のヘルパー
  void _drawDashedLeft(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    _drawDashedLine(canvas, p1, p2, paint);
  }

  // 点線の角丸四角形（お弁当箱の柔らかい外枠用）
  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    // 🌟 dart:ui をインポートしたことで PathMetric の赤線が解消されます（139行、143行の修正）
    final Path path = Path()..addRRect(rrect);
    final PathMetrics metrics = path.computeMetrics();
    const double dashWidth = 10.0;
    const double dashSpace = 8.0;

    for (final PathMetric metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double remaining = metric.length - distance;
        final double len = remaining < dashWidth ? remaining : dashWidth;
        final Path extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  // 点線の直線（お箸、パースガイド、アングル線用）
  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 10;
    const double dashSpace = 8;
    
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = Offset(dx, dy).distance;
    
    if (distance == 0) return;

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
    // 状態変化を厳密にチェックして適切に再描画
    return oldDelegate.isHorizontal != isHorizontal || 
           oldDelegate.designGuide != designGuide;
  }
}