class TopClient {
  final String name;
  final double billed;
  final double maxBilled; // for progress bar ratio
  const TopClient({
    required this.name,
    required this.billed,
    required this.maxBilled,
  });

  double get ratio => maxBilled > 0 ? (billed / maxBilled).clamp(0.0, 1.0) : 0;
}
