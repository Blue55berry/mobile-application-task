import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/invoice_model.dart';
import '../services/invoice_service.dart';
import '../services/leads_service.dart';
import 'invoice_details_screen.dart';
import 'create_invoice_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InvoiceService>(context, listen: false).loadInvoices();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildInvoiceList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateInvoiceScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF6C5CE7),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search invoices...',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF16213E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Unpaid', 'Paid', 'Partial', 'Overdue'];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              backgroundColor: const Color(0xFF16213E),
              selectedColor: const Color(0xFF6C5CE7),
              checkmarkColor: Colors.white,
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }

  Widget _buildInvoiceList() {
    return Consumer<InvoiceService>(
      builder: (context, invoiceService, child) {
        if (invoiceService.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
          );
        }

        var invoices = invoiceService.invoices;

        // Apply filters
        if (_selectedFilter != 'All') {
          invoices = invoices
              .where((inv) => inv.paymentStatus == _selectedFilter)
              .toList();
        }

        // Apply search
        if (_searchQuery.isNotEmpty) {
          invoices = invoices
              .where(
                (inv) => inv.invoiceNumber.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();
        }

        if (invoices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey[700]),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No invoices found'
                      : 'No invoices yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => invoiceService.loadInvoices(),
          backgroundColor: const Color(0xFF16213E),
          color: const Color(0xFF6C5CE7),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return _buildInvoiceCard(invoice);
            },
          ),
        );
      },
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    return Consumer<LeadsService>(
      builder: (context, leadsService, child) {
        final lead = leadsService.leads.firstWhere(
          (l) => l.id == invoice.leadId,
          orElse: () => leadsService.leads.first,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      InvoiceDetailsScreen(invoiceId: invoice.id!),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildStatusBadge(invoice.paymentStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lead.name,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rs. ${invoice.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (invoice.isOverdue())
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'OVERDUE',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Due Date',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(invoice.dueDate),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
      case 'Overdue':
        backgroundColor = Colors.red.withValues(alpha: 0.2);
        textColor = Colors.red;
        break;
      default:
        backgroundColor = Colors.grey.withValues(alpha: 0.2);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
