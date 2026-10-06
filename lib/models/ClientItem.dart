class ClientItem {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String address;
  final String gstin;
  final String state;
  final double totalBilled;

  const ClientItem({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.city = '',
    this.address = '',
    this.gstin = '',
    this.state = '',
    this.totalBilled = 0,
  });
  factory ClientItem.fromMap(String id, Map<String, dynamic> data) {
    return ClientItem(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      city: data['city'] ?? '',
      address: data['address'] ?? '',
      gstin: data['gstin'] ?? '',
      state: data['state'] ?? '',
      totalBilled: (data['totalBilled'] ?? 0).toDouble(),
    );
  }

  /// Street address plus city, as printed under "Bill to".
  String get fullAddress =>
      [address, city].where((s) => s.trim().isNotEmpty).join(', ');
}
