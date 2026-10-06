import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ClientItem.dart';
import '../services/SubscriptionService.dart';

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

  /// Adds a client. Returns false (with [errorMsg] set) if it couldn't be
  /// saved — including when the free plan's client limit is reached.
  Future<bool> addClient({
    required String name,
    required String email,
    String phone = '',
    String city = '',
    String address = '',
    String gstin = '',
    String state = '',
  }) async {
    // Screens check the limit before opening the form; this is the
    // backstop for when the local list isn't loaded yet.
    if (!SubscriptionService.isPremium) {
      var count = clients.length;
      try {
        count = (await _clientsRef.count().get()).count ?? count;
      } catch (e) {
        debugPrint('Client count failed, using local list: $e');
      }
      if (!SubscriptionService.canAddClient(count)) {
        errorMsg = 'The free plan includes up to '
            '${SubscriptionService.freeClientLimit} clients. Upgrade to add more.';
        notifyListeners();
        return false;
      }
    }

    final docRef = _clientsRef.doc();
    final newClient = ClientItem(
      id: docRef.id,
      name: name,
      email: email,
      phone: phone,
      city: city,
      address: address,
      gstin: gstin,
      state: state,
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
        'address': address,
        'gstin': gstin,
        'state': state,
        'totalBilled': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding client: $e');
      errorMsg = 'Could not save this client. Please try again.';
      clients = clients.where((c) => c.id != newClient.id).toList();
      notifyListeners();
      return false;
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