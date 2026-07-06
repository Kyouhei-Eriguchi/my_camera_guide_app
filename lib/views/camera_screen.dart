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

            // 🌟🌟🌟 【3】 画面上部：タイトルと解説メッセージをまとめて配置 🌟🌟🌟
            Positioned(
              top: MediaQuery.of(context).padding.top + 16, // ノッチ（画面の切り欠き）の下辺りから開始
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // タイトル行（戻るボタンと並べる）
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
                  const SizedBox(height: 12), // タイトルとメッセージの隙間

                  // 解説メッセージ（上部の空きスペースに配置！）
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

            // 🌟🌟🌟 【4】 画面下部：シャッターボタンのみですっきり配置 🌟🌟🌟
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 32,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    try {
                      await _controller!.takePicture();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('バシッと型が決まりました！'),
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