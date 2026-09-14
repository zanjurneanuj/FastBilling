import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ClientItem.dart';

class ClientsViewModel extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;

  List<ClientItem> clients = [];
  bool isLoading = false;
  String? errorMsg;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _clientsRef {
    final uid = _uid;
    if (uid == null) throw Exception('No signed-in user.');
    return _firestore.collection('users').doc(uid).collection('clients');
  }

  Future<void> loadClients() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();

    try {
      final snapshot =
      await _clientsRef.orderBy('createdAt', descending: true).get();
      clients =
          snapshot.docs.map((d) => ClientItem.fromMap(d.id, d.data())).toList();
    } catch (e) {
      debugPrint('Error loading clients: $e');
      errorMsg = 'Could not load clients. Please try again.';
      clients = [];
    }

    isLoading = false;
    notifyListeners();
  }

  /// Looks up a client by id from the already-loaded list, falling back to
  /// a direct Firestore read (e.g. after a deep link straight to a client's
  /// detail page before the list has loaded).
  Future<ClientItem?> getClient(String id) async {
    for (final c in clients) {
      if (c.id == id) return c;
    }
    try {
      final doc = await _clientsRef.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return ClientItem.fromMap(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('Error fetching client $id: $e');
      return null;
    }
  }

  Future<void> addClient({
    required String name,
    required String email,
    String phone = '',
    String city = '',
  }) async {
    final docRef = _clientsRef.doc();
    final newClient = ClientItem(
      id: docRef.id,
      name: name,
      email: email,
      phone: phone,
      city: city,
      totalBilled: 0,
    );

    clients = [newClient, ...clients]; // optimistic UI
    errorMsg = null;
    notifyListeners();

    try {
      await docRef.set({
        'name': name,
        'email': email,
        'phone': phone,
        'city': city,
        'totalBilled': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding client: $e');
      errorMsg = 'Could not save this client. Please try again.';
      clients = clients.where((c) => c.id != newClient.id).toList();
      notifyListeners();
    }
  }

  Future<void> deleteClient(String id) async {
    final prev = clients;
    clients = clients.where((c) => c.id != id).toList();
    errorMsg = null;
    notifyListeners();

    try {
      await _clientsRef.doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting client: $e');
      errorMsg = 'Could not delete this client. Please try again.';
      clients = prev; // rollback
      notifyListeners();
    }
  }
}