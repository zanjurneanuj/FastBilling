// Data model class
class LineItem {
  final String id;
  
  LineItem({
    required this.id,
  });
  
  factory LineItem.empty() {
    return LineItem(id: '');
  }
  
  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      id: json['id'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
