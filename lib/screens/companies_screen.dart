import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('Companies', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<CompanyService>(
        builder: (context, companyService, _) {
          if (companyService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
            );
          }

          if (!companyService.hasCompanies) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: companyService.companies.length,
            itemBuilder: (context, index) {
              final company = companyService.companies[index];
              final isActive = companyService.activeCompany?.id == company.id;

              return _buildCompanyCard(
                context,
                company,
                isActive,
                companyService,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCompanyDialog(context),
        backgroundColor: const Color(0xFF6C5CE7),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Company', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.business,
              size: 64,
              color: Color(0xFF6C5CE7),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Companies Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first company to get started',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showCompanyDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Company',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(
    BuildContext context,
    Company company,
    bool isActive,
    CompanyService companyService,
  ) {
    return GestureDetector(
      onTap: () => _showCompanyDetails(context, company),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF5B4CD6)],
                )
              : null,
          color: isActive ? null : const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.transparent : const Color(0xFF3A3A4E),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showCompanyDetails(context, company),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Company Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        company.initials,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : const Color(0xFF6C5CE7),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Company Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                company.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (company.type != null)
                          Text(
                            company.type!,
                            style: TextStyle(
                              color: isActive ? Colors.white70 : Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        if (company.email != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.email,
                                size: 14,
                                color: isActive ? Colors.white70 : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  company.email!,
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white70
                                        : Colors.grey,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions
                  PopupMenuButton(
                    color: const Color(0xFF2A2A3E),
                    icon: Icon(
                      Icons.more_vert,
                      color: isActive ? Colors.white : Colors.grey,
                    ),
                    itemBuilder: (context) => [
                      if (!isActive)
                        PopupMenuItem(
                          onTap: () {
                            Future.delayed(Duration.zero, () {
                              if (!context.mounted) return;
                              companyService.setActiveCompany(company);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${company.name} is now active',
                                  ),
                                  backgroundColor: const Color(0xFF6C5CE7),
                                ),
                              );
                            });
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Set Active',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        onTap: () {
                          Future.delayed(Duration.zero, () {
                            if (!context.mounted) return;
                            _showCompanyDialog(context, company: company);
                          });
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.edit, color: Colors.white),
                            SizedBox(width: 12),
                            Text('Edit', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        onTap: () {
                          Future.delayed(Duration.zero, () {
                            if (!context.mounted) return;
                            _showDeleteConfirmation(
                              context,
                              company,
                              companyService,
                            );
                          });
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCompanyDetails(BuildContext context, Company company) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6C5CE7,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              company.initials,
                              style: const TextStyle(
                                color: Color(0xFF6C5CE7),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                company.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (company.type != null)
                                Text(
                                  company.type!,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Details
                    if (company.email != null)
                      _buildDetailRow(Icons.email, 'Email', company.email!),
                    if (company.phone != null)
                      _buildDetailRow(Icons.phone, 'Phone', company.phone!),
                    if (company.website != null)
                      _buildDetailRow(
                        Icons.language,
                        'Website',
                        company.website!,
                      ),
                    if (company.industry != null)
                      _buildDetailRow(
                        Icons.business_center,
                        'Industry',
                        company.industry!,
                      ),
                    if (company.address != null)
                      _buildDetailRow(
                        Icons.location_on,
                        'Address',
                        company.address!,
                      ),

                    _buildDetailRow(
                      Icons.people,
                      'Members',
                      '${company.memberCount} ${company.memberCount == 1 ? "member" : "members"}',
                    ),

                    const SizedBox(height: 32),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showCompanyDialog(context, company: company);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C5CE7),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.edit, color: Colors.white),
                            label: const Text(
                              'Edit',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF6C5CE7), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCompanyDialog(BuildContext context, {Company? company}) {
    final nameController = TextEditingController(text: company?.name ?? '');
    final typeController = TextEditingController(text: company?.type ?? '');
    final industryController = TextEditingController(
      text: company?.industry ?? '',
    );
    final emailController = TextEditingController(text: company?.email ?? '');
    final phoneController = TextEditingController(text: company?.phone ?? '');
    final websiteController = TextEditingController(
      text: company?.website ?? '',
    );
    final addressController = TextEditingController(
      text: company?.address ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          company == null ? 'Add Company' : 'Edit Company',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(nameController, 'Company Name *', Icons.business),
              const SizedBox(height: 16),
              _buildTextField(
                typeController,
                'Type (e.g., Client, Vendor)',
                Icons.category,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                industryController,
                'Industry',
                Icons.business_center,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                emailController,
                'Email',
                Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                phoneController,
                'Phone',
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(websiteController, 'Website', Icons.language),
              const SizedBox(height: 16),
              _buildTextField(
                addressController,
                'Address',
                Icons.location_on,
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Company name is required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final companyService = context.read<CompanyService>();

              final newCompany = Company(
                id: company?.id,
                name: nameController.text.trim(),
                type: typeController.text.trim().isNotEmpty
                    ? typeController.text.trim()
                    : null,
                industry: industryController.text.trim().isNotEmpty
                    ? industryController.text.trim()
                    : null,
                email: emailController.text.trim().isNotEmpty
                    ? emailController.text.trim()
                    : null,
                phone: phoneController.text.trim().isNotEmpty
                    ? phoneController.text.trim()
                    : null,
                website: websiteController.text.trim().isNotEmpty
                    ? websiteController.text.trim()
                    : null,
                address: addressController.text.trim().isNotEmpty
                    ? addressController.text.trim()
                    : null,
                memberCount: company?.memberCount ?? 1,
                isActive: company?.isActive ?? true,
                createdAt: company?.createdAt ?? DateTime.now(),
              );

              bool success;
              if (company == null) {
                success = await companyService.addCompany(newCompany);
              } else {
                success = await companyService.updateCompany(newCompany);
              }

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              if (success) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      company == null
                          ? 'Company added successfully'
                          : 'Company updated successfully',
                    ),
                    backgroundColor: const Color(0xFF6C5CE7),
                  ),
                );

                // Show company details after creation/update
                final createdCompany = company == null
                    ? companyService.companies.first
                    : companyService.getCompanyById(company.id!);

                if (createdCompany != null) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (context.mounted) {
                      _showCompanyDetails(context, createdCompany);
                    }
                  });
                }
              }
            },
            child: Text(
              company == null ? 'Add' : 'Update',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFF6C5CE7)),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C5CE7)),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Company company,
    CompanyService companyService,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Company?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${company.name}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final success = await companyService.deleteCompany(company.id!);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Company deleted successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
