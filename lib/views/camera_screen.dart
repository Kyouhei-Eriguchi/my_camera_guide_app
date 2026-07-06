import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:universal_html/html.dart' as html; // 🌟 Web保存用のパッケージ
import 'dart:typed_data';
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

  // 🌟🌟🌟 【修正】超広角レンズを避けて「標準等倍レンズ」を強制選択するロジック 🌟🌟🌟
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras != null && _cameras!.isNotEmpty) {
        // 1. まず背面カメラだけをすべて集める
        final backCameras = _cameras!.where(
          (camera) => camera.lensDirection == CameraLensDirection.back
        ).toList();

        CameraDescription selectedCamera;

        if (backCameras.isNotEmpty) {
          // 複数カメラがある場合、超広角（wide / ultrawide）という名前を含まない「標準レンズ」を探す
          if (backCameras.length > 1) {
            selectedCamera = backCameras.firstWhere(
              (c) => !c.name.toLowerCase().contains('wide') && !c.name.toLowerCase().contains('ultrawide'),
              orElse: () => backCameras[1], // 見つからなければ2番目（標準の可能性高）を選択
            );
          } else {
            selectedCamera = backCameras.first;
          }
        } else {
          selectedCamera = _cameras!.first;
        }

        // 2. 決定した標準カメラを最高解像度（max）で起動
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

  // 🌟🌟🌟 【残存】Webブラウザに保存先を選ばせてダウンロードさせる関数 🌟🌟🌟
  Future<void> _saveImageWeb(XFile file) async {
    try {
      // 1. 撮影された画像データをバイト配列（デジタルデータ）として読み込む
      final Uint8List imageBytes = await file.readAsBytes();

      // 2. ブラウザが理解できるデータ（Blob）に変換する
      final blob = html.Blob([imageBytes], 'image/jpeg');
      final url = html.Url.createObjectUrlFromBlob(blob);

      // 3. ブラウザの裏側で「見えないダウンロードリンク」を生成する
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "guide_photo_${DateTime.now().millisecondsSinceEpoch}.jpg")
        ..style.display = 'none';
      
      html.document.body?.children.add(anchor);

      // 4. 自動でそのリンクをクリックさせることで、スマホの「どこに保存しますか？」を引き出す
      anchor.click();

      // 5. 後片付け
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('Web保存エラー: $e');
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            // 【1】 カメラ映像
            Positioned.fill(
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: screenSize.width,
                    height: screenSize.width * _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
            ),

            // 【2】 なぞり書きガイド
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

            // 【3】 画面上部：タイトルと解説メッセージ（位置OK判定済み）
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

            // 【4】 画面下部：シャッターボタン（ポツンと独立）
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 32,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    try {
                      // ① パシャリと撮影
                      final XFile file = await _controller!.takePicture();
                      
                      // ② Web保存関数を呼び出し（保存先ポップアップを誘導）
                      await _saveImageWeb(file);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('撮影完了！保存先を確認してください。'),
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