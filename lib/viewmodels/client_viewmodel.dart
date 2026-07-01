// Data model class
class ClientViewmodel {
  final String id;
  
  ClientViewmodel({
    required this.id,
  });
  
  factory ClientViewmodel.empty() {
    return ClientViewmodel(id: '');
  }
  
  factory ClientViewmodel.fromJson(Map<String, dynamic> json) {
    return ClientViewmodel(
      id: json['id'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
