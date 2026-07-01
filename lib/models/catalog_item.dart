// Data model class
class CatalogItem {
  final String id;
  
  CatalogItem({
    required this.id,
  });
  
  factory CatalogItem.empty() {
    return CatalogItem(id: '');
  }
  
  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: json['id'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
