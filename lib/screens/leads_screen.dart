import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
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

class LeadsScreenState extends State<LeadsScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'all';
  final int _currentIndex = 1;
  late TabController _tabController;

  // Separate search for Leads tab
  String _leadsSearchQuery = '';
  final TextEditingController _leadsSearchController = TextEditingController();

  // Separate search for All Contacts tab
  String _contactsSearchQuery = '';
  final TextEditingController _contactsSearchController =
      TextEditingController();

  // Cache contacts to prevent re-fetching on every search
  List<Contact>? _cachedContacts;
  bool _isLoadingContacts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Load contacts when switching to All Contacts tab
      if (_tabController.index == 1 &&
          _cachedContacts == null &&
          !_isLoadingContacts) {
        _loadContacts();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _leadsSearchController.dispose();
    _contactsSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    if (_isLoadingContacts) return;
    setState(() => _isLoadingContacts = true);
    try {
      final contacts = await _getLocalPhoneContacts();
      setState(() {
        _cachedContacts = contacts;
        _isLoadingContacts = false;
      });
    } catch (e) {
      setState(() => _isLoadingContacts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadsService = Provider.of<LeadsService>(context);

    // Filter out contact-imported leads from Leads tab (only show in Dashboard)
    var leads = leadsService.leads
        .where((lead) => lead.source != 'phone_import')
        .toList();

    // Apply search filter for LEADS TAB ONLY
    if (_leadsSearchQuery.isNotEmpty) {
      leads = leads.where((lead) {
        return lead.name.toLowerCase().contains(
              _leadsSearchQuery.toLowerCase(),
            ) ||
            (lead.phoneNumber?.toLowerCase().contains(
                  _leadsSearchQuery.toLowerCase(),
                ) ??
                false) ||
            (lead.email?.toLowerCase().contains(
                  _leadsSearchQuery.toLowerCase(),
                ) ??
                false);
      }).toList();
    }

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
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: const Color(0xFF1A1A2E),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6C5CE7),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF6C5CE7),
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Leads'),
                Tab(text: 'All Contacts'),
              ],
            ),
          ),
          // Expanded TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderTabContent(filteredLeads),
                _buildAllContactsTabContent(leadsService.leads),
              ],
            ),
          ),
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

  // Leader Tab - CRM contacts only (manually added)
  Widget _buildLeaderTabContent(List<Lead> leads) {
    // Filter for CRM contacts only (exclude phone imports)
    final leaderContacts = leads.where((lead) => lead.source == 'crm').toList();
    var filteredLeads = leaderContacts;

    if (_selectedFilter != 'all') {
      filteredLeads = filteredLeads
          .where((lead) => lead.category == _selectedFilter)
          .toList();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildLeadsSearchBar()),
        SliverToBoxAdapter(child: const SizedBox(height: 16)),
        SliverToBoxAdapter(child: _buildFilterChips()),
        SliverToBoxAdapter(child: _buildLeadStats(filteredLeads)),
        _buildLeadsList(filteredLeads),
      ],
    );
  }

  Widget _buildLeadsSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _leadsSearchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search leads...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _leadsSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _leadsSearchController.clear();
                      _leadsSearchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF2A2A3E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _leadsSearchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildContactsSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _contactsSearchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _contactsSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _contactsSearchController.clear();
                      _contactsSearchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF2A2A3E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _contactsSearchQuery = value;
          });
        },
      ),
    );
  }

  // All Contacts Tab - Use cached contacts for better performance
  Widget _buildAllContactsTabContent(List<Lead> leads) {
    // Load contacts if not loaded yet
    if (_cachedContacts == null && !_isLoadingContacts) {
      _loadContacts();
    }

    // Show loading indicator
    if (_isLoadingContacts || _cachedContacts == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
      );
    }

    final allContacts = _cachedContacts!;

    // Remove duplicates - keep only unique phone numbers
    final Map<String, Contact> uniqueContacts = {};
    for (var contact in allContacts) {
      final phone = contact.phones.isNotEmpty
          ? contact.phones.first.number.replaceAll(RegExp(r'[^\d+]'), '')
          : '';

      // Only add if phone is not empty and not already in map
      if (phone.isNotEmpty && !uniqueContacts.containsKey(phone)) {
        uniqueContacts[phone] = contact;
      }
    }

    final contacts = uniqueContacts.values.toList();

    // Apply search filter for CONTACTS TAB ONLY
    var filteredContacts = contacts;
    if (_contactsSearchQuery.isNotEmpty) {
      filteredContacts = contacts.where((contact) {
        final name = contact.displayName.toLowerCase();
        final phone = contact.phones.isNotEmpty
            ? contact.phones.first.number.toLowerCase()
            : '';
        return name.contains(_contactsSearchQuery.toLowerCase()) ||
            phone.contains(_contactsSearchQuery.toLowerCase());
      }).toList();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildContactsSearchBar()),
        SliverToBoxAdapter(child: const SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.contacts, color: Color(0xFF6C5CE7)),
                const SizedBox(width: 8),
                Text(
                  '${filteredContacts.length} Phone Contacts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: filteredContacts.isEmpty
              ? const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No contacts found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final contact = filteredContacts[index];
                    final phone = contact.phones.isNotEmpty
                        ? contact.phones.first.number
                        : '';
                    return GestureDetector(
                      onTap: () async {
                        // Find or create lead for this contact
                        final leadsService = Provider.of<LeadsService>(
                          context,
                          listen: false,
                        );

                        // Check if lead already exists by phone number
                        Lead? existingLead;
                        if (phone.isNotEmpty) {
                          try {
                            existingLead = leadsService.leads.firstWhere(
                              (lead) => lead.phoneNumber == phone,
                            );
                          } catch (e) {
                            // No matching lead found, this is okay
                            existingLead = null;
                          }
                        }

                        if (!context.mounted) return;

                        if (existingLead != null) {
                          // Navigate to existing lead details
                          Navigator.pushNamed(
                            context,
                            '/lead_details',
                            arguments: existingLead,
                          );
                        } else {
                          // Show form to create new lead from contact
                          _showCreateLeadFromContactDialog(
                            context,
                            contact.displayName,
                            phone,
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A3E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF6C5CE7),
                              child: Text(
                                contact.displayName.isNotEmpty
                                    ? contact.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: filteredContacts.length),
                ),
        ),
      ],
    );
  }

  Future<List<Contact>> _getLocalPhoneContacts() async {
    if (await Permission.contacts.isGranted) {
      return await FlutterContacts.getContacts(withProperties: true);
    }
    await Permission.contacts.request();
    if (await Permission.contacts.isGranted) {
      return await FlutterContacts.getContacts(withProperties: true);
    }
    return [];
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
    final labelService = Provider.of<LabelService>(context, listen: false);

    // Check if labels exist
    if (labelService.labels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please create at least one category/label in Settings first',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    String selectedCategory = labelService.labels.first.name;
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
                      keyboardType: TextInputType.phone,
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
              child: const Text(
                'Add Lead',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                // Validate inputs
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Capture context-dependent values before async operation
                final errorMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final leadsService = context.read<LeadsService>();

                try {
                  final lead = Lead(
                    name: nameController.text.trim(),
                    category: selectedCategory,
                    status: selectedStatus,
                    createdAt: DateTime.now(),
                    phoneNumber: phoneController.text.trim().isNotEmpty
                        ? phoneController.text.trim()
                        : null,
                    assignedDate: assignedDate,
                    assignedTime: assignedTime?.format(context),
                    source: 'crm', // Mark as CRM-added lead
                  );

                  await leadsService.addLead(lead);

                  navigator.pop();

                  // Show success message
                  errorMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Lead "${lead.name}" added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  debugPrint('Error adding lead: $e');
                  errorMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error adding lead: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
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

  void _showCreateLeadFromContactDialog(
    BuildContext context,
    String contactName,
    String contactPhone,
  ) {
    final nameController = TextEditingController(text: contactName);
    final phoneController = TextEditingController(text: contactPhone);
    final emailController = TextEditingController();
    final descriptionController = TextEditingController();

    String? selectedCategory;
    String selectedStatus = 'New';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Consumer<LabelService>(
          builder: (context, labelService, child) {
            if (labelService.labels.isEmpty) {
              return AlertDialog(
                backgroundColor: const Color(0xFF2A2A3E),
                title: const Text(
                  'No Categories',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Please create at least one category in Settings first.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('OK'),
                  ),
                ],
              );
            }

            selectedCategory ??= labelService.labels.first.name;

            return AlertDialog(
              backgroundColor: const Color(0xFF2A2A3E),
              title: const Text(
                'Create Lead from Contact',
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
                            labelText: 'Name *',
                            labelStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1A1A2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
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
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Email (Optional)',
                            labelStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1A1A2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          dropdownColor: const Color(0xFF1A1A2E),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Category *',
                            labelStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1A1A2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: labelService.labels
                              .map(
                                (label) => DropdownMenuItem(
                                  value: label.name,
                                  child: Text(label.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          dropdownColor: const Color(0xFF1A1A2E),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Status',
                            labelStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1A1A2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: ['New', 'Contacted', 'Qualified', 'Converted']
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedStatus = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            labelStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1A1A2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Name is required'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final leadsService = Provider.of<LeadsService>(
                      context,
                      listen: false,
                    );

                    final newLead = Lead(
                      name: nameController.text.trim(),
                      phoneNumber: phoneController.text.trim().isNotEmpty
                          ? phoneController.text.trim()
                          : null,
                      email: emailController.text.trim().isNotEmpty
                          ? emailController.text.trim()
                          : null,
                      category: selectedCategory!,
                      status: selectedStatus,
                      description: descriptionController.text.trim().isNotEmpty
                          ? descriptionController.text.trim()
                          : null,
                      createdAt: DateTime.now(),
                      source: 'phone_import',
                    );

                    await leadsService.addLead(newLead);
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);

                    // Get the newly created lead and navigate to it
                    final createdLead = leadsService.leads.firstWhere(
                      (l) =>
                          l.phoneNumber == newLead.phoneNumber &&
                          l.name == newLead.name,
                    );

                    if (!context.mounted) return;
                    Navigator.pushNamed(
                      context,
                      '/lead_details',
                      arguments: createdLead,
                    );

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lead created successfully'),
                        backgroundColor: Color(0xFF6C5CE7),
                      ),
                    );
                  },
                  child: const Text(
                    'Create Lead',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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

        // Handle empty labels case
        if (labels.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No categories available. Create labels in Settings first.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        // Ensure selected category is valid
        final validCategory = labels.any((l) => l.name == _selectedCategory)
            ? _selectedCategory
            : labels.first.name;

        return DropdownButtonFormField<String>(
          initialValue: validCategory,
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
