import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/contact_sync_service.dart';

class EnhancedOnboardingScreen extends StatefulWidget {
  const EnhancedOnboardingScreen({super.key});

  @override
  State<EnhancedOnboardingScreen> createState() =>
      _EnhancedOnboardingScreenState();
}

class _EnhancedOnboardingScreenState extends State<EnhancedOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Match app theme
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildContactsPermissionPage(),
                  _buildPhonePermissionPage(),
                  _buildCallScreeningPage(),
                  _buildCallerIDPage(),
                  _buildBatteryOptimizationPage(),
                  _buildAutostartPage(), // New page
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (index) {
          // Changed from 5 to 6
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == _currentPage ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: index == _currentPage
                  ? const Color(0xFF6C5CE7)
                  : const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // Page 1: Contacts Permission
  Widget _buildContactsPermissionPage() {
    return _buildPermissionPage(
      icon: Icons.contacts,
      iconColor: const Color(0xFF00BCD4),
      title: 'Allow SBS CRM to access your contacts?',
      description: 'To show contact names during calls and sync with CRM',
      onAllow: () async {
        final status = await Permission.contacts.request();
        if (status.isGranted) {
          // Auto-import all contacts
          await _importAllContacts();
          _nextPage();
        } else {
          _showPermissionDeniedDialog('Contacts');
        }
      },
      onDeny: () {
        _showPermissionRequiredDialog('Contacts');
      },
    );
  }

  // Auto-import contacts after permission granted
  Future<void> _importAllContacts() async {
    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF2A2A3E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF6C5CE7)),
            SizedBox(height: 20),
            Text(
              'Importing your contacts...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    try {
      final ContactSyncService syncService = ContactSyncService();
      final result = await syncService.importAllContacts();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${result['success']} contacts imported • ${result['skipped']} already exist',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF6C5CE7),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      debugPrint('Contact import error: $e');
    }
  }

  // Page 2: Phone Permission
  Widget _buildPhonePermissionPage() {
    return _buildPermissionPage(
      icon: Icons.phone,
      iconColor: const Color(0xFF00BCD4),
      title: 'Allow SBS CRM to make and manage phone calls?',
      description: 'To detect incoming/outgoing calls and show overlay',
      onAllow: () async {
        final status = await Permission.phone.request();
        if (status.isGranted) {
          _nextPage();
        } else {
          _showPermissionDeniedDialog('Phone');
        }
      },
      onDeny: () {
        _showPermissionRequiredDialog('Phone');
      },
    );
  }

  // Page 3: Call Screening Setup
  Widget _buildCallScreeningPage() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shield Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA855F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.security, size: 60, color: Colors.white),
          ),

          const SizedBox(height: 40),

          const Text(
            'Call Screening',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),

          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'To block spam and identify callers reliably, please set CRM Call as your Call Screening app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 60),

          // Set as Default Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ElevatedButton(
              onPressed: () {
                _openCallScreeningSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
              ),
              child: const Text(
                'Set as Default',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 20),

          TextButton(
            onPressed: _nextPage,
            child: const Text(
              'Skip for now',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // Page 4: Default Caller ID (Auto-request)
  Widget _buildCallerIDPage() {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA855F7)],
              ),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.phone_in_talk,
              size: 50,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'Default Caller ID',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'SBS needs to be set as your default Caller ID & Spam app to identify callers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFFAAAAAA),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 48),

          ElevatedButton(
            onPressed: _requestDefaultCallerIdRole,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Set as Default',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: _nextPage,
            child: const Text(
              'Skip',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          ),
        ],
      ),
    );
  }

  void _requestDefaultCallerIdRole() async {
    try {
      // Request to be default call screening app
      const platform = MethodChannel('com.example.sbs/call_screening');
      await platform.invokeMethod('requestDefaultRole');

      // Auto-proceed after request
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _nextPage();
        }
      });
    } catch (e) {
      debugPrint('Error requesting default role: $e');
      // Fallback: open settings
      await openAppSettings();
      _nextPage();
    }
  }

  // Page 5: Battery Optimization
  Widget _buildBatteryOptimizationPage() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Battery Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA855F7)],
              ),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.battery_charging_full,
              size: 60,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 40),

          const Text(
            'Keep App Running',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'To show SBS popup FIRST during calls, please disable battery restrictions:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFFAAAAAA)),
            ),
          ),

          const SizedBox(height: 24),

          // Important note
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6C5CE7), width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF6C5CE7)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap "Allow" on the next dialog to let SBS run in background',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Main Button - Disable Battery Restrictions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ElevatedButton.icon(
              onPressed: _requestBatteryOptimization,
              icon: const Icon(Icons.battery_saver),
              label: const Text(
                'Disable Battery Restrictions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
              ),
            ),
          ),

          const SizedBox(height: 20),

          TextButton(
            onPressed: _nextPage,
            child: const Text(
              'Skip for now',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // Generic permission page builder
  Widget _buildPermissionPage({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onAllow,
    required VoidCallback onDeny,
  }) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF252540),
            border: Border.all(color: const Color(0xFF6C5CE7), width: 1),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // White on dark card
                ),
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFAAAAAA),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Allow Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAllow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'ALLOW',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Don't Allow Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onDeny,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "DON'T ALLOW",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Page 6: Autostart Permission
  Widget _buildAutostartPage() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF8B7CE8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.autorenew, size: 60, color: Colors.white),
          ),

          const SizedBox(height: 40),

          const Text(
            'Enable Autostart',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          const Text(
            'Allow SBS to run in the background to monitor calls and provide real-time contact information.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFFAAAAAA),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          // Instructions Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6C5CE7), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How to enable:',
                  style: TextStyle(
                    color: Color(0xFF6C5CE7),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '1. Tap "Open Settings" below\n'
                  '2. Find "Autostart" or "Auto-start"\n'
                  '3. Enable for SBS\n'
                  '4. Return to this app',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Open Settings Button
          ElevatedButton.icon(
            onPressed: _openAutostartSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 8,
            ),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: _completeOnboarding,
            child: const Text(
              'Skip & Complete',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          ),
        ],
      ),
    );
  }

  void _openAutostartSettings() async {
    try {
      await openAppSettings();
      // Auto-complete after opening settings
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _completeOnboarding();
        }
      });
    } catch (e) {
      debugPrint('Error opening settings: $e');
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _nextPage() {
    if (_currentPage < 5) {
      // Changed from 4 to 5 for 6 pages
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showPermissionDeniedDialog(String permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permission Permission Required'),
        content: Text(
          '$permission permission is required for the app to function properly. Please grant it in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('OPEN SETTINGS'),
          ),
        ],
      ),
    );
  }

  void _showPermissionRequiredDialog(String permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
          '$permission permission is essential for SBS CRM to work. Would you like to proceed anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GO BACK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nextPage();
            },
            child: const Text('SKIP'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCallScreeningSettings() async {
    try {
      // Simply skip to next page - user can set manually
      _nextPage();
    } catch (e) {
      debugPrint('Error: $e');
      _nextPage();
    }
  }

  Future<void> _requestBatteryOptimization() async {
    try {
      // Request battery optimization exemption via native channel
      const platform = MethodChannel('com.example.sbs/battery');
      final result = await platform.invokeMethod(
        'requestBatteryOptimizationExemption',
      );
      debugPrint('Battery optimization result: $result');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please tap "Allow" to disable battery restrictions'),
            backgroundColor: Color(0xFF6C5CE7),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error requesting battery optimization: $e');
      // Fallback to app settings
      await openAppSettings();
    }
  }
}
