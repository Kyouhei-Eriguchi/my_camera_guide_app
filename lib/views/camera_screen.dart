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

  // 🌟🌟🌟 【大幅強化】画面で見えている比率（スマホ画面）に合わせて画像を中央で切り抜く関数 🌟🌟🌟
  Future<void> _saveAndCropImageWeb(XFile file, double screenAspectRatio) async {
    try {
      final Uint8List imageBytes = await file.readAsBytes();
      final blob = html.Blob([imageBytes], 'image/jpeg');
      final originalUrl = html.Url.createObjectUrlFromBlob(blob);

      // 1. 画像エレメントを生成して読み込む
      final html.ImageElement img = html.ImageElement();
      img.src = originalUrl;

      await img.onLoad.first;

      // 2. 元画像のサイズを取得
      final int imgW = img.naturalWidth;
      final int imgH = img.naturalHeight;

      // 3. 画面の比率（縦/横）に合わせて、元画像から切り出すべきサイズを計算
      // ※Webカメラの画角は通常横長(W > H)で撮影されるため、スマホ縦画面(1/screenAspectRatio)に合わせます
      double targetRatio = 1 / screenAspectRatio; 
      
      int cropW = imgW;
      int cropH = (imgW / targetRatio).round();

      if (cropH > imgH) {
        cropH = imgH;
        cropW = (imgH * targetRatio).round();
      }

      // 中央から切り抜くための開始位置(X, Y)
      int startX = ((imgW - cropW) / 2).round();
      int startY = ((imgH - cropH) / 2).round();

      // 4. ブラウザのCanvasを使って切り抜きを実行
      final html.CanvasElement canvas = html.CanvasElement(width: cropW, height: cropH);
      final html.CanvasRenderingContext2D ctx = canvas.context2D;
      
      ctx.drawImageScaledFromSource(
        img,
        startX, startY, cropW, cropH, // 元画像の切り抜き範囲
        0, 0, cropW, cropH            // キャンバスへの描画位置
      );

      // 5. 切り抜いた Canvas から新しい JPEG を生成してダウンロード
      final String dataUrl = canvas.toDataUrl('image/jpeg', 0.9);
      
      final anchor = html.AnchorElement(href: dataUrl)
        ..setAttribute("download", "guide_photo_${DateTime.now().millisecondsSinceEpoch}.jpg")
        ..style.display = 'none';
      
      html.document.body?.children.add(anchor);
      anchor.click();

      // 6. 後片付け
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(originalUrl);
    } catch (e) {
      debugPrint('Webクロップ・保存エラー: $e');
    }
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
    // スマホ画面の縦横比（これに合わせて写真を切り抜きます）
    final double screenAspectRatio = screenSize.width / screenSize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            // 【1】 🌟カメラ映像（coverに戻して、スマホ画面いっぱいにフル表示！）
            Positioned.fill(
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.cover, // 🌟フル画面表示に変更！
                  child: SizedBox(
                    width: screenSize.width,
                    height: screenSize.width * _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
            ),

            // 【2】 なぞり書きガイド（フル画面の正確な中央に配置されます）
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: GuidePainter(
                    shapeType: widget.theme.designGuide['shape_type'] ?? 'default',
                    shapeParams: widget.theme.designGuide['shape_params'] ?? {},
                    isHorizontal: false,
                  ),
                ),
              ),
            ),

            // 【3】 画面上部：タイトルと解説メッセージ
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
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
                  const SizedBox(height: 12),
                  Container(
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
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 【4】 画面下部：シャッターボタン
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 32,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    try {
                      // ① パシャリと撮影（この時点では広角の全体データ）
                      final XFile file = await _controller!.takePicture();
                      
                      // ② 画面比率を渡して、自動切り抜き保存を実行！
                      await _saveAndCropImageWeb(file, screenAspectRatio);
                      
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
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