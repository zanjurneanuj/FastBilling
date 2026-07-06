import 'package:flutter/material.dart';

import '../models/ClientItem.dart';



class ClientsViewModel extends ChangeNotifier {
  List<ClientItem> clients = [];
  bool isLoading = false;

  Future<void> loadClients() async {
    isLoading = true;
    notifyListeners();

    // ── Replace with your real sqflite / Firestore query ─────────────────
    await Future.delayed(const Duration(milliseconds: 400));
    clients = const [
      ClientItem(id: '1', name: 'Meridian Studio',  email: 'hello@meridian.co',        totalBilled: 284000),
      ClientItem(id: '2', name: 'Nordic Coffee Co.', email: 'accounts@nordic.coffee',   totalBilled: 64500),
      ClientItem(id: '3', name: 'Patel & Sons',      email: 'patel.sons@gmail.com',     totalBilled: 192200),
      ClientItem(id: '4', name: 'Lumen Design',      email: 'pay@lumen.design',         totalBilled: 88000),
      ClientItem(id: '5', name: 'Veda Wellness',     email: 'finance@veda.in',          totalBilled: 54750),
    ];
    // ─────────────────────────────────────────────────────────────────────

    isLoading = false;
    notifyListeners();
  }

  Future<void> addClient({
    required String name,
    required String email,
    String phone = '',
  }) async {
    // ── Replace with your real DB insert ─────────────────────────────────
    final newClient = ClientItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      phone: phone,
      totalBilled: 0,
    );
    clients = [newClient, ...clients];
    // ─────────────────────────────────────────────────────────────────────
    notifyListeners();
  }

  Future<void> deleteClient(String id) async {
    clients = clients.where((c) => c.id != id).toList();
    notifyListeners();
  }
}