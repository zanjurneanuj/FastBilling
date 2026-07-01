// Data model class
class SettingsViewmodel {
  final String id;
  
  SettingsViewmodel({
    required this.id,
  });
  
  factory SettingsViewmodel.empty() {
    return SettingsViewmodel(id: '');
  }
  
  factory SettingsViewmodel.fromJson(Map<String, dynamic> json) {
    return SettingsViewmodel(
      id: json['id'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
