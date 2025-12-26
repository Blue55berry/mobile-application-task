import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quotation_item_model.dart';
import '../models/lead_model.dart';
import '../services/quotation_service.dart';
import '../services/leads_service.dart';

class CreateQuotationScreen extends StatefulWidget {
  final int? quotationId; // For editing existing quotation

  const CreateQuotationScreen({super.key, this.quotationId});

  @override
  State<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends State<CreateQuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  Lead? _selectedLead;
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  double _taxRate = 18.0;
  double _discountPercent = 0.0;
  String _notes = '';
  String _termsAndConditions =
      'Payment due within 30 days.\nAll prices in INR.';

  final List<QuotationItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingData = false;
  String? _quotationNumber;
  DateTime? _createdAt;

  @override
  void initState() {
    super.initState();
    if (widget.quotationId != null) {
      _loadExistingQuotation();
    } else {
      _addNewItem(); // Start with one item for new quotation
    }
  }

  Future<void> _loadExistingQuotation() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      final quotationService = Provider.of<QuotationService>(
        context,
        listen: false,
      );
      final leadsService = Provider.of<LeadsService>(context, listen: false);

      // Load quotation
      final quotation = await quotationService.getQuotationById(
        widget.quotationId!,
      );

      if (quotation != null) {
        // Load items
        final items = await quotationService.getQuotationItems(
          widget.quotationId!,
        );

        // Find lead
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
          _selectedLead = lead;
          _validUntil = quotation.validUntil;
          _taxRate = quotation.taxRate;
          _discountPercent = quotation.discountPercent;
          _notes = quotation.notes ?? '';
          _termsAndConditions = quotation.termsAndConditions ?? '';
          _quotationNumber = quotation.quotationNumber;
          _createdAt = quotation.createdAt;
          _items.clear();
          _items.addAll(items);
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quotation not found'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading quotation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addNewItem() {
    setState(() {
      _items.add(
        QuotationItem(
          quotationId: 0,
          itemName: '',
          description: '',
          quantity: 1,
          unit: 'pcs',
          unitPrice: 0,
          totalPrice: 0,
          position: _items.length,
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
      });
    }
  }

  void _updateItem(int index, QuotationItem item) {
    setState(() {
      _items[index] = item;
    });
  }

  double get _subtotal {
    return _items.fold(0, (sum, item) => sum + item.totalPrice);
  }

  double get _discountAmount {
    return _subtotal * (_discountPercent / 100);
  }

  double get _taxableAmount {
    return _subtotal - _discountAmount;
  }

  double get _taxAmount {
    return _taxableAmount * (_taxRate / 100);
  }

  double get _total {
    return _taxableAmount + _taxAmount;
  }

  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLead == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a lead'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if there's at least one valid item with a non-empty name
    if (_items.isEmpty ||
        !_items.any((item) => item.itemName.trim().isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item with a name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final quotationService = Provider.of<QuotationService>(
      context,
      listen: false,
    );

    final validItems = _items
        .where((item) => item.itemName.isNotEmpty)
        .toList();

    bool success;
    if (widget.quotationId != null) {
      // Update existing quotation
      success = await quotationService.updateQuotation(
        quotationId: widget.quotationId!,
        leadId: _selectedLead!.id!,
        validUntil: _validUntil,
        items: validItems,
        taxRate: _taxRate,
        discountPercent: _discountPercent,
        notes: _notes,
        termsAndConditions: _termsAndConditions,
        status: 'Draft',
        quotationNumber: _quotationNumber!,
        createdAt: _createdAt!,
      );
    } else {
      // Create new quotation
      final quotationId = await quotationService.createQuotation(
        leadId: _selectedLead!.id!,
        validUntil: _validUntil,
        items: validItems,
        taxRate: _taxRate,
        discountPercent: _discountPercent,
        notes: _notes,
        termsAndConditions: _termsAndConditions,
        status: 'Draft',
      );
      success = quotationId != null;
    }

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.quotationId != null
                  ? '✅ Quotation updated successfully!'
                  : '✅ Quotation created successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.quotationId != null
                  ? '❌ Failed to update quotation'
                  : '❌ Failed to create quotation',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(
          widget.quotationId != null ? 'Edit Quotation' : 'Create Quotation',
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _saveQuotation,
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(
                widget.quotationId != null ? 'Update' : 'Save',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildLeadSelector(),
                  const SizedBox(height: 20),
                  _buildValidUntilPicker(),
                  const SizedBox(height: 20),
                  _buildItemsSection(),
                  const SizedBox(height: 20),
                  _buildTaxDiscountSection(),
                  const SizedBox(height: 20),
                  _buildTotalsCard(),
                  const SizedBox(height: 20),
                  _buildNotesSection(),
                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewItem,
        backgroundColor: const Color(0xFF6C5CE7),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  Widget _buildLeadSelector() {
    return Consumer<LeadsService>(
      builder: (context, leadsService, child) {
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
                'Select Lead',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Lead>(
                initialValue: _selectedLead != null
                    ? leadsService.leads.firstWhere(
                        (lead) => lead.id == _selectedLead!.id,
                        orElse: () => _selectedLead!,
                      )
                    : null,
                dropdownColor: const Color(0xFF2A2A3E),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.person,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
                hint: const Text(
                  'Choose a lead',
                  style: TextStyle(color: Colors.grey),
                ),
                items: leadsService.leads.map((lead) {
                  return DropdownMenuItem(
                    value: lead,
                    child: Text(
                      lead.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (lead) {
                  setState(() => _selectedLead = lead);
                },
                validator: (value) =>
                    value == null ? 'Please select a lead' : null,
              ),
              if (_selectedLead != null) ...[
                const SizedBox(height: 8),
                Text(
                  _selectedLead!.phoneNumber ?? 'No phone',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (_selectedLead!.email != null)
                  Text(
                    _selectedLead!.email!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildValidUntilPicker() {
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
            'Valid Until',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _validUntil,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF6C5CE7),
                        surface: Color(0xFF2A2A3E),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() => _validUntil = date);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFF6C5CE7)),
                  const SizedBox(width: 12),
                  Text(
                    '${_validUntil.day}/${_validUntil.month}/${_validUntil.year}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
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
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _LineItemEditor(
              key: ValueKey(index),
              item: item,
              onUpdate: (updated) => _updateItem(index, updated),
              onRemove: _items.length > 1 ? () => _removeItem(index) : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTaxDiscountSection() {
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
            'Tax & Discount',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _taxRate.toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Tax Rate (%)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _taxRate = double.tryParse(value) ?? 0);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _discountPercent.toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Discount (%)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(
                      () => _discountPercent = double.tryParse(value) ?? 0,
                    );
                  },
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
          colors: [Color(0xFF6C5CE7), Color(0xFF6C5CE7).withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', _subtotal),
          if (_discountPercent > 0)
            _buildTotalRow('Discount (-$_discountPercent%)', -_discountAmount),
          _buildTotalRow('Taxable Amount', _taxableAmount),
          _buildTotalRow('Tax (+$_taxRate%)', _taxAmount),
          const Divider(color: Colors.white54, height: 24),
          _buildTotalRow('Total', _total, isGrand: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isGrand = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
      ),
    );
  }

  Widget _buildNotesSection() {
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
            'Additional Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _notes,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Notes',
              labelStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => _notes = value,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _termsAndConditions,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Terms & Conditions',
              labelStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => _termsAndConditions = value,
          ),
        ],
      ),
    );
  }
}

class _LineItemEditor extends StatefulWidget {
  final QuotationItem item;
  final Function(QuotationItem) onUpdate;
  final VoidCallback? onRemove;

  const _LineItemEditor({
    super.key,
    required this.item,
    required this.onUpdate,
    this.onRemove,
  });

  @override
  State<_LineItemEditor> createState() => _LineItemEditorState();
}

class _LineItemEditorState extends State<_LineItemEditor> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _qtyController;
  late TextEditingController _priceController;
  late String _selectedUnit;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.itemName);
    _descController = TextEditingController(text: widget.item.description);
    _qtyController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _priceController = TextEditingController(
      text: widget.item.unitPrice.toString(),
    );
    _selectedUnit = widget.item.unit;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _updateItem() {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final total = qty * price;

    widget.onUpdate(
      widget.item.copyWith(
        itemName: _nameController.text,
        description: _descController.text,
        quantity: qty,
        unitPrice: price,
        unit: _selectedUnit,
        totalPrice: total,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total =
        (double.tryParse(_qtyController.text) ?? 0) *
        (double.tryParse(_priceController.text) ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => _updateItem(),
                ),
              ),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descController,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Description',
              labelStyle: TextStyle(color: Colors.grey, fontSize: 11),
              isDense: true,
              border: InputBorder.none,
            ),
            onChanged: (_) => _updateItem(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Qty *',
                    labelStyle: TextStyle(color: Colors.grey, fontSize: 11),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => _updateItem(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedUnit,
                  dropdownColor: const Color(0xFF2A2A3E),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    labelStyle: TextStyle(color: Colors.grey, fontSize: 11),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  items: () {
                    // Build unit list that includes current unit if not in common list
                    final units = <String>[...QuotationItem.commonUnits];
                    if (!units.contains(_selectedUnit)) {
                      units.add(_selectedUnit);
                    }
                    return units.map((unit) {
                      return DropdownMenuItem(value: unit, child: Text(unit));
                    }).toList();
                  }(),
                  onChanged: (value) {
                    setState(() => _selectedUnit = value!);
                    _updateItem();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Price *',
                    labelStyle: TextStyle(color: Colors.grey, fontSize: 11),
                    isDense: true,
                    border: InputBorder.none,
                    prefixText: '₹',
                    prefixStyle: TextStyle(color: Colors.grey),
                  ),
                  onChanged: (_) => _updateItem(),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.grey, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
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
}
