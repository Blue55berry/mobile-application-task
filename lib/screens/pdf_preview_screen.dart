import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';
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
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing PDF for sharing...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Save PDF to cache directory (accessible for sharing)
      Directory? output;
      if (Platform.isAndroid) {
        // Use app documents directory - accessible via FileProvider for sharing
        output = await getApplicationDocumentsDirectory();
        debugPrint('📂 Using app documents: ${output.path}');
      } else {
        output = await getTemporaryDirectory();
      }

      final file = File('${output.path}/$fileName.pdf');

      // Generate PDF bytes with error handling
      Uint8List bytes;
      try {
        bytes = await pdf.save();
        debugPrint('📄 PDF bytes generated: ${bytes.length}');

        // Validate PDF header (should start with %PDF)
        if (bytes.length < 4 ||
            String.fromCharCodes(bytes.sublist(0, 4)) != '%PDF') {
          throw Exception('Invalid PDF: Missing PDF header');
        }

        debugPrint('✅ PDF header validated');
      } catch (e) {
        debugPrint('❌ PDF generation error: $e');
        rethrow;
      }

      // Write to file with explicit error handling
      try {
        final randomAccessFile = await file.open(mode: FileMode.write);
        await randomAccessFile.writeFrom(bytes);
        await randomAccessFile.flush();
        await randomAccessFile.close();

        debugPrint('✅ PDF written to disk');
      } catch (e) {
        debugPrint('❌ File write error: $e');
        rethrow;
      }

      // Verify file exists
      if (!await file.exists()) {
        throw Exception('PDF file was not saved successfully');
      }

      final fileSize = await file.length();
      debugPrint('📁 File verified: $fileSize bytes on disk');

      // Share the file
      debugPrint('📤 Attempting to share...');
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: fileName,
        text: 'Quotation from SBS',
      );

      debugPrint('✅ Share result: ${result.status}');

      if (result.status == ShareResultStatus.success) {
        debugPrint('✅ PDF shared successfully');
      } else if (result.status == ShareResultStatus.dismissed) {
        debugPrint('ℹ️ Share dialog dismissed');
      }
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
