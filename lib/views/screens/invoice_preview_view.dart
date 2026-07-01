import 'package:flutter/material.dart';

class InvoicePreviewView extends StatelessWidget {
  const InvoicePreviewView({super.key, required String invoiceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InvoicePreviewView'),
      ),
      body: const Center(
        child: Text('TODO: Implement InvoicePreviewView'),
      ),
    );
  }
}
