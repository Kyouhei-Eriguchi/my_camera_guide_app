import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:universal_html/html.dart' as html; // 🌟 Web用のパッケージ
import 'dart:typed_data';
import 'dart:async';
import '../../models/theme_model.dart';
import 'widgets/guide_painter.dart';

class CameraScreen extends StatefulWidget {
  final CameraTheme theme;

  const CameraScreen({super.key, required this.theme});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // 超広角レンズを避けて「標準等倍レンズ」を強制選択するロジック
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras != null && _cameras!.isNotEmpty) {
        final backCameras = _cameras!.where(
          (camera) => camera.lensDirection == CameraLensDirection.back
        ).toList();

        CameraDescription selectedCamera;

        if (backCameras.isNotEmpty) {
          if (backCameras.length > 1) {
            selectedCamera = backCameras.firstWhere(
              (c) => !c.name.toLowerCase().contains('wide') && !c.name.toLowerCase().contains('ultrawide'),
              orElse: () => backCameras[1],
            );
          } else {
            selectedCamera = backCameras.first;
          }
        } else {
          selectedCamera = _cameras!.first;
        }

        _controller = CameraController(
          selectedCamera,
          ResolutionPreset.max,
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('カメラの初期化エラー: $e');
    }
  }

  // 🌟🌟🌟 【修正】縦・横それぞれの撮影時、画面の見た目通りの向き・比率で保存するクロップ関数 🌟🌟🌟
  Future<void> _saveAndCropImageWeb(XFile file, double screenAspectRatio, bool isLandscape) async {
    try {
      final Uint8List imageBytes = await file.readAsBytes();
      final blob = html.Blob([imageBytes], 'image/jpeg');
      final originalUrl = html.Url.createObjectUrlFromBlob(blob);

      final html.ImageElement img = html.ImageElement();
      img.src = originalUrl;
      await img.onLoad.first;

      // Webカメラの生の出力解像度（通常はデバイスの向きに関わらず常に横長 imgW > imgH）
      final int imgW = img.naturalWidth;
      final int imgH = img.naturalHeight;

      int cropW, cropH;

      if (isLandscape) {
        // 【横向き撮影時】生データと同じ横長比率（screenAspectRatio）で切り抜く
        cropW = imgW;
        cropH = (imgW / screenAspectRatio).round();
        if (cropH > imgH) {
          cropH = imgH;
          cropW = (imgH * screenAspectRatio).round();
        }
      } else {
        // 【縦向き撮影時】生データの中心から、縦長画面の比率（1 / screenAspectRatio）で切り抜く
        cropH = imgH;
        cropW = (imgH * screenAspectRatio).round();
        if (cropW > imgW) {
          cropW = imgW;
          cropH = (imgW / screenAspectRatio).round();
        }
      }

      int startX = ((imgW - cropW) / 2).round();
      int startY = ((imgH - cropH) / 2).round();

      // キャンバスの初期設定
      final html.CanvasElement canvas = html.CanvasElement(width: cropW, height: cropH);
      final html.CanvasRenderingContext2D ctx = canvas.context2D;
      
      if (!isLandscape) {
        // 🌟 スマホ縦向きの場合は、横長の生データを縦長写真に変換するため、Canvasごと90度回転させる
        canvas.width = cropH; // 縦向き出力にするため幅と高さを反転
        canvas.height = cropW;
        
        // 🌟 【赤波線修正箇所】
        // universal_html の canvas.width/height は Null許容型 (int?) の場合があるため、
        // 明示的に `!` で非Null保証を行い、double型として安全に除算を行います。
        ctx.translate(canvas.width! / 2.0, canvas.height! / 2.0);
        ctx.rotate(90 * 3.1415926535 / 180); // 90度時計回りに回転
        
        ctx.drawImageScaledFromSource(
          img, 
          startX, startY, cropW, cropH, 
          -cropW / 2, -cropH / 2, cropW, cropH
        );
      } else {
        // 横向き撮影時はそのまま保存
        ctx.drawImageScaledFromSource(img, startX, startY, cropW, cropH, 0, 0, cropW, cropH);
      }

      final String dataUrl = canvas.toDataUrl('image/jpeg', 0.9);
      
      final anchor = html.AnchorElement(href: dataUrl)
        ..setAttribute("download", "guide_photo_${DateTime.now().millisecondsSinceEpoch}.jpg")
        ..style.display = 'none';
      
      html.document.body?.children.add(anchor);
      anchor.click();

      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(originalUrl);
    } catch (e) {
      debugPrint('Webクロップ・保存エラー: $e');
    }
  }

  // タイトルやメッセージから、縦向き撮影・横向き撮影のどちらを推奨しているかを判定するロジック
  bool _isRecommendLandscape() {
    final text = '${widget.theme.title} ${widget.theme.message}'.toLowerCase();
    if (text.contains('俯瞰') || text.contains('真上') || text.contains('縦')) {
      return false; // 縦向き推奨
    }
    if (text.contains('横') || text.contains('シズル') || text.contains('端に寄せる')) {
      return true; // 横向き推奨
    }
    return false; // デフォルトは縦向き推奨
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    // 🌟 現在のデバイスの画面が横向きかどうかをリアルタイム判定
    final bool isCurrentlyLandscape = screenSize.width > screenSize.height;
    final double screenAspectRatio = screenSize.width / screenSize.height;

    // 推奨される向きの取得
    final bool recommendLandscape = _isRecommendLandscape();
    // 現在の状態が推奨通りになっているか
    final bool isMatchingOrientation = isCurrentlyLandscape == recommendLandscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false, bottom: false, left: false, right: false,
        child: Stack(
          children: [
            // 【1】 カメラ映像（縦でも横でも画面全体を黒帯なしで覆い尽くします）
            Positioned.fill(
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: isCurrentlyLandscape 
                        ? screenSize.height * _controller!.value.aspectRatio 
                        : screenSize.width,
                    height: isCurrentlyLandscape 
                        ? screenSize.height 
                        : screenSize.width * _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
            ),

            // 【2】 なぞり書きガイド（画面の回転に合わせて自動追従）
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: GuidePainter(
                    shapeType: widget.theme.designGuide['shape_type'] ?? 'default',
                    shapeParams: widget.theme.designGuide['shape_params'] ?? {},
                    isHorizontal: isCurrentlyLandscape,
                  ),
                ),
              ),
            ),

            // 【3】 画面上部：タイトル・推奨向きアナウンス・メッセージ
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: MediaQuery.of(context).padding.left + 16,
              // 🌟横向き時は右側にボタンが来るため、メッセージ等が被らないよう右側の余白を大きく確保する
              right: isCurrentlyLandscape ? 120 : 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.6),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.theme.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // カメラの推奨向き（縦 or 横）を表示するナビゲーションバッジ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isMatchingOrientation 
                          ? Colors.green.withOpacity(0.85) // 推奨通りの向きなら緑
                          : Colors.orange.withOpacity(0.85), // 違う向きなら注意を促すオレンジ
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          recommendLandscape ? Icons.screen_rotation : Icons.stay_current_portrait,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          recommendLandscape 
                              ? (isMatchingOrientation ? '判定：横向き撮影（バッチリ！）' : 'おすすめ：スマホを【横向き】にしてください')
                              : (isMatchingOrientation ? '判定：縦向き撮影（バッチリ！）' : 'おすすめ：スマホを【縦向き】にしてください'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 解説メッセージ（横向き時に画面を塞ぎすぎないよう、最大高さをセーブ）
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: isCurrentlyLandscape ? 60 : 120,
                    ),
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          widget.theme.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 【4】 🌟🌟🌟 シャッターボタン（画面の向きに合わせて完全に独立させて配置） 🌟🌟🌟
            isCurrentlyLandscape
                ? Positioned(
                    // 🌟 横向きなら画面の右端（ライトニングやType-Cの端子・ケーブル側）中央に配置
                    right: MediaQuery.of(context).padding.right + 24,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _buildShutterButton(context, screenAspectRatio, isCurrentlyLandscape),
                    ),
                  )
                : Positioned(
                    // 縦向きなら画面の下部に配置
                    bottom: MediaQuery.of(context).padding.bottom + 32,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildShutterButton(context, screenAspectRatio, isCurrentlyLandscape),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // 🌟 タップ判定を確実にするためHitTestBehaviorを適用した共通のシャッターボタンUI
  Widget _buildShutterButton(BuildContext context, double screenAspectRatio, bool isCurrentlyLandscape) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // ボタン周辺の透明部分をタップしても確実に反応させる
      onTap: () async {
        try {
          // ① パシャリと撮影
          final XFile file = await _controller!.takePicture();
          
          // ② 画面比率と回転状態を渡して、自動切り抜き保存を実行！
          await _saveAndCropImageWeb(file, screenAspectRatio, isCurrentlyLandscape);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('撮影完了！画面通りのサイズで保存しました。'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          debugPrint('撮影エラー: $e');
        }
      },
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }
}