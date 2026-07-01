// Data model class
class Payment {
  final String id;
  
  Payment({
    required this.id,
  });
  
  factory Payment.empty() {
    return Payment(id: '');
  }
  
  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
