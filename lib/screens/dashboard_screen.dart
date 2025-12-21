import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/lead_item.dart';
import '../widgets/bottom_nav_bar.dart';
import '../models/lead_model.dart';
import '../services/leads_service.dart';
import '../services/team_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final int _currentIndex = 0;

  String _selectedCategory = 'all';
  String _searchQuery = ''; // Add this line

  @override
  Widget build(BuildContext context) {
    final leadsService = Provider.of<LeadsService>(context);
    final recentLeads = leadsService.leads;

    final pendingResponse = recentLeads
        .where((lead) => lead.status == 'New')
        .length;
    final newLeadsToday = recentLeads.where((lead) {
      final now = DateTime.now();
      return lead.createdAt.year == now.year &&
          lead.createdAt.month == now.month &&
          lead.createdAt.day == now.day;
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildCategoryTabs(),
                const SizedBox(height: 20),
                _buildTotalLeadsCard(recentLeads),
                const SizedBox(height: 20),
                _buildStatsRow(
                  pendingResponse: pendingResponse,
                  newLeadsToday: newLeadsToday,
                ),
                const SizedBox(height: 20),
                _buildRecentLeadsSection(recentLeads),
                const SizedBox(height: 20),
                _buildTeamCard(),
              ],
            ),
          ),
        ),
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

  Widget _buildHeader() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.currentUser;
        final now = DateTime.now();
        String greetingHourText = 'Good Morning';
        if (now.hour >= 12 && now.hour < 17) {
          greetingHourText = 'Good Afternoon';
        } else if (now.hour >= 17 || now.hour < 4) {
          greetingHourText = 'Good Evening';
        }

        return Column(
          children: [
            const SizedBox(height: 8),
            // Top row: Profil + Search
            Row(
              children: [
                // Profile Avatar
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: user != null
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF6C5CE7), Color(0xFF8B7CE8)],
                              ),
                      ),
                      child: user != null && user.photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                user.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultAvatar(user);
                                },
                              ),
                            )
                          : _buildDefaultAvatar(user),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Search Box
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: const Color(0xFF3A3A4E),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search leads...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey[500],
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Welcome Text below
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user != null
                          ? '$greetingHourText, ${user.displayName.split(' ').first}!'
                          : 'Welcome to SBS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user != null
                          ? user.email
                          : 'Manage your leads efficiently',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDefaultAvatar(AppUser? user) {
    String initial = 'U';

    if (user != null) {
      if (user.displayName.isNotEmpty) {
        initial = user.displayName[0].toUpperCase();
      } else if (user.email.isNotEmpty) {
        initial = user.email[0].toUpperCase();
      }
    }

    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryChip('All', 'all'),
          _buildCategoryChip('Jobs', 'jobs'),
          _buildCategoryChip('Internship', 'internship'),
          _buildCategoryChip('Paid Internship', 'paid_internship'),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _selectedCategory = value;
          });
        },
        backgroundColor: const Color(0xFF2A2A3E),
        selectedColor: const Color(0xFF6C5CE7),
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
      ),
    );
  }

  Widget _buildTotalLeadsCard(List<Lead> recentLeads) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A3E), Color(0xFF3A3A4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Leads',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            recentLeads.length.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _getSpots(),
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                    ),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(
                            0xFF6C5CE7,
                          ).withAlpha((255 * 0.3).round()),
                          const Color(
                            0xFFA29BFE,
                          ).withAlpha((255 * 0.1).round()),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _getSpots() {
    return [
      const FlSpot(0, 3),
      const FlSpot(1, 1),
      const FlSpot(2, 4),
      const FlSpot(3, 2),
      const FlSpot(4, 5),
      const FlSpot(5, 3),
      const FlSpot(6, 6),
    ];
  }

  Widget _buildStatsRow({
    required int pendingResponse,
    required int newLeadsToday,
  }) {
    return Row(
      children: [
        Expanded(
          child: DashboardCard(
            title: 'Pending Response',
            value: pendingResponse.toString(),
            icon: Icons.pending_actions,
            color: const Color(0xFFFF6B6B),
            showChart: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DashboardCard(
            title: "Today's Leads",
            value: newLeadsToday.toString(),
            icon: Icons.trending_up,
            color: const Color(0xFF4ECDC4),
            showChart: true,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentLeadsSection(List<Lead> recentLeads) {
    var filteredLeads = _selectedCategory == 'all'
        ? recentLeads
        : recentLeads
              .where((lead) => lead.category == _selectedCategory)
              .toList();

    if (_searchQuery.isNotEmpty) {
      filteredLeads = filteredLeads
          .where(
            (lead) =>
                lead.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (lead.phoneNumber?.contains(_searchQuery) ?? false),
          )
          .toList();
    }

    // Limit to 5 leads for dashboard
    final displayLeads = filteredLeads.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Leads',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (filteredLeads.length > 5)
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/leads');
                },
                child: const Text(
                  'See More →',
                  style: TextStyle(
                    color: Color(0xFF6C5CE7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        displayLeads.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No leads yet',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                itemCount: displayLeads.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final lead = displayLeads[index];
                  return LeadItem(lead: lead);
                },
              ),
      ],
    );
  }

  Widget _buildTeamCard() {
    return Consumer<TeamService>(
      builder: (context, teamService, child) {
        if (!teamService.hasTeamData) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Company Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                _showTeamDetails(context, teamService);
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A2A3E), Color(0xFF3A3A4E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.business,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teamService.companyName ?? 'My Company',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.people,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${teamService.memberCount} ${teamService.memberCount == 1 ? "member" : "members"}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        teamService.companyType ?? '',
                        style: const TextStyle(
                          color: Color(0xFF6C5CE7),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white54,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTeamDetails(BuildContext context, TeamService teamService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teamService.companyName ?? 'My Company',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              teamService.companyType ?? '',
                              style: const TextStyle(
                                color: Color(0xFF6C5CE7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow(
                    'Company Size',
                    teamService.companySize ?? 'N/A',
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF2A2A3E)),
                  const SizedBox(height: 16),
                  Text(
                    'Team Members (${teamService.memberCount})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: teamService.teamMembers.isEmpty
                  ? const Center(
                      child: Text(
                        'No team members added yet',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: teamService.teamMembers.length,
                      itemBuilder: (context, index) {
                        final email = teamService.teamMembers[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A3E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF6C5CE7),
                                child: Text(
                                  email[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  email,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
