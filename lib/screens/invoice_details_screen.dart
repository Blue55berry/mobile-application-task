import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/invoice_model.dart';
import '../models/invoice_item_model.dart';
import '../services/invoice_service.dart';
import '../services/leads_service.dart';
import '../widgets/add_payment_dialog.dart';
import 'package:intl/intl.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  Invoice? _invoice;
  List<InvoiceItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoiceData();
  }

  Future<void> _loadInvoiceData() async {
    setState(() => _isLoading = true);

    final invoiceService = Provider.of<InvoiceService>(context, listen: false);
    final invoice = await invoiceService.getInvoiceById(widget.invoiceId);
    final items = await invoiceService.getInvoiceItems(widget.invoiceId);

    setState(() {
      _invoice = invoice;
      _items = items;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _invoice == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          title: const Text('Invoice Details'),
          backgroundColor: const Color(0xFF1A1A2E),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(_invoice!.invoiceNumber),
        backgroundColor: const Color(0xFF1A1A2E),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF16213E),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                _deleteInvoice();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInvoiceHeader(),
            const SizedBox(height: 20),
            _buildCustomerCard(),
            const SizedBox(height: 20),
            _buildItemsSection(),
            const SizedBox(height: 20),
            _buildPaymentSummary(),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader() {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice Date',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(_invoice!.createdAt),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Due Date',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(_invoice!.dueDate),
                    style: TextStyle(
                      color: _invoice!.isOverdue() ? Colors.red : Colors.white,
                      fontSize: 14,
                      fontWeight: _invoice!.isOverdue()
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusBadge(_invoice!.paymentStatus),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Consumer<LeadsService>(
      builder: (context, leadsService, child) {
        final lead = leadsService.leads.firstWhere(
          (l) => l.id == _invoice!.leadId,
          orElse: () => leadsService.leads.first,
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                lead.name,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              if (lead.phoneNumber != null) ...[
                const SizedBox(height: 4),
                Text(
                  lead.phoneNumber!,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
              if (lead.email != null) ...[
                const SizedBox(height: 4),
                Text(
                  lead.email!,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Line Items',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Colors.white12, height: 20),
            itemBuilder: (context, index) {
              final item = _items[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.itemName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        'Rs. ${item.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.quantity} ${item.unit} × Rs. ${item.unitPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF5B4CDB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', _invoice!.subtotal),
          if (_invoice!.discountAmount > 0)
            _buildSummaryRow(
              'Discount (${_invoice!.discountPercent}%)',
              -_invoice!.discountAmount,
            ),
          _buildSummaryRow('Tax (${_invoice!.taxRate}%)', _invoice!.taxAmount),
          const Divider(color: Colors.white24, height: 20),
          _buildSummaryRow('Total', _invoice!.totalAmount, isBold: true),
          if (_invoice!.paidAmount > 0) ...[
            _buildSummaryRow(
              'Paid',
              -_invoice!.paidAmount,
              color: Colors.green,
            ),
            const Divider(color: Colors.white24, height: 20),
            _buildSummaryRow(
              'Balance Due',
              _invoice!.balanceAmount,
              isBold: true,
              color: Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'Rs. ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_invoice!.balanceAmount > 0) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addPayment,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Payment',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor:
                    Colors.white, // Ensures text and icons are white
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _markAsPaid,
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark as Paid'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'Paid':
        backgroundColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green;
        break;
      case 'Unpaid':
        backgroundColor = Colors.orange.withValues(alpha: 0.2);
        textColor = Colors.orange;
        break;
      case 'Partial':
        backgroundColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue;
        break;
      default:
        backgroundColor = Colors.grey.withValues(alpha: 0.2);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _addPayment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          AddPaymentDialog(maxAmount: _invoice!.balanceAmount),
    );

    if (result != null && mounted) {
      final invoiceService = Provider.of<InvoiceService>(
        context,
        listen: false,
      );
      final success = await invoiceService.recordPayment(
        widget.invoiceId,
        result['amount'] as double,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInvoiceData();
      }
    }
  }

  Future<void> _markAsPaid() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Mark as Paid',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Mark this invoice as fully paid?\nRemaining balance: Rs. ${_invoice!.balanceAmount.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final invoiceService = Provider.of<InvoiceService>(
        context,
        listen: false,
      );
      final success = await invoiceService.markAsPaid(widget.invoiceId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice marked as paid'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInvoiceData();
      }
    }
  }

  Future<void> _deleteInvoice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Delete Invoice',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this invoice? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final invoiceService = Provider.of<InvoiceService>(
        context,
        listen: false,
      );
      final success = await invoiceService.deleteInvoice(widget.invoiceId);

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
