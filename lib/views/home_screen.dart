import 'package:flutter/material.dart';
import '../view_models/theme_notifier.dart';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ThemeNotifier _notifier = ThemeNotifier();

  @override
  void initState() {
    super.initState();
    // アプリ起動時にJSONデータをロードする
    _notifier.loadThemes();
    // データの変更を検知して画面を再描画する設定
    _notifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121212), // 暗めの高級感ある背景
      appBar: AppBar(
        title: const Text('記憶を記録するカメラガイド', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _notifier.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. 何を撮影しますか？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  // 「何を」を選ぶトップボタン
                  Row(
                    children: [
                      _buildWhatButton('料理', Icons.restaurant),
                      const SizedBox(width: 10),
                      _buildWhatButton('人物', Icons.people),
                      const SizedBox(width: 10),
                      _buildWhatButton('すべて', Icons.clear_all),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text('2. どう・どのように撮りたいですか？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('※ パワー（数値）が高いほど、多くの人に好まれる定番の型です', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  // 目的（How）のリスト
                  Expanded(
                    child: _notifier.filteredThemes.isEmpty
                        ? const Center(child: Text('該当するテーマがありません', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _notifier.filteredThemes.length,
                            itemBuilder: (context, index) {
                              final theme = _notifier.filteredThemes[index];
                              return Card(
                                color: const Color(0xff1e1e1e),
                                margin: const EdgeInsets.only(bottom: 12), // 🌟修正: EdgeInsets.onlyを使用
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // 🌟修正: 正しい大文字小文字表記
                                    children: [
                                      Expanded(
                                        child: Text(theme.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                      ),
                                      // パース数（人を寄せるパワー）のバッジ表示
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.initialPower > 1000 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: theme.initialPower > 1000 ? Colors.green : Colors.orange),
                                        ),
                                        child: Text(
                                          'パワー: ${theme.initialPower}',
                                          style: TextStyle(color: theme.initialPower > 1000 ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8.0), // 🌟修正: EdgeInsets.onlyを使用
                                    child: Text(theme.purposeHow, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                                  onTap: () {
                                    // タップしたらカメラ画面へ選んだテーマを渡して移動
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CameraScreen(theme: theme),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  // 「何を」を選ぶボタンの共通パーツ
  Widget _buildWhatButton(String label, IconData icon) {
    final isSelected = (_notifier.selectedWhat == label) || (label == 'すべて' && _notifier.selectedWhat.isEmpty);
    return Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.green : const Color(0xff2a2a2a),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          if (label == 'すべて') {
            _notifier.selectWhat('');
          } else {
            _notifier.selectWhat(label);
          }
        },
      ),
    );
  }
}