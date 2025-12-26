import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddPaymentDialog extends StatefulWidget {
  final double maxAmount;

  const AddPaymentDialog({super.key, required this.maxAmount});

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'Cash';
  DateTime _paymentDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16213E),
      title: const Text('Add Payment', style: TextStyle(color: Colors.white)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixText: 'Rs. ',
                  prefixStyle: const TextStyle(color: Colors.white),
                  suffixText: 'Max: ${widget.maxAmount.toStringAsFixed(2)}',
                  suffixStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null) {
                    return 'Invalid amount';
                  }
                  if (amount <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  if (amount > widget.maxAmount) {
                    return 'Amount exceeds balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(
                    value: 'Bank Transfer',
                    child: Text('Bank Transfer'),
                  ),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                  DropdownMenuItem(
                    value: 'Credit Card',
                    child: Text('Credit Card'),
                  ),
                  DropdownMenuItem(
                    value: 'Debit Card',
                    child: Text('Debit Card'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _paymentMethod = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _paymentDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFF6C5CE7),
                            surface: Color(0xFF16213E),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setState(() {
                      _paymentDate = date;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Payment Date',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_paymentDate.day}/${_paymentDate.month}/${_paymentDate.year}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _savePayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _savePayment() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'amount': double.parse(_amountController.text),
        'paymentMethod': _paymentMethod,
        'paymentDate': _paymentDate,
        'notes': _notesController.text,
      });
    }
  }
}
