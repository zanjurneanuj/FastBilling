class ClientItem {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final double totalBilled;

  const ClientItem({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.city = '',
    this.totalBilled = 0,
  });
  factory ClientItem.fromMap(String id, Map<String, dynamic> data) {
    return ClientItem(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      city: data['city'] ?? '',
      totalBilled: (data['totalBilled'] ?? 0).toDouble(),
    );
  }
}
