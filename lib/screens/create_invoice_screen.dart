import 'package:flutter/material.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final int? invoiceId;

  const CreateInvoiceScreen({super.key, this.invoiceId});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(
          widget.invoiceId == null ? 'Create Invoice' : 'Edit Invoice',
        ),
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Invoice Creation Form',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Reuses quotation form pattern',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
