// Data model class
class CatalogViewmodel {
  final String id;
  
  CatalogViewmodel({
    required this.id,
  });
  
  factory CatalogViewmodel.empty() {
    return CatalogViewmodel(id: '');
  }
  
  factory CatalogViewmodel.fromJson(Map<String, dynamic> json) {
    return CatalogViewmodel(
      id: json['id'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
