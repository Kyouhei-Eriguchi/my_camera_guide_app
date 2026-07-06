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

  // 🌟 画面の向き（縦・横）に合わせて画像を中央で切り抜く関数
  Future<void> _saveAndCropImageWeb(XFile file, double screenAspectRatio, bool isLandscape) async {
    try {
      final Uint8List imageBytes = await file.readAsBytes();
      final blob = html.Blob([imageBytes], 'image/jpeg');
      final originalUrl = html.Url.createObjectUrlFromBlob(blob);

      final html.ImageElement img = html.ImageElement();
      img.src = originalUrl;
      await img.onLoad.first;

      final int imgW = img.naturalWidth;
      final int imgH = img.naturalHeight;

      // 画面が横向きならそのままの比率、縦向きなら逆数をターゲットにする
      double targetRatio = isLandscape ? screenAspectRatio : (1 / screenAspectRatio);
      
      int cropW = imgW;
      int cropH = (imgW / targetRatio).round();

      if (cropH > imgH) {
        cropH = imgH;
        cropW = (imgH * targetRatio).round();
      }

      int startX = ((imgW - cropW) / 2).round();
      int startY = ((imgH - cropH) / 2).round();

      final html.CanvasElement canvas = html.CanvasElement(width: cropW, height: cropH);
      final html.CanvasRenderingContext2D ctx = canvas.context2D;
      
      ctx.drawImageScaledFromSource(img, startX, startY, cropW, cropH, 0, 0, cropW, cropH);

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

  // 🌟 タイトルやメッセージから、縦向き撮影・横向き撮影のどちらを推奨しているかを判定するロジック
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
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: Stack(
          children: [
            // 【1】 カメラ映像（FittedBoxを最適化し、縦でも横でも画面全体を黒帯なしで覆い尽くします）
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
              right: MediaQuery.of(context).padding.right + 16,
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
                  
                  // 🌟🌟🌟 カメラの推奨向き（縦 or 横）を表示するナビゲーションバッジ 🌟🌟🌟
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

                  // 解説メッセージ（横向き時に画面を塞ぎすぎないよう、最大高さを少しセーブ）
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

            // 【4】 画面最下部：シャッターボタン（画面の回転状態に合わせて、常に確実にタップできる絶対座標へ配置）
            Positioned(
              bottom: isCurrentlyLandscape 
                  ? 20 
                  : (MediaQuery.of(context).padding.bottom + 32),
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
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
                    width: 72,
                    height: 72,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}