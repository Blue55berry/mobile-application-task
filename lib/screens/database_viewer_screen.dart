import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../models/lead_model.dart';

class DatabaseViewerScreen extends StatefulWidget {
  const DatabaseViewerScreen({super.key});
  @override
  DatabaseViewerScreenState createState() => DatabaseViewerScreenState();
}

class DatabaseViewerScreenState extends State<DatabaseViewerScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Lead> _leads = [];
  String _searchQuery = '';

  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final leads = await _dbService.getLeads();
      final stats = await _dbService.getDatabaseStats();

      setState(() {
        _leads = leads;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Database Viewer'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Leads', icon: Icon(Icons.people)),
            Tab(text: 'Statistics', icon: Icon(Icons.analytics)),
            Tab(text: 'Export', icon: Icon(Icons.download)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildLeadsTab(), _buildStatisticsTab(), _buildExportTab()],
      ),
    );
  }

  Widget _buildLeadsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search leads by name, phone, or email...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF2A2A3E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),

        // Leads list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredLeads.length,
            itemBuilder: (context, index) {
              final lead = _filteredLeads[index];
              return _buildLeadCard(lead);
            },
          ),
        ),
      ],
    );
  }

  List<Lead> get _filteredLeads {
    if (_searchQuery.isEmpty) {
      return _leads;
    }
    final searchLower = _searchQuery.toLowerCase();
    return _leads.where((lead) {
      return (lead.name.toLowerCase().contains(searchLower) ||
          (lead.phoneNumber?.toLowerCase().contains(searchLower) ?? false) ||
          (lead.email?.toLowerCase().contains(searchLower) ?? false));
    }).toList();
  }

  Color _getRoleColor(String category) {
    switch (category) {
      case 'jobs':
        return const Color(0xFF4ECDC4);
      case 'internship':
        return const Color(0xFFA29BFE);
      case 'paid_internship':
        return const Color(0xFF6C5CE7);
      default:
        return Colors.grey;
    }
  }

  Widget _buildLeadCard(Lead lead) {
    return Card(
      color: const Color(0xFF2A2A3E),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(lead.category),
          child: Text(
            lead.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          lead.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phone: ${lead.phoneNumber ?? 'N/A'}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email: ${lead.email ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${lead.status}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Category: ${lead.category}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Created At: ${lead.createdAt.toLocal()}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last Call: ${lead.lastCallDate?.toLocal() ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Calls: ${lead.totalCalls}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Description: ${lead.description ?? 'No description.'}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final categoryCounts =
        _stats['categoryCounts'] as List<Map<String, dynamic>>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard(
            'Total Leads',
            _stats['totalLeads'].toString(),
            Icons.people,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            'Total Calls',
            _stats['totalCalls'].toString(),
            Icons.call,
            Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            'Leads by Category',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ...categoryCounts.map((category) {
            return Card(
              color: const Color(0xFF2A2A3E),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  category['category'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Text(
                  category['count'].toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      color: const Color(0xFF2A2A3E),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Export Coming Soon!',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final data = await _dbService.exportAllData();
              final dataString = data.toString();
              await Clipboard.setData(ClipboardData(text: dataString));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data copied to clipboard')),
              );
            },
            child: const Text('Copy Data to Clipboard'),
          ),
        ],
      ),
    );
  }
}
