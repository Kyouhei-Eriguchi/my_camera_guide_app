class CameraTheme {
  final String id;
  final int initialPower;
  final String purposeWhat;
  final String purposeHow;
  final String title;
  final String message;
  final Map<String, dynamic> conditions;
  final Map<String, dynamic> designGuide;

  CameraTheme({
    required this.id,
    required this.initialPower,
    required this.purposeWhat,
    required this.purposeHow,
    required this.title,
    required this.message,
    required this.conditions,
    required this.designGuide,
  });

  // JSONからCameraThemeオブジェクトに変換するファクトリメソッド
  factory CameraTheme.fromJson(Map<String, dynamic> json) {
    return CameraTheme(
      id: json['id'] as String,
      initialPower: json['initial_power'] as int,
      purposeWhat: json['purpose_what'] as String,
      purposeHow: json['purpose_how'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      conditions: json['conditions'] as Map<String, dynamic>,
      designGuide: json['design_guide'] as Map<String, dynamic>,
    );
  }
}