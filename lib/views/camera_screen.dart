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

  // 🌟 ズーム手動調整用の変数
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // 超広角・望遠を避けて「標準等倍レンズ」を強制選択するロジック
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
              (c) => !c.name.toLowerCase().contains('wide') && !c.name.toLowerCase().contains('ultrawide') && !c.name.toLowerCase().contains('telephoto'),
              orElse: () => backCameras.first,
            );
          } else {
            selectedCamera = backCameras.first;
          }
        } else {
          selectedCamera = _cameras!.first;
        }

        // Appleの標準的なデフォルトに合わせ、安定した画角を得るため ResolutionPreset.high を指定
        _controller = CameraController(
          selectedCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _controller!.initialize();

        // 初期化成功後にカメラデバイスのズーム可能範囲を取得
        if (mounted) {
          _minZoomLevel = await _controller!.getMinZoomLevel();
          _maxZoomLevel = await _controller!.getMaxZoomLevel();
          if (_maxZoomLevel > 8.0) _maxZoomLevel = 8.0; // 操作しやすくするため上限を8倍に制限
          
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('カメラの初期化エラー: $e');
    }
  }

  // 🌟 ズーム倍率を変更する関数
  Future<void> _setZoom(double value) async {
    if (_controller == null || !_isCameraInitialized) return;
    if (value < _minZoomLevel) value = _minZoomLevel;
    if (value > _maxZoomLevel) value = _maxZoomLevel;

    try {
      await _controller!.setZoomLevel(value);
      setState(() {
        _currentZoom = value;
      });
    } catch (e) {
      debugPrint('ズーム設定エラー: $e');
    }
  }

  // 🌟🌟🌟 【修正】厳密な4:3（または3:4）比率で見た目通りに切り抜いて保存するWeb保存関数 🌟🌟🌟
  Future<void> _saveAndCropImageWeb(XFile file, bool isLandscape) async {
    try {
      final Uint8List imageBytes = await file.readAsBytes();
      final blob = html.Blob([imageBytes], 'image/jpeg');
      final originalUrl = html.Url.createObjectUrlFromBlob(blob);

      final html.ImageElement img = html.ImageElement();
      img.src = originalUrl;
      await img.onLoad.first;

      // Webカメラの生の出力解像度
      final int imgW = img.naturalWidth;
      final int imgH = img.naturalHeight;

      final html.CanvasElement canvas = html.CanvasElement();
      final html.CanvasRenderingContext2D ctx = canvas.context2D;

      // ガイドラインおよびプレビューの仕様に完全追従する「4:3」の固定比率ターゲット
      final double targetAspectRatio = isLandscape ? (4.0 / 3.0) : (3.0 / 4.0);

      if (isLandscape) {
        // 【横向き撮影時】生データから綺麗に中央4:3を切り出す
        int cropW = imgW;
        int cropH = (cropW / targetAspectRatio).round();
        
        if (cropH > imgH) {
          cropH = imgH;
          cropW = (imgH * targetAspectRatio).round();
        }

        int startX = ((imgW - cropW) / 2).round();
        int startY = ((imgH - cropH) / 2).round();

        canvas.width = cropW;
        canvas.height = cropH;
        ctx.drawImageScaledFromSource(img, startX, startY, cropW, cropH, 0, 0, cropW, cropH);
      } else {
        // 【縦向き撮影時】生データの横長データから「中央の3:4（縦長）領域」を抽出
        int srcH = imgH;
        int srcW = (srcH * targetAspectRatio).round(); // ターゲット比率(3/4)を掛けて縦長幅を算出
        
        if (srcW > imgW) {
          srcW = imgW;
          srcH = (imgW / targetAspectRatio).round();
        }

        int startX = ((imgW - srcW) / 2).round();
        int startY = ((imgH - srcH) / 2).round();

        // 最終出力される画像サイズ（3:4の縦長形に確定）
        canvas.width = srcW;
        canvas.height = srcH;

        // 余計な回転を挟まず、生データの該当中央エリアをそのまま縦長にフィッティングして描画
        ctx.drawImageScaledFromSource(img, startX, startY, srcW, srcH, 0, 0, srcW, srcH);
      }

      final String dataUrl = canvas.toDataUrl('image/jpeg', 0.9);
      _downloadImageWeb(dataUrl);

      html.Url.revokeObjectUrl(originalUrl);
    } catch (e) {
      debugPrint('Webクロップ・保存エラー: $e');
    }
  }

  void _downloadImageWeb(String dataUrl) {
    final anchor = html.AnchorElement(href: dataUrl)
      ..setAttribute("download", "guide_photo_${DateTime.now().millisecondsSinceEpoch}.jpg")
      ..style.display = 'none';
    
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
  }

  bool _isRecommendLandscape() {
    final text = '${widget.theme.title} ${widget.theme.message}'.toLowerCase();
    if (text.contains('俯瞰') || text.contains('真上') || text.contains('縦')) {
      return false; // 縦向き推奨
    }
    if (text.contains('横') || text.contains('シズル') || text.contains('端に寄せる')) {
      return true; // 横向き推奨
    }
    return false; 
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
    final bool isCurrentlyLandscape = screenSize.width > screenSize.height;

    final bool recommendLandscape = _isRecommendLandscape();
    final bool isMatchingOrientation = isCurrentlyLandscape == recommendLandscape;

    // 🌟🌟🌟 【重要修正】プレビュー表示も厳格に「4:3」または「3:4」に固定 🌟🌟🌟
    // 画面いっぱいに間延びさせず、正確な比率のプレビュー枠の中に、お弁当枠やランドマークガイドを表示させます。
    final double cameraAspect = isCurrentlyLandscape ? (4.0 / 3.0) : (3.0 / 4.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false, bottom: false, left: false, right: false,
        child: GestureDetector(
          // 画面ピンチイン・アウトでスムーズにハードウェアズームを調整
          onScaleUpdate: (ScaleUpdateDetails details) {
            if (details.scale != 1.0) {
              double zoomDelta = details.scale > 1.0 ? 0.03 : -0.03;
              _setZoom(_currentZoom + zoomDelta);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 【1】 🌟 カメラ映像（アスペクト比を厳格に4:3または3:4に固定して中央配置）
              Positioned.fill(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: cameraAspect,
                    child: CameraPreview(
                      _controller!,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

              // 【2】 🌟 【重要修正】設計データ（複合形状・ライン等）を丸ごと引き渡す構造に変更 🌟
              // 4:3に固定された上のCameraPreviewと完全に同じ枠に重なるように配置
              Positioned.fill(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: cameraAspect,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: GuidePainter(
                          // 🔴 旧構造の単一キー指定（shapeType / shapeParams）を廃止し、
                          // お弁当箱、ケーキ、参道等の全形状・ライン線が含まれた最新JSON（Mapオブジェクト）を丸ごと注入
                          designGuide: widget.theme.designGuide,
                          isHorizontal: isCurrentlyLandscape,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 【3】 手動ズームコントロール（スライダーUI）
              _buildZoomSlider(isCurrentlyLandscape),

              // 【4】 画面上部：タイトル・推奨向きアナウンス・メッセージ
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: MediaQuery.of(context).padding.left + 16,
                right: isCurrentlyLandscape ? 160 : 16,
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
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMatchingOrientation 
                            ? Colors.green.withOpacity(0.85)
                            : Colors.orange.withOpacity(0.85),
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

              // 【5】 シャッターボタン
              isCurrentlyLandscape
                  ? Positioned(
                      right: MediaQuery.of(context).padding.right + 12,
                      top: 0,
                      bottom: 0,
                      width: 140,
                      child: Center(
                        child: _buildShutterButton(context, isCurrentlyLandscape),
                      ),
                    )
                  : Positioned(
                      bottom: MediaQuery.of(context).padding.bottom + 24,
                      left: 0,
                      right: 0,
                      height: 140,
                      child: Center(
                        child: _buildShutterButton(context, isCurrentlyLandscape),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ズームイン・アウトを手動で行うためのスライダーUI部品
  Widget _buildZoomSlider(bool isLandscape) {
    if (_maxZoomLevel <= _minZoomLevel) return const SizedBox.shrink();

    final sliderWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.zoom_out, color: Colors.white70, size: 18),
        SizedBox(
          width: 140,
          child: Slider(
            value: _currentZoom,
            min: _minZoomLevel,
            max: _maxZoomLevel,
            activeColor: Colors.green,
            inactiveColor: Colors.white24,
            onChanged: (value) => _setZoom(value),
          ),
        ),
        const Icon(Icons.zoom_in, color: Colors.white70, size: 18),
        const SizedBox(width: 6),
        Text(
          '${_currentZoom.toStringAsFixed(1)}x',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );

    return Positioned(
      bottom: isLandscape ? 20 : MediaQuery.of(context).padding.bottom + 160,
      left: isLandscape ? MediaQuery.of(context).padding.left + 24 : 0,
      right: isLandscape ? null : 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: sliderWidget,
        ),
      ),
    );
  }

  // シャッターボタンUI
  Widget _buildShutterButton(BuildContext context, bool isCurrentlyLandscape) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        try {
          final XFile file = await _controller!.takePicture();
          
          // 【修正】画面比率依存を撤廃し、厳密な4:3または3:4（縦横状態）を直接渡して切り出し保存
          await _saveAndCropImageWeb(file, isCurrentlyLandscape);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('撮影完了！4:3の正確な比率で保存しました。'),
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
        width: 90,
        height: 90,
        alignment: Alignment.center,
        color: Colors.transparent,
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
    );
  }
}