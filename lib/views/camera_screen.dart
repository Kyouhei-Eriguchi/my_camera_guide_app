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

  // スマホのカメラモジュールを初期化する関数
  Future<void> _initializeCamera() async {
    try {
      // 使用可能なカメラ（背面・前面など）のリストを取得
      _cameras = await availableCameras();
      
      if (_cameras != null && _cameras!.isNotEmpty) {
        // 撮影者が迷わないよう、基本は「背面カメラ（back）」を優先選択
        final backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );

        // カメラコントローラーを設定（画質は標準〜高画質に設定）
        _controller = CameraController(
          backCamera,
          ResolutionPreset.medium,
          enableAudio: false, // 撮影ガイド用なので音声はオフ
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
    // 画面を閉じるときにカメラの資源をちゃんと解放する
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
          // 1. 全面のカメラプレビュー映像
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),

          // 2. 「習字のなぞり線」を映像の真上にオーバーレイ
          Positioned.fill(
            child: CustomPaint(
              painter: GuidePainter(
                shapeType: widget.theme.designGuide['shape_type'] ?? 'default',
                shapeParams: widget.theme.designGuide['shape_params'] ?? {},
                isHorizontal: false, // 将来的にセンサー値を入れて連動させます
              ),
            ),
          ),

          // 3. 上部の閉じるボタンとタイトル
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.5), // 🌟修正: 標準の半透明指定に変更
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.theme.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 40), // バランス用
              ],
            ),
          ),

          // 4. 下部のアドバイスメッセージとシャッターボタン
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 巨匠のアドバイスボード
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    widget.theme.message,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),
                
                // シャッターボタン
                GestureDetector(
                  onTap: () async {
                    try {
                      // シャッターを切って写真を一時保存
                      final XFile file = await _controller!.takePicture();
                      
                      // 撮影完了のポップアップ（レタッチへの余白を促す）
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar( // 🌟修正: constを追加
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
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.black,
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}