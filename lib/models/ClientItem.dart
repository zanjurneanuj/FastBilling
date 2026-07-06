class ClientItem {
  final String id;
  final String name;
  final String email;
  final String phone;
  final double totalBilled;

  const ClientItem({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.totalBilled = 0,
  });
}