import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PdfPreviewScreen extends StatelessWidget {
  final pw.Document pdf;
  final String fileName;

  const PdfPreviewScreen({
    super.key,
    required this.pdf,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(fileName),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share PDF',
            onPressed: () => _sharePDF(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdf.save(),
        allowSharing: true,
        allowPrinting: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }

  Future<void> _sharePDF(BuildContext context) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing PDF for sharing...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Use temporary directory for sharing
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/$fileName.pdf');

      // Generate PDF bytes
      final bytes = await pdf.save();

      // Write to file
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('✅ PDF written to disk: ${file.path}');

      // Share the file
      debugPrint('📤 Attempting to share...');
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: fileName,
        text: 'Quotation from SBS CRM',
      );

      debugPrint('✅ Share result: ${result.status}');
    } catch (e) {
      debugPrint('❌ Share error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
