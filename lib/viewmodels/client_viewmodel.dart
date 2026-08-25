import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ClientItem.dart';

class ClientsViewModel extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;

  List<ClientItem> clients = [];
  bool isLoading = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _clientsRef {
    final uid = _uid;
    if (uid == null) throw Exception('No signed-in user.');
    return _firestore.collection('users').doc(uid).collection('clients');
  }

  Future<void> loadClients() async {
    isLoading = true;
    notifyListeners();

    try {
      final snapshot =
      await _clientsRef.orderBy('createdAt', descending: true).get();
      clients =
          snapshot.docs.map((d) => ClientItem.fromMap(d.id, d.data())).toList();
    } catch (e) {
      debugPrint('Error loading clients: $e');
      clients = [];
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> addClient({
    required String name,
    required String email,
    String phone = '',
  }) async {
    final docRef = _clientsRef.doc();
    final newClient = ClientItem(
      id: docRef.id,
      name: name,
      email: email,
      phone: phone,
      totalBilled: 0,
    );

    clients = [newClient, ...clients]; // optimistic UI
    notifyListeners();

    try {
      await docRef.set({
        'name': name,
        'email': email,
        'phone': phone,
        'totalBilled': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding client: $e');
      clients = clients.where((c) => c.id != newClient.id).toList();
      notifyListeners();
    }
  }

  Future<void> deleteClient(String id) async {
    final prev = clients;
    clients = clients.where((c) => c.id != id).toList();
    notifyListeners();

    try {
      await _clientsRef.doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting client: $e');
      clients = prev; // rollback
      notifyListeners();
    }
  }
}