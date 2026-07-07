import 'package:flutter/material.dart';
import 'dart:ui';

class GuidePainter extends CustomPainter {
  // JSONの「design_guide」またはガイドオブジェクト全体のMapを受け取る
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
      // 階層のズレ対策（"design_guide" の中にデータがある場合と、直下にある場合の両方に対応）
      final Map<String, dynamic> guideData = designGuide.containsKey('design_guide') 
          ? Map<String, dynamic>.from(designGuide['design_guide']) 
          : designGuide;

      // 2. 基本仕様：三分割グリッドを表示（JSONで明示的にfalseでない限りうっすら表示）
      final gridLines = guideData['grid_lines'];
      if (gridLines == null || (gridLines is Map && gridLines['visible'] != false)) {
        final gridPaint = Paint()
          ..color = Colors.white.withOpacity(0.12)
          ..strokeWidth = 1.5
          ..style = paint.style;
        _drawThirdsGrid(canvas, size, gridPaint);
      }

      // 3. 🌟 JSONの「guide_shapes」配列をリッチに解析・描画
      if (guideData['guide_shapes'] != null && guideData['guide_shapes'] is List) {
        final List<dynamic> shapes = guideData['guide_shapes'];
        
        for (var shape in shapes) {
          if (shape is! Map) continue;
          final String type = shape['type']?.toString() ?? '';

          // 共通ペイント設定の生成
          final double customStrokeWidth = (shape['stroke_width'] is num) 
              ? (shape['stroke_width'] as num).toDouble() 
              : paint.strokeWidth;
              
          final shapePaint = Paint()
            ..color = paint.color
            ..strokeWidth = customStrokeWidth
            ..style = paint.style;

          // --- A. 円・楕円形 (circle / ellipse / spot / capsule などに追従) ---
          if (type.contains('circle') || type.contains('ellipse') || type.contains('spot') || type.contains('oval')) {
            
            // 複数ポジション（ご飯・汁物など）の配列データがある場合
            if (shape['positions'] != null && shape['positions'] is List) {
              final List<dynamic> positions = shape['positions'];
              for (var pos in positions) {
                if (pos is! Map) continue;
                final double cx = ((pos['center_x'] ?? 0.5) as num).toDouble() * size.width;
                final double cy = ((pos['center_y'] ?? 0.5) as num).toDouble() * size.height;
                final double r = ((pos['radius'] ?? 0.1) as num).toDouble() * (size.width < size.height ? size.width : size.height);
                _drawDashedCircle(canvas, Offset(cx, cy), r, shapePaint);
              }
            } else {
              // 単一の円・楕円形データのパース
              final double cx = ((shape['center_x'] ?? 0.5) as num).toDouble() * size.width;
              final double cy = ((shape['center_y'] ?? 0.5) as num).toDouble() * size.height;
              
              // radius_x/y、radius、width/height のどの表記でも安全に取得する
              double rx = 0.0;
              double ry = 0.0;
              if (shape['radius_x'] is num) {
                rx = (shape['radius_x'] as num).toDouble() * size.width;
                ry = (shape['radius_y'] is num) ? (shape['radius_y'] as num).toDouble() * size.height : rx;
              } else if (shape['radius'] is num) {
                rx = (shape['radius'] as num).toDouble() * (size.width < size.height ? size.width : size.height);
                ry = rx;
              } else {
                rx = ((shape['width'] ?? 0.4) as num).toDouble() * size.width / 2;
                ry = ((shape['height'] ?? 0.4) as num).toDouble() * size.height / 2;
              }

              final rect = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
              _drawDashedArc(canvas, rect, 0, 2 * 3.14159265, shapePaint);

              // 固体の真円ターゲット（focus_target_spotなど）は点線ではなく実線で描く
              if (shape['style'] == 'solid_circle') {
                final solidPaint = Paint()
                  ..color = paint.color
                  ..strokeWidth = shapePaint.strokeWidth
                  ..style = PaintingStyle.stroke;
                canvas.drawCircle(Offset(cx, cy), rx, solidPaint);
              }
            }
          }

          // --- B. 多角形・長方形・パース線 (points配列を順に結ぶ) ---
          else if (shape['points'] != null && shape['points'] is List) {
            final List<dynamic> pointsData = shape['points'];
            if (pointsData.length >= 2) {
              final List<Offset> offsets = pointsData.map((p) {
                final double px = ((p['x'] ?? 0.0) as num).toDouble() * size.width;
                final double py = ((p['y'] ?? 0.0) as num).toDouble() * size.height;
                return Offset(px, py);
              }).toList();

              // 点線を繋げて多角形を描画（お膳外枠、お弁当箱立体、鳥居など）
              for (int i = 0; i < offsets.length; i++) {
                final Offset startPt = offsets[i];
                // 最後の点なら最初の点に繋ぐ（閉じられた多角形）、それ以外は次の点へ
                final Offset endPt = (i == offsets.length - 1) ? offsets[0] : offsets[i + 1];
                _drawDashedLine(canvas, startPt, endPt, shapePaint);
              }
            }
          }

          // --- C. 直線データ (start / end のペア) ---
          else if (shape['start'] != null && shape['end'] != null) {
            final Map<dynamic, dynamic> st = shape['start'] is Map ? shape['start'] : {};
            final Map<dynamic, dynamic> ed = shape['end'] is Map ? shape['end'] : {};
            
            final double x1 = ((st['x'] ?? 0.0) as num).toDouble() * size.width;
            final double y1 = ((st['y'] ?? 0.0) as num).toDouble() * size.height;
            final double x2 = ((ed['x'] ?? 0.0) as num).toDouble() * size.width;
            final double y2 = ((ed['y'] ?? 0.0) as num).toDouble() * size.height;

            _drawDashedLine(canvas, Offset(x1, y1), Offset(x2, y2), shapePaint);
          }

          // --- D. 単一の水平ガイド線 (y_position指定) ---
          else if (shape['y_position'] is num) {
            final double y = (shape['y_position'] as num).toDouble() * size.height;
            _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), shapePaint);
          }

          // --- E. 滝の平行線などの特別な平行ライン (left_x / right_x 指定) ---
          else if (shape['left_x'] is num && shape['right_x'] is num) {
            final double lx = (shape['left_x'] as num).toDouble() * size.width;
            final double rx = (shape['right_x'] as num).toDouble() * size.width;
            final double topY = ((shape['top_y'] ?? 0.0) as num).toDouble() * size.height;
            final double botY = ((shape['bottom_y'] ?? 1.0) as num).toDouble() * size.height;

            _drawDashedLine(canvas, Offset(lx, topY), Offset(lx, botY), shapePaint);
            _drawDashedLine(canvas, Offset(rx, topY), Offset(rx, botY), shapePaint);
          }

          // --- F. 神社などの放射パース収束線 (vanishing_point指定) ---
          else if (shape['vanishing_point'] != null && shape['lines'] != null && shape['lines'] is List) {
            final Map<dynamic, dynamic> vp = shape['vanishing_point'] is Map ? shape['vanishing_point'] : {};
            final double vpx = ((vp['x'] ?? 0.5) as num).toDouble() * size.width;
            final double vpy = ((vp['y'] ?? 0.5) as num).toDouble() * size.height;
            
            final List<dynamic> vLines = shape['lines'];
            for (var vLine in vLines) {
              if (vLine is! Map) continue;
              final double sx = ((vLine['start_x'] ?? 0.0) as num).toDouble() * size.width;
              final double sy = ((vLine['start_y'] ?? 0.0) as num).toDouble() * size.height;
              _drawDashedLine(canvas, Offset(sx, sy), Offset(vpx, vpy), shapePaint);
            }
          }

          // --- G. 境界四角形 (bounds指定: 人影シルエットやランドマークなど) ---
          else if (shape['bounds'] != null && shape['bounds'] is Map) {
            final Map<dynamic, dynamic> bounds = shape['bounds'];
            final double left = ((bounds['left'] ?? 0.0) as num).toDouble() * size.width;
            final double top = ((bounds['top'] ?? 0.0) as num).toDouble() * size.height;
            final double right = ((bounds['right'] ?? 1.0) as num).toDouble() * size.width;
            final double bottom = ((bounds['bottom'] ?? 1.0) as num).toDouble() * size.height;

            final rect = Rect.fromLTRB(left, top, right, bottom);
            _drawDashedRect(canvas, rect, shapePaint);

            // もし「人物の頭（head_radius）」などの詳細パラメタがあれば追加描画
            if (shape['head_radius'] is num) {
              final double cx = ((shape['center_x'] ?? 0.5) as num).toDouble() * size.width;
              final double cy = ((shape['center_y'] ?? 0.5) as num).toDouble() * size.height;
              final double hr = (shape['head_radius'] as num).toDouble() * (size.width < size.height ? size.width : size.height);
              _drawDashedCircle(canvas, Offset(cx, cy), hr, shapePaint);
            }
          }
        }
      }
    } catch (e, stacktrace) {
      debugPrint('GuidePainter JSONデコード・描画エラー回避: $e');
      debugPrint('スタックトレース: $stacktrace');
      
      // 万が一のエラー時は、薄い三分割線だけを絶対に表示してUXを担保する
      final errorGridPaint = Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..strokeWidth = paint.strokeWidth
        ..style = paint.style;
      _drawThirdsGrid(canvas, size, errorGridPaint);
    }
  }

  // --- なぞり線を表現するためのカスタム描画関数 ---

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    if (radius <= 0) return;
    _drawDashedArc(canvas, Rect.fromCircle(center: center, radius: radius), 0, 2 * 3.14159265, paint);
  }

  void _drawDashedArc(Canvas canvas, Rect rect, double startAngle, double sweepAngle, Paint paint) {
    if (rect.width <= 0 || rect.height <= 0) return;
    const int dashCount = 40;
    final double dashAngle = sweepAngle / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      canvas.drawArc(rect, startAngle + (i * dashAngle), dashAngle, false, paint);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    if (rect.width <= 0 || rect.height <= 0) return;
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 10;
    const double dashSpace = 8;
    
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = Offset(dx, dy).distance;
    
    if (distance == 0 || distance.isNaN) return;

    final int dashCount = (distance / (dashWidth + dashSpace)).floor();
    if (dashCount <= 0) return;
    
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