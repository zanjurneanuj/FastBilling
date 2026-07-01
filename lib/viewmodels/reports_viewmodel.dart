// Data model class
class ReportsViewmodel {
  final String id;
  
  ReportsViewmodel({
    required this.id,
  });
  
  factory ReportsViewmodel.empty() {
    return ReportsViewmodel(id: '');
  }
  
  factory ReportsViewmodel.fromJson(Map<String, dynamic> json) {
    return ReportsViewmodel(
      id: json['id'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
