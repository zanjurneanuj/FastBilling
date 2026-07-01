// Data model class
class Client {
  final String id;
  
  Client({
    required this.id,
  });
  
  factory Client.empty() {
    return Client(id: '');
  }
  
  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
