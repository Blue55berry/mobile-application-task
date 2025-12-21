import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lead_model.dart';
import '../services/leads_service.dart';
import '../services/label_service.dart';
import '../widgets/lead_item.dart';
import '../widgets/bottom_nav_bar.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});
  @override
  LeadsScreenState createState() => LeadsScreenState();
}

class LeadsScreenState extends State<LeadsScreen> {
  String _selectedFilter = 'all';
  final int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    final leadsService = Provider.of<LeadsService>(context);
    final leads = leadsService.leads;

    var filteredLeads = leads;
    if (_selectedFilter != 'all') {
      filteredLeads = filteredLeads
          .where((lead) => lead.category == _selectedFilter)
          .toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('Leads', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddLeadDialog(),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildFilterChips()),
          SliverToBoxAdapter(child: _buildLeadStats(filteredLeads)),
          _buildLeadsList(filteredLeads),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != _currentIndex) {
            Navigator.pushReplacementNamed(context, _getRouteName(index));
          }
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return Consumer<LabelService>(
      builder: (context, labelService, child) {
        return Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterChip('All', 'all'),
              ...labelService.labels.map(
                (label) => _buildFilterChip(label.name, label.name),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: const Color(0xFF2A2A3E),
        selectedColor: const Color(0xFF6C5CE7),
        side: BorderSide.none,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
      ),
    );
  }

  Widget _buildLeadStats(List<Lead> filteredLeads) {
    final totalLeads = filteredLeads.length;
    final newLeads = filteredLeads.where((l) => l.status == 'New').length;
    final followUps = filteredLeads
        .where((l) => l.status == 'Follow-up')
        .length;
    final hotLeads = filteredLeads.where((l) => l.status == 'Hot').length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', totalLeads.toString(), Colors.blue),
          _buildStatItem('New', newLeads.toString(), const Color(0xFF6C5CE7)),
          _buildStatItem(
            'Follow-up',
            followUps.toString(),
            const Color(0xFFFF6B6B),
          ),
          _buildStatItem('Hot', hotLeads.toString(), const Color(0xFFFFB86C)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildLeadsList(List<Lead> filteredLeads) {
    if (filteredLeads.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No leads found',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final lead = filteredLeads[index];
          return Dismissible(
            key: Key(lead.id.toString()),
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) async {
              final leadsService = context.read<LeadsService>();
              final messenger = ScaffoldMessenger.of(context);
              await leadsService.deleteLead(lead.id!);
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('Lead deleted')),
              );
            },
            child: LeadItem(lead: lead),
          );
        }, childCount: filteredLeads.length),
      ),
    );
  }

  void _showAddLeadDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedCategory =
        Provider.of<LabelService>(context, listen: false).labels.isNotEmpty
        ? Provider.of<LabelService>(context, listen: false).labels.first.name
        : 'Client';
    String selectedStatus = 'New';
    DateTime? assignedDate = DateTime.now();
    TimeOfDay? assignedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: const Text(
            'Add New Lead',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C5CE7),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C5CE7),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _LeadCategoryDropdown(
                      initialCategory: selectedCategory,
                      onChanged: (newValue) {
                        selectedCategory = newValue;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        'Assigned Date: ${assignedDate != null ? "${assignedDate!.toLocal()}".split(' ')[0] : 'Not set'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today,
                        color: Colors.grey,
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: assignedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2101),
                        );
                        if (date != null) {
                          setState(() {
                            assignedDate = date;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        'Assigned Time: ${assignedTime != null ? assignedTime!.format(context) : 'Not set'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.access_time,
                        color: Colors.grey,
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: assignedTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            assignedTime = time;
                          });
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
              ),
              child: const Text('Add'),
              onPressed: () async {
                final lead = Lead(
                  name: nameController.text,
                  category: selectedCategory,
                  status: selectedStatus,
                  createdAt: DateTime.now(),
                  phoneNumber: phoneController.text,
                  assignedDate: assignedDate,
                  assignedTime: assignedTime?.format(context),
                );
                final leadsService = context.read<LeadsService>();
                final navigator = Navigator.of(context);
                await leadsService.addLead(lead);
                if (!mounted) return;
                navigator.pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _getRouteName(int index) {
    switch (index) {
      case 0:
        return '/dashboard';
      case 1:
        return '/leads';
      case 2:
        return '/tasks';
      case 3:
        return '/settings';
      default:
        return '/dashboard';
    }
  }
}

class _LeadCategoryDropdown extends StatefulWidget {
  final String initialCategory;
  final ValueChanged<String> onChanged;

  const _LeadCategoryDropdown({
    required this.initialCategory,
    required this.onChanged,
  });

  @override
  State<_LeadCategoryDropdown> createState() => _LeadCategoryDropdownState();
}

class _LeadCategoryDropdownState extends State<_LeadCategoryDropdown> {
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LabelService>(
      builder: (context, labelService, child) {
        final labels = labelService.labels;

        return DropdownButtonFormField<String>(
          initialValue: labels.any((l) => l.name == _selectedCategory)
              ? _selectedCategory
              : (labels.isNotEmpty ? labels.first.name : null),
          dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Category',
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: labels.map((label) {
            return DropdownMenuItem<String>(
              value: label.name,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(
                        int.parse(label.color.replaceFirst('#', '0xFF')),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(label.name),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCategory = value;
              });
              widget.onChanged(value);
            }
          },
        );
      },
    );
  }
}
