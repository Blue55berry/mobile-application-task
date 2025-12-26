import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quotation_model.dart';
import '../models/quotation_item_model.dart';
import '../models/lead_model.dart';
import '../services/quotation_service.dart';
import '../services/leads_service.dart';
import '../services/invoice_service.dart';
import '../services/pdf_service.dart';
import 'pdf_preview_screen.dart';
import 'invoice_details_screen.dart';
import 'package:intl/intl.dart';

class QuotationDetailsScreen extends StatefulWidget {
  final int quotationId;

  const QuotationDetailsScreen({super.key, required this.quotationId});

  @override
  State<QuotationDetailsScreen> createState() => _QuotationDetailsScreenState();
}

class _QuotationDetailsScreenState extends State<QuotationDetailsScreen> {
  Quotation? _quotation;
  List<QuotationItem> _items = [];
  Lead? _lead;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuotationDetails();
  }

  Future<void> _loadQuotationDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quotationService = Provider.of<QuotationService>(
        context,
        listen: false,
      );
      final leadsService = Provider.of<LeadsService>(context, listen: false);

      // Load quotation
      final quotation = await quotationService.getQuotationById(
        widget.quotationId,
      );
      if (quotation == null) {
        setState(() {
          _error = 'Quotation not found';
          _isLoading = false;
        });
        return;
      }

      // Load items
      final items = await quotationService.getQuotationItems(
        widget.quotationId,
      );

      // Load lead
      final lead = leadsService.leads.firstWhere(
        (l) => l.id == quotation.leadId,
        orElse: () => Lead(
          name: 'Unknown',
          phoneNumber: '',
          category: '',
          status: 'New',
          createdAt: DateTime.now(),
        ),
      );

      setState(() {
        _quotation = quotation;
        _items = items;
        _lead = lead;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading quotation: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final quotationService = Provider.of<QuotationService>(
      context,
      listen: false,
    );

    final success = await quotationService.updateQuotationStatus(
      widget.quotationId,
      newStatus,
    );

    if (success) {
      await _loadQuotationDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteQuotation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text(
          'Delete Quotation?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This action cannot be undone. All quotation data will be permanently deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final quotationService = Provider.of<QuotationService>(
        context,
        listen: false,
      );

      final success = await quotationService.deleteQuotation(
        widget.quotationId,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context); // Go back to list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quotation deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete quotation'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _sharePDF() async {
    if (_quotation == null || _lead == null) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
        ),
      );

      // Generate PDF
      final pdf = await PdfService.generateQuotationPDF(
        quotation: _quotation!,
        items: _items,
        lead: _lead!,
      );

      // Close loading
      if (mounted) Navigator.pop(context);

      // Navigate to PDF preview screen
      // Users can view the PDF and then share from there
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdf: pdf,
              fileName: _quotation!.quotationNumber,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading if still open
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _previewPDF() async {
    if (_quotation == null || _lead == null) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
        ),
      );

      // Generate PDF
      final pdf = await PdfService.generateQuotationPDF(
        quotation: _quotation!,
        items: _items,
        lead: _lead!,
      );

      // Close loading
      if (mounted) Navigator.pop(context);

      // Navigate to PDF preview screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdf: pdf,
              fileName: _quotation!.quotationNumber,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading if still open
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to preview PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editQuotation() {
    Navigator.pushNamed(
      context,
      '/create_quotation',
      arguments: widget.quotationId,
    ).then((_) => _loadQuotationDetails());
  }

  Future<void> _convertToInvoice() async {
    if (_quotation == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Convert to Invoice',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Convert quotation ${_quotation!.quotationNumber} to an invoice?\n\nThis will create a new invoice with all items from this quotation.',
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
            child: const Text('Convert'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
        ),
      );

      final invoiceService = Provider.of<InvoiceService>(
        context,
        listen: false,
      );
      final invoiceId = await invoiceService.convertQuotationToInvoice(
        quotation: _quotation!,
        items: _items,
      );

      if (mounted) Navigator.pop(context);

      if (invoiceId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully converted to invoice'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoiceDetailsScreen(invoiceId: invoiceId),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to convert to invoice'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(_quotation?.quotationNumber ?? 'Quotation Details'),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          if (_quotation != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editQuotation,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteQuotation,
              tooltip: 'Delete',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'preview') {
                  _previewPDF();
                } else if (value == 'share') {
                  _sharePDF();
                } else if (value == 'convert') {
                  _convertToInvoice();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'preview',
                  child: Row(
                    children: [
                      Icon(Icons.preview, size: 20),
                      SizedBox(width: 8),
                      Text('Preview PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 20),
                      SizedBox(width: 8),
                      Text('Share PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'convert',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, size: 20, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Convert to Invoice',
                        style: TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadQuotationDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _quotation == null
          ? const Center(
              child: Text(
                'Quotation not found',
                style: TextStyle(color: Colors.white),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildLeadInfo(),
                const SizedBox(height: 16),
                _buildItemsSection(),
                const SizedBox(height: 16),
                _buildTotalsCard(),
                if (_quotation!.notes != null &&
                    _quotation!.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildNotesSection(_quotation!.notes!),
                ],
                if (_quotation!.termsAndConditions != null &&
                    _quotation!.termsAndConditions!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildTermsSection(_quotation!.termsAndConditions!),
                ],
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
      floatingActionButton: _quotation != null
          ? FloatingActionButton.extended(
              onPressed: _sharePDF,
              backgroundColor: const Color(0xFF6C5CE7),
              icon: const Icon(Icons.share),
              label: const Text('Share PDF'),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _quotation!.quotationNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${dateFormat.format(_quotation!.createdAt)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _buildStatusDropdown(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(
                'Valid Until: ${dateFormat.format(_quotation!.validUntil)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    final statusColor = _getStatusColor(_quotation!.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor),
      ),
      child: DropdownButton<String>(
        value: _quotation!.status,
        dropdownColor: const Color(0xFF2A2A3E),
        underline: const SizedBox(),
        isDense: true,
        style: TextStyle(color: statusColor, fontSize: 12),
        items: ['Draft', 'Sent', 'Accepted', 'Rejected', 'Converted']
            .map(
              (status) => DropdownMenuItem(value: status, child: Text(status)),
            )
            .toList(),
        onChanged: (newStatus) {
          if (newStatus != null && newStatus != _quotation!.status) {
            _updateStatus(newStatus);
          }
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'converted':
        return const Color(0xFF6C5CE7);
      default:
        return Colors.grey;
    }
  }

  Widget _buildLeadInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF6C5CE7), size: 20),
              const SizedBox(width: 8),
              Text(
                _lead?.name ?? 'Unknown',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          if (_lead?.phoneNumber != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, color: Color(0xFF6C5CE7), size: 20),
                const SizedBox(width: 8),
                Text(
                  _lead!.phoneNumber!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ],
          if (_lead?.email != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email, color: Color(0xFF6C5CE7), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lead!.email!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
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
          const SizedBox(height: 16),
          ..._items.map((item) => _buildItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildItemCard(QuotationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.itemName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description!,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.quantity} ${item.unit} × ₹${item.unitPrice.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                '₹${item.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF6C5CE7),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C5CE7),
            const Color(0xFF6C5CE7).withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', _quotation!.subtotal),
          if (_quotation!.discountPercent > 0) ...[
            const SizedBox(height: 8),
            _buildTotalRow(
              'Discount (-${_quotation!.discountPercent}%)',
              -_quotation!.discountAmount,
            ),
          ],
          const SizedBox(height: 8),
          _buildTotalRow(
            'Taxable Amount',
            _quotation!.subtotal - _quotation!.discountAmount,
          ),
          const SizedBox(height: 8),
          _buildTotalRow(
            'Tax (+${_quotation!.taxRate}%)',
            _quotation!.taxAmount,
          ),
          const Divider(color: Colors.white54, height: 24),
          _buildTotalRow(
            'Total Amount',
            _quotation!.totalAmount,
            isGrand: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isGrand = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: isGrand ? 18 : 14,
            fontWeight: isGrand ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.white,
            fontSize: isGrand ? 20 : 14,
            fontWeight: isGrand ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(String notes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(String terms) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Terms & Conditions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            terms,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
