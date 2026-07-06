import 'package:flutter/material.dart';
import 'views/home_screen.dart';

void main() {
  // Flutterのシステム初期化を確実に行うための決まり文句
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyCameraGuideApp());
}

class MyCameraGuideApp extends StatelessWidget {
  const MyCameraGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '記憶を記録するカメラガイド',
      debugShowCheckedModeBanner: false, // 画面右上の「DEBUG」リボンを非表示にする
      
      // アプリ全体のデザインテーマ（ダークモードベースでスタイリッシュに）
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xff121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      
      // アプリ起動時に最初に表示する画面（ホーム画面）
      home: const HomeScreen(),
    );
  }
}