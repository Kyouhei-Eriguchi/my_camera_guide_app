import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/theme_model.dart';

class ThemeNotifier extends ChangeNotifier {
  List<CameraTheme> _allThemes = [];
  List<CameraTheme> _filteredThemes = [];
  
  String _selectedWhat = '';
  bool _isLoading = true;

  // 外部の画面（View）から参照するためのゲッター
  List<CameraTheme> get filteredThemes => _filteredThemes;
  String get selectedWhat => _selectedWhat;
  bool get isLoading => _isLoading;

  // アプリ起動時にJSONファイルを読み込む関数
  Future<void> loadThemes() async {
    try {
      _isLoading = true;
      notifyListeners();

      // assetsからJSONの文字列を読み込む
      final String jsonString = await rootBundle.loadString('assets/json/camera_themes.json');
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

      // JSONデータからCameraThemeのリストに変換
      _allThemes = jsonList
          .map((jsonItem) => CameraTheme.fromJson(jsonItem as Map<String, dynamic>))
          .toList();

      // 初期状態ではすべてのテーマを表示
      _filteredThemes = List.from(_allThemes);
    } catch (e) {
      debugPrint('JSON読み込みエラー: $e');
    } finally {
      _isLoading = false;
      notifyListeners(); // 画面を更新
    }
  }

  // 「何を撮る？（What）」が選ばれたときに、目的（How）の選択肢を絞り込む関数
  void selectWhat(String what) {
    _selectedWhat = what;
    
    if (what.isEmpty) {
      _filteredThemes = List.from(_allThemes);
    } else {
      // JSONの中のpurpose_whatに含まれているかでフィルタリング
      _filteredThemes = _allThemes
          .where((theme) => theme.purposeWhat.contains(what))
          .toList();
    }
    
    // 選ばれた数（パワー）が多い順に並び替える（Googleマップのレビュー人数ロジック）
    _filteredThemes.sort((a, b) => b.initialPower.compareTo(a.initialPower));
    
    notifyListeners(); // 画面を更新
  }

  // カテゴリ一覧を取得する（ホーム画面のタブやボタン生成用）
  List<String> get categories {
    // 料理、人物、風景 などの重複を排除してリスト化
    final set = _allThemes.map((t) {
      if (t.purposeWhat.contains('料理')) return '料理';
      if (t.purposeWhat.contains('家族') || t.purposeWhat.contains('人物')) return '人物・家族';
      return 'その他';
    }).toSet();
    return set.toList();
  }
}