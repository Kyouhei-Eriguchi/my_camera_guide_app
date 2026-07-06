import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras != null && _cameras!.isNotEmpty) {
        final backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );

        _controller = CameraController(
          backCamera,
          ResolutionPreset.medium,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text('カメラを起動中...', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 【レイヤー1】 全面のカメラプレビュー映像
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),

          // 【レイヤー2】 「習字のなぞり線」を中央にオーバーレイ
          Positioned.fill(
            child: CustomPaint(
              painter: GuidePainter(
                shapeType: widget.theme.designGuide['shape_type'] ?? 'default',
                shapeParams: widget.theme.designGuide['shape_params'] ?? {},
                isHorizontal: false, // 将来的にセンサー連動
              ),
            ),
          ),

          // 🌟🌟🌟 【レイヤー3】 新・UIレイアウト（重なり解消） 🌟🌟🌟

          // 【修正点1】 メッセージボードを左上に配置（ガイドの邪魔をしない）
          Positioned(
            top: MediaQuery.of(context).padding.top + 16, // ステータスバーの下
            left: 16,
            right: 80, // 右側に閉じるボタン用のスペースを開ける
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.theme.title,
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.theme.message,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),

          // 【修正点2】 閉じるボタンを右上（メッセージの横）に独立して配置
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.5),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white), // アイコンを「close」に変更
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 【修正点3】 シャッターボタンは一番下に配置（中央は開ける）
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32, // ナビゲーションバーの上
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  try {
                    // シャッターを切って写真を一時保存（※Web版ではメモリ上に存在）
                    final XFile file = await _controller!.takePicture();
                    
                    // 🌟🌟🌟 【重要：写真保存の解決策】 🌟🌟🌟
                    // ここでWebブラウザに「写真データをダウンロードさせる」処理を追加します。
                    // 現状は保存されませんが、本番ではここのロジックを強化します。
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('バシッと型が決まりました！あとはお好みでレタッチしてね！'),
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
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}