// Data model class
class InvoiceViewmodel {
  final String id;
  
  InvoiceViewmodel({
    required this.id,
  });
  
  factory InvoiceViewmodel.empty() {
    return InvoiceViewmodel(id: '');
  }
  
  factory InvoiceViewmodel.fromJson(Map<String, dynamic> json) {
    return InvoiceViewmodel(
      id: json['id'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
