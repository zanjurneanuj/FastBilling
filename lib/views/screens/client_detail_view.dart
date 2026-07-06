import 'package:flutter/material.dart';

  class ClientDetailView extends StatelessWidget {
  const ClientDetailView({super.key, required String clientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClientDetailView'),
      ),
      body: const Center(
        child: Text('TODO: Implement ClientDetailView'),
      ),
    );
  }
}
