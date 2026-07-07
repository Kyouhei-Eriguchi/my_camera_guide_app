import 'package:flutter/material.dart';
import 'dart:ui';

class GuidePainter extends CustomPainter {
  // 新しいマスターJSON構造（Mapオブジェクト全体）を受け取る
  final Map<String, dynamic> designGuide;
  final bool isHorizontal;

  GuidePainter({
    required this.designGuide,
    this.isHorizontal = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 基本となるペイント設定
    final paint = Paint()
      ..color = isHorizontal ? Colors.greenAccent : Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    try {
      // 2. 基本仕様：三分割グリッドをうっすら背景に必ず描画（show_gridフラグがfalseでなければ描く）
      if (designGuide['show_grid'] != false) {
        final gridPaint = Paint()
          ..color = Colors.white.withOpacity(0.15)
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style;
        _drawThirdsGrid(canvas, size, gridPaint);
      }

      // 3. 新JSON構造の「guide_shapes」（お弁当箱の四角枠、ケーキの楕円など）のループ描画
      if (designGuide['guide_shapes'] != null && designGuide['guide_shapes'] is List) {
        final List<dynamic> shapes = designGuide['guide_shapes'];
        for (var shape in shapes) {
          if (shape is! Map) continue;

          final String type = shape['type']?.toString() ?? '';
          
          final double cx = (shape['center_x'] is num) ? (shape['center_x'] as num).toDouble() * size.width : size.width * 0.5;
          final double cy = (shape['center_y'] is num) ? (shape['center_y'] as num).toDouble() * size.height : size.height * 0.5;
          final double w = (shape['width'] is num) ? (shape['width'] as num).toDouble() * size.width : size.width * 0.4;
          final double h = (shape['height'] is num) ? (shape['height'] as num).toDouble() * size.height : size.height * 0.4;
          final double customStrokeWidth = (shape['stroke_width'] is num) ? (shape['stroke_width'] as num).toDouble() : paint.strokeWidth;

          final shapePaint = Paint()
            ..color = paint.color
            ..strokeWidth = customStrokeWidth
            ..style = paint.style;

          if (type == 'rect' || type == 'rrect') {
            final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
            if (type == 'rrect') {
              final double radius = (shape['corner_radius'] is num) ? (shape['corner_radius'] as num).toDouble() : 12.0;
              _drawDashedRRect(canvas, RRect.fromRectAndRadius(rect, Radius.circular(radius)), shapePaint);
            } else {
              _drawDashedRect(canvas, rect, shapePaint);
            }
          } else if (type == 'circle' || type == 'ellipse') {
            final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
            _drawDashedArc(canvas, rect, 0, 2 * 3.14159265, shapePaint);
            
            if (shape['draw_center_target'] == true) {
              canvas.drawCircle(Offset(cx, cy), 15, shapePaint);
            }
          }
        }
      }

      // 4. 新JSON構造の「guide_lines」（参道のパース線、アングル斜め線、フォークなど）のループ描画
      if (designGuide['guide_lines'] != null && designGuide['guide_lines'] is List) {
        final List<dynamic> lines = designGuide['guide_lines'];
        for (var line in lines) {
          if (line is! Map) continue;

          final double x1 = (line['start_x'] is num) ? (line['start_x'] as num).toDouble() * size.width : 0.0;
          final double y1 = (line['start_y'] is num) ? (line['start_y'] as num).toDouble() * size.height : 0.0;
          final double x2 = (line['end_x'] is num) ? (line['end_x'] as num).toDouble() * size.width : size.width;
          final double y2 = (line['end_y'] is num) ? (line['end_y'] as num).toDouble() * size.height : size.height;
          final double customStrokeWidth = (line['stroke_width'] is num) ? (line['stroke_width'] as num).toDouble() : paint.strokeWidth;

          final linePaint = Paint()
            ..color = paint.color
            ..strokeWidth = customStrokeWidth
            ..style = paint.style;

          _drawDashedLine(canvas, Offset(x1, y1), Offset(x2, y2), linePaint);
        }
      }

      // 5. 後方互換性：もし古いJSON（shape_typeが直接指定されているもの）が来ても動くようにフォールバック処理
      final String legacyShapeType = designGuide['shape_type']?.toString() ?? '';
      if (legacyShapeType.isNotEmpty) {
        final Map<dynamic, dynamic> legacyParams = designGuide['shape_params'] is Map ? designGuide['shape_params'] : {};
        
        if (legacyShapeType == 'circle') {
          final double ratio = (legacyParams['size_ratio'] is num) ? (legacyParams['size_ratio'] as num).toDouble() : 0.6;
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
    } catch (e, stacktrace) {
      debugPrint('GuidePainterエラー回避ロジック発動: $e');
      debugPrint('スタックトレース: $stacktrace');
      
      // 🌟 paint.copyWith を修正：新しく Paint を生成して色をオーバーライド（125行目の修正）
      final errorGridPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..strokeWidth = paint.strokeWidth
        ..style = paint.style;
      
      _drawThirdsGrid(canvas, size, errorGridPaint);
    }
  }

  // --- なぞり線を表現するためのカスタム描画関数 ---

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    _drawDashedArc(canvas, Rect.fromCircle(center: center, radius: radius), 0, 2 * 3.1415, paint);
  }

  void _drawDashedArc(Canvas canvas, Rect rect, double startAngle, double sweepAngle, Paint paint) {
    const int dashCount = 40;
    final double dashAngle = sweepAngle / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      canvas.drawArc(rect, startAngle + (i * dashAngle), dashAngle, false, paint);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLeft(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  void _drawDashedLeft(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    _drawDashedLine(canvas, p1, p2, paint);
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
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

  void _drawThirdsGrid(Canvas canvas, Size size, Paint paint) {
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant GuidePainter oldDelegate) {
    return oldDelegate.isHorizontal != isHorizontal || 
           oldDelegate.designGuide != designGuide;
  }
}