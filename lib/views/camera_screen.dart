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

        // 🌟【重要】maxだとブラウザが勝手に望遠レンズを掴むため、標準画角（引き）になるhighに変更
        _controller = CameraController(
          selectedCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _controller!.initialize();

        // 🌟 初期化成功後にズームの可能範囲を取得
        if (mounted) {
          _minZoomLevel = await _controller!.getMinZoomLevel();
          _maxZoomLevel = await _controller!.getMaxZoomLevel();
          if (_maxZoomLevel > 10.0) _maxZoomLevel = 10.0; // 操作性のため上限を10倍に制限
          
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

  // 🌟🌟🌟 【修正】画面の引き（Fit状態）と手動ズームを完璧に連動させたクロップ関数 🌟🌟🌟
  Future<void> _saveAndCropImageWeb(XFile file, double screenAspectRatio, bool isLandscape, double previewScale) async {
    try {
      final Uint8List imageBytes = await file.readAsBytes();
      final blob = html.Blob([imageBytes], 'image/jpeg');
      final originalUrl = html.Url.createObjectUrlFromBlob(blob);

      final html.ImageElement img = html.ImageElement();
      img.src = originalUrl;
      await img.onLoad.first;

      // Webカメラの生の出力解像度（常に横長 imgW > imgH）
      final int imgW = img.naturalWidth;
      final int imgH = img.naturalHeight;

      if (isLandscape) {
        // 【横向き撮影時】
        int cropW = (imgW / previewScale).round();
        int cropH = (cropW / screenAspectRatio).round();
        
        if (cropH > imgH) {
          cropH = imgH;
          cropW = (imgH * screenAspectRatio).round();
        }

        int startX = ((imgW - cropW) / 2).round();
        int startY = ((imgH - cropH) / 2).round();

        final html.CanvasElement canvas = html.CanvasElement()
          ..width = cropW
          ..height = cropH;
        final html.CanvasRenderingContext2D ctx = canvas.context2D;
        ctx.drawImageScaledFromSource(img, startX, startY, cropW, cropH, 0, 0, cropW, cropH);

        final String dataUrl = canvas.toDataUrl('image/jpeg', 0.9);
        _downloadImageWeb(dataUrl);
      } else {
        // 【縦向き撮影時】
        int srcH = (imgH / previewScale).round();
        int srcW = (srcH * screenAspectRatio).round();
        
        if (srcW > imgW) {
          srcW = imgW;
          srcH = (imgW / screenAspectRatio).round();
        }

        int startX = ((imgW - srcW) / 2).round();
        int startY = ((imgH - srcH) / 2).round();

        // 🌟【重要修正】Canvas自体のサイズをあべこべにせず「縦長」として正しく直して定義
        final html.CanvasElement canvas = html.CanvasElement()
          ..width = srcH   
          ..height = srcW; 
        
        final html.CanvasRenderingContext2D ctx = canvas.context2D;

        // Canvasの中心を軸にして回転させる
        ctx.translate(canvas.width! / 2.0, canvas.height! / 2.0);
        ctx.rotate(90 * 3.1415926535 / 180); // 90度時計回りに回転

        // 縦長の比率を維持したまま、切り出した中心領域を正しくマッピング
        ctx.drawImageScaledFromSource(
          img, 
          startX, startY, srcW, srcH, 
          -srcW / 2, -srcH / 2, srcW, srcH
        );

        final String dataUrl = canvas.toDataUrl('image/jpeg', 0.9);
        _downloadImageWeb(dataUrl);
      }

      html.Url.revokeObjectUrl(originalUrl);
    } catch (e) {
      debugPrint('Webクロップ・保存エラー: $e');
    }
  }

  // Web用のダウンロード処理共通化
  void _downloadImageWeb(String dataUrl) {
    final anchor = html.AnchorElement(href: dataUrl)
      ..setAttribute("download", "guide_photo_${DateTime.now().millisecondsSinceEpoch}.jpg")
      ..style.display = 'none';
    
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
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
    final bool isCurrentlyLandscape = screenSize.width > screenSize.height;
    final double screenAspectRatio = screenSize.width / screenSize.height;

    // 推奨される向きの取得
    final bool recommendLandscape = _isRecommendLandscape();
    // 現在の状態が推奨通りになっているか
    final bool isMatchingOrientation = isCurrentlyLandscape == recommendLandscape;

    // 🌟🌟🌟 【重要修正】過剰にズームアップせず、本来の「引きの絵」が画面内に収まるように縮小計算 🌟🌟🌟
    final double cameraAspectRatio = _controller!.value.aspectRatio;
    double scale = 1.0;
    if (isCurrentlyLandscape) {
      scale = screenSize.width / (screenSize.height * cameraAspectRatio);
    } else {
      scale = screenSize.height / (screenSize.width * cameraAspectRatio);
    }
    // 🌟 1.0より大きい（はみ出す）場合、逆数を取って「画面内に引きで全体が収まるサイズ」に補正
    if (scale > 1.0) scale = 1.0 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false, bottom: false, left: false, right: false,
        child: GestureDetector(
          // 🌟 画面全体のピンチイン・アウトジェスチャーでズームを操作できるようにする
          onScaleUpdate: (ScaleUpdateDetails details) {
            if (details.scale != 1.0) {
              double zoomDelta = details.scale > 1.0 ? 0.04 : -0.04;
              _setZoom(_currentZoom + zoomDelta);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 【1】 カメラ映像（引きの状態で、アスペクト比を維持して画面内に綺麗に収める）
              Positioned.fill(
                child: Center(
                  child: Transform.scale(
                    scale: scale,
                    child: CameraPreview(_controller!),
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

              // 【3】 🌟 手動ズームコントロール（スライダーUI）の設置
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
                    
                    // カメラの推奨向き（縦 or 横）を表示するナビゲーションバッジ
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

                    // 解説メッセージ
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
                        child: _buildShutterButton(context, screenAspectRatio, isCurrentlyLandscape, scale),
                      ),
                    )
                  : Positioned(
                      bottom: MediaQuery.of(context).padding.bottom + 24,
                      left: 0,
                      right: 0,
                      height: 140,
                      child: Center(
                        child: _buildShutterButton(context, screenAspectRatio, isCurrentlyLandscape, scale),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 ズームイン・アウトを手動で行うためのスライダーUI部品
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
      // 縦向き時はボタン上部、横向き時は画面の左端付近にレイアウト
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

  // タップ判定を確実にするためHitTestBehaviorを適用した共通のシャッターボタンUI
  Widget _buildShutterButton(BuildContext context, double screenAspectRatio, bool isCurrentlyLandscape, double previewScale) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        try {
          // ① パシャリと撮影
          final XFile file = await _controller!.takePicture();
          
          // ② 画面比率、回転状態、およびズームスケール（引き状態のscale）を渡して完全に見た目通り保存
          await _saveAndCropImageWeb(file, screenAspectRatio, isCurrentlyLandscape, previewScale);
          
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