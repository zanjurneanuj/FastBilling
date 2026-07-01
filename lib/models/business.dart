// Data model class
class Business {
  final String id;
  
  Business({
    required this.id,
  });
  
  factory Business.empty() {
    return Business(id: '');
  }
  
  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
