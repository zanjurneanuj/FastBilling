// Data model class
class Invoice {
  final String id;
  
  Invoice({
    required this.id,
  });
  
  factory Invoice.empty() {
    return Invoice(id: '');
  }
  
  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
