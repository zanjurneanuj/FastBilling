import 'package:fast_billing/views/screens/home_view.dart';
import 'package:flutter/material.dart';

  class ClientDetailView extends StatelessWidget {
  const ClientDetailView({super.key, required String clientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClientDetailView'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeView(),
              ),
            );
          },
        ),
      ),
      body: const Center(
        child: Text('TODO: Implement ClientDetailView'),
      ),
    );
  }
}
