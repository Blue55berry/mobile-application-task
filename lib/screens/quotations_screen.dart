import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/quotation_service.dart';
import '../services/leads_service.dart';
import '../models/quotation_model.dart';
import '../widgets/bottom_nav_bar.dart';

class QuotationsScreen extends StatefulWidget {
  const QuotationsScreen({super.key});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<QuotationService>(context, listen: false).loadQuotations();
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
        title: const Text('Quotations'),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<QuotationService>(
                context,
                listen: false,
              ).loadQuotations();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildQuotationsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/create_quotation');
        },
        backgroundColor: const Color(0xFF6C5CE7),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 3, // Assuming quotations is index 3
        onTap: (index) {
          // Handle navigation
        },
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
          hintText: 'Search quotations...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFF2A2A3E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      'All',
      'Draft',
      'Sent',
      'Accepted',
      'Rejected',
      'Converted',
    ];

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
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              backgroundColor: const Color(0xFF2A2A3E),
              selectedColor: const Color(0xFF6C5CE7),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
              ),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuotationsList() {
    return Consumer<QuotationService>(
      builder: (context, quotationService, child) {
        if (quotationService.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
          );
        }

        var quotations = quotationService.filterByStatus(_selectedFilter);

        if (_searchController.text.isNotEmpty) {
          quotations = quotationService.searchQuotations(
            _searchController.text,
          );
        }

        if (quotations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 80,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedFilter == 'All'
                      ? 'No quotations yet'
                      : 'No $_selectedFilter quotations',
                  style: TextStyle(color: Colors.grey[600], fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap + to create your first quotation',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: quotations.length,
          itemBuilder: (context, index) {
            return _buildQuotationCard(quotations[index]);
          },
        );
      },
    );
  }

  Widget _buildQuotationCard(Quotation quotation) {
    final statusColor = Color(
      int.parse(
        Quotation.getStatusColor(quotation.status).replaceFirst('#', '0xFF'),
      ),
    );

    return Card(
      color: const Color(0xFF2A2A3E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/quotation_details',
            arguments: quotation.id,
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
                    quotation.quotationNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      quotation.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Consumer<LeadsService>(
                builder: (context, leadsService, child) {
                  final lead = leadsService.leads
                      .where((l) => l.id == quotation.leadId)
                      .firstOrNull;

                  return Row(
                    children: [
                      const Icon(Icons.person, color: Colors.grey, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        lead?.name ?? 'Unknown Lead',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Valid until: ${quotation.validUntil.day}/${quotation.validUntil.month}/${quotation.validUntil.year}',
                    style: TextStyle(
                      color: quotation.isExpired() ? Colors.red : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  if (quotation.isExpired())
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        '(Expired)',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const Divider(color: Colors.grey, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  Text(
                    '₹${quotation.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF6C5CE7),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
