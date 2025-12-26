import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/label_service.dart';
import '../models/user_model.dart';
import '../models/label_model.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/profile_header.dart';
import 'company_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final int _currentIndex = 3;
  bool _notificationsEnabled = true;
  bool _autoSaveContacts = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
      ),
      backgroundColor: const Color(0xFF1A1A2E), // Match app's dark background
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // Profile/Sign-In Section
              if (authService.isSignedIn && authService.currentUser != null)
                _buildProfileSection(authService.currentUser!)
              else
                _buildSignInSection(authService),

              const SizedBox(height: 24),

              _buildSettingsSection('Preferences', [
                _buildSwitchTile(
                  'Notifications',
                  'Receive push notifications',
                  _notificationsEnabled,
                  (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  'Auto-save Contacts',
                  'Automatically save new call contacts',
                  _autoSaveContacts,
                  (value) {
                    setState(() {
                      _autoSaveContacts = value;
                    });
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // Manage Labels Section
              Consumer<LabelService>(
                builder: (context, labelService, child) {
                  return _buildSettingsSection('Manage Labels', [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Custom Categories/Roles (e.g., Jobs, Internship)',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (labelService.isLoading)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF6C5CE7),
                              ),
                            )
                          else if (labelService.labels.isEmpty)
                            const Text(
                              'No labels yet. Create your first label!',
                              style: TextStyle(color: Colors.grey),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: labelService.labels.map((label) {
                                return _buildLabelChip(label, labelService);
                              }).toList(),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showCreateLabelDialog(labelService),
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Create New Label'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C5CE7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]);
                },
              ),

              const SizedBox(height: 24),

              // Team Collaboration Section
              _buildSettingsSection('Team Collaborations', [
                _buildListTile(
                  'Setup Team',
                  'Create company profile and invite members',
                  Icons.group_add,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CompanyProfileScreen(),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // Business Operations Section
              _buildSettingsSection('Business Operations', [
                _buildListTile(
                  'Quotations & Invoices',
                  'Manage quotes and invoices for leads',
                  Icons.receipt_long,
                  () {
                    Navigator.pushNamed(context, '/business_menu');
                  },
                ),
              ]),

              const SizedBox(height: 24),
              _buildSettingsSection('Data Management', [
                _buildListTile(
                  'Export Data',
                  'Export your leads and tasks',
                  Icons.download,
                  () {},
                ),
                _buildListTile(
                  'Import Data',
                  'Import leads from file',
                  Icons.upload,
                  () {},
                ),
                _buildListTile(
                  'Clear Cache',
                  'Free up storage space',
                  Icons.cleaning_services,
                  () {},
                ),
              ]),
              const SizedBox(height: 24),
              _buildSettingsSection('About', [
                _buildListTile('Version', '1.0.0', Icons.info, () {}),
                _buildListTile(
                  'Terms of Service',
                  'Read our terms',
                  Icons.description,
                  () {},
                ),
                _buildListTile(
                  'Privacy Policy',
                  'How we protect your data',
                  Icons.privacy_tip,
                  () {},
                ),
              ]),
              const SizedBox(height: 24),

              // Only show logout if user is signed in
              if (authService.isSignedIn) _buildLogoutButton(authService),
            ],
          );
        },
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

  Widget _buildProfileSection(AppUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ProfileHeader(user: user),
      ],
    );
  }

  Widget _buildSignInSection(AuthService authService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF2A2A3E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: authService.isLoading
                ? null
                : () async {
                    final success = await authService.signInWithGoogle();
                    if (!success &&
                        authService.errorMessage != null &&
                        mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(authService.errorMessage!),
                          backgroundColor: Colors.red[700],
                        ),
                      );
                    }
                  },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: authService.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C5CE7),
                      ),
                    )
                  : Row(
                      children: [
                        // Google logo
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/google_logo.png',
                              width: 24,
                              height: 24,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback if image not found
                                return const Icon(
                                  Icons.g_mobiledata,
                                  color: Colors.blue,
                                  size: 32,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Quick and secure access to SBS',
                                style: TextStyle(
                                  color: Colors.grey[400],
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
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF2A2A3E), // Consistent dark card color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildListTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(AuthService authService) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B6B),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: authService.isLoading
            ? null
            : () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF2A2A3E),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Are you sure you want to logout?',
                      style: TextStyle(color: Colors.white),
                    ),
                    actions: [
                      TextButton(
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                        ),
                        child: const Text('Logout'),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await authService.signOut();
                        },
                      ),
                    ],
                  ),
                );
              },
        child: authService.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Logout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  // Build label chip widget
  Widget _buildLabelChip(Label label, LabelService labelService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color(int.parse(label.color.replaceFirst('#', '0xFF'))),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showEditLabelDialog(label, labelService),
            child: const Icon(Icons.edit, size: 16, color: Colors.white70),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _confirmDeleteLabel(label, labelService),
            child: const Icon(Icons.close, size: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // Show create label dialog
  void _showCreateLabelDialog(LabelService labelService) {
    final nameController = TextEditingController();
    String selectedColor = '#6C5CE7';

    final colors = [
      '#6C5CE7',
      '#00C853',
      '#2196F3',
      '#FF9800',
      '#FFD700',
      '#E91E63',
      '#00BCD4',
      '#FF5722',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: const Text(
            'Create New Label',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Label Name',
                  labelStyle: TextStyle(color: Colors.grey),
                  hintText: 'e.g., Jobs, Internship',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Color',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(color.replaceFirst('#', '0xFF')),
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a label name')),
                  );
                  return;
                }
                try {
                  await labelService.addLabel(name, selectedColor);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Label "$name" created successfully!'),
                      backgroundColor: const Color(0xFF6C5CE7),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
              ),
              child: const Text(
                'Create',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show edit label dialog
  void _showEditLabelDialog(Label label, LabelService labelService) {
    final nameController = TextEditingController(text: label.name);
    String selectedColor = label.color;

    final colors = [
      '#6C5CE7',
      '#00C853',
      '#2196F3',
      '#FF9800',
      '#FFD700',
      '#E91E63',
      '#00BCD4',
      '#FF5722',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: const Text(
            'Edit Label',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Label Name',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Color',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(color.replaceFirst('#', '0xFF')),
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a label name')),
                  );
                  return;
                }
                try {
                  final updatedLabel = label.copyWith(
                    name: name,
                    color: selectedColor,
                  );
                  await labelService.updateLabel(updatedLabel);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Label updated successfully!'),
                      backgroundColor: Color(0xFF6C5CE7),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
              ),
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Confirm delete label
  void _confirmDeleteLabel(Label label, LabelService labelService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text(
          'Delete Label?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${label.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await labelService.deleteLabel(label.id!);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Label "${label.name}" deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
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
}
