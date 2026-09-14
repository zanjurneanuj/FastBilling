class BusinessProfile {
  final String uid;          // owner = firebase uid
  final String name;
  final String address;
  final String? gstNumber;   // optional
  final String? state;       // optional — shown alongside GSTIN
  final String currency;     // 'INR', 'USD', ...
  final String? logoPath;    // local file path (device-only)
  final String? logoUrl;     // firebase storage url (cross-device)
  final String? bankName;
  final String? bankAccountNo;
  final String? bankIfsc;
  final int updatedAt;

  const BusinessProfile({
    required this.uid,
    required this.name,
    required this.address,
    this.gstNumber,
    this.state,
    required this.currency,
    this.logoPath,
    this.logoUrl,
    this.bankName,
    this.bankAccountNo,
    this.bankIfsc,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
    'uid': uid,
    'name': name,
    'address': address,
    'gst_number': gstNumber,
    'state': state,
    'currency': currency,
    'logo_path': logoPath,
    'logo_url': logoUrl,
    'bank_name': bankName,
    'bank_account_no': bankAccountNo,
    'bank_ifsc': bankIfsc,
    'updated_at': updatedAt,
  };

  // logo_path is skipped on purpose — a local file path is meaningless in the cloud.
  Map<String, Object?> toFirestore() => {
    'uid': uid,
    'name': name,
    'address': address,
    'gst_number': gstNumber,
    'state': state,
    'currency': currency,
    'logo_url': logoUrl,
    'bank_name': bankName,
    'bank_account_no': bankAccountNo,
    'bank_ifsc': bankIfsc,
    'updated_at': updatedAt,
  };

  factory BusinessProfile.fromMap(Map<String, Object?> m) => BusinessProfile(
    uid: m['uid'] as String,
    name: m['name'] as String? ?? '',
    address: m['address'] as String? ?? '',
    gstNumber: m['gst_number'] as String?,
    state: m['state'] as String?,
    currency: m['currency'] as String? ?? 'INR',
    logoPath: m['logo_path'] as String?,
    logoUrl: m['logo_url'] as String?,
    bankName: m['bank_name'] as String?,
    bankAccountNo: m['bank_account_no'] as String?,
    bankIfsc: m['bank_ifsc'] as String?,
    updatedAt: (m['updated_at'] as int?) ?? 0,
  );
}
