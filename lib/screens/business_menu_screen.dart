import 'package:flutter/material.dart';

class BusinessMenuScreen extends StatelessWidget {
  const BusinessMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Business Management'),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage your business documents',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildMenuCard(
              context,
              title: 'Quotations',
              subtitle: 'Create and manage quotations for leads',
              icon: Icons.description,
              color: const Color(0xFF6C5CE7),
              onTap: () {
                Navigator.pushNamed(context, '/quotations');
              },
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              context,
              title: 'Invoices',
              subtitle: 'Track payments and manage invoices',
              icon: Icons.receipt_long,
              color: const Color(0xFF00D9FF),
              onTap: () {
                Navigator.pushNamed(context, '/invoices');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF16213E),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
