import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String provider;      // 'password', 'google.com', etc.
  final int lastLoginAt;      // epoch millis

  const UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.provider,
    required this.lastLoginAt,
  });

  factory UserModel.fromFirebase(User user) => UserModel(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoURL,
    provider: user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'unknown',
    lastLoginAt: DateTime.now().millisecondsSinceEpoch,
  );

  Map<String, Object?> toMap() => {
    'uid': uid,
    'email': email,
    'display_name': displayName,
    'photo_url': photoUrl,
    'provider': provider,
    'last_login_at': lastLoginAt,
  };

  factory UserModel.fromMap(Map<String, Object?> map) => UserModel(
    uid: map['uid'] as String,
    email: map['email'] as String?,
    displayName: map['display_name'] as String?,
    photoUrl: map['photo_url'] as String?,
    provider: map['provider'] as String? ?? 'unknown',
    lastLoginAt: (map['last_login_at'] as int?) ?? 0,
  );
}