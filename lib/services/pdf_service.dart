import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/quotation_model.dart';
import '../models/quotation_item_model.dart';
import '../models/lead_model.dart';
import 'package:intl/intl.dart';

class PdfService {
  /// Generate a professional quotation PDF
  static Future<pw.Document> generateQuotationPDF({
    required Quotation quotation,
    required List<QuotationItem> items,
    required Lead lead,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(),
            pw.SizedBox(height: 20),
            _buildQuotationInfo(quotation),
            pw.SizedBox(height: 20),
            _buildCustomerInfo(lead),
            pw.SizedBox(height: 20),
            _buildItemsTable(items),
            pw.SizedBox(height: 20),
            _buildTotals(quotation),
            if (quotation.notes != null && quotation.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildNotes(quotation.notes!),
            ],
            if (quotation.termsAndConditions != null &&
                quotation.termsAndConditions!.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildTerms(quotation.termsAndConditions!),
            ],
            pw.Spacer(),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf;
  }

  /// Build header section with company branding
  static pw.Widget _buildHeader() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'SBS',
              style: pw.TextStyle(
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.deepPurple,
              ),
            ),
            pw.Text(
              'Business Solutions',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'QUOTATION',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  /// Build quotation information section
  static pw.Widget _buildQuotationInfo(Quotation quotation) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Quotation #: ${quotation.quotationNumber}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date: ${dateFormat.format(quotation.createdAt)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Valid Until: ${dateFormat.format(quotation.validUntil)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: _getStatusColor(quotation.status),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  quotation.status.toUpperCase(),
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build customer information section
  static pw.Widget _buildCustomerInfo(Lead lead) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Bill To:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            lead.name,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if (lead.phoneNumber != null)
            pw.Text(
              'Phone: ${lead.phoneNumber}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          if (lead.email != null)
            pw.Text(
              'Email: ${lead.email}',
              style: const pw.TextStyle(fontSize: 10),
            ),
        ],
      ),
    );
  }

  /// Build items table
  static pw.Widget _buildItemsTable(List<QuotationItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('Item Description', isHeader: true),
            _buildTableCell('Qty', isHeader: true),
            _buildTableCell('Unit', isHeader: true),
            _buildTableCell('Price', isHeader: true),
            _buildTableCell('Total', isHeader: true),
          ],
        ),
        // Data rows
        ...items.map((item) {
          return pw.TableRow(
            children: [
              _buildTableCell(
                '${item.itemName}\n${item.description != null && item.description!.isNotEmpty ? item.description : ''}',
                isHeader: false,
              ),
              _buildTableCell(item.quantity.toString(), isHeader: false),
              _buildTableCell(item.unit, isHeader: false),
              _buildTableCell(
                '₹${item.unitPrice.toStringAsFixed(2)}',
                isHeader: false,
              ),
              _buildTableCell(
                '₹${item.totalPrice.toStringAsFixed(2)}',
                isHeader: false,
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Build table cell
  static pw.Widget _buildTableCell(String text, {required bool isHeader}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 11 : 10,
        ),
      ),
    );
  }

  /// Build totals section
  static pw.Widget _buildTotals(Quotation quotation) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            _buildTotalRow('Subtotal', quotation.subtotal),
            if (quotation.discountPercent > 0) ...[
              pw.SizedBox(height: 4),
              _buildTotalRow(
                'Discount (${quotation.discountPercent}%)',
                -quotation.discountAmount,
              ),
            ],
            pw.SizedBox(height: 4),
            _buildTotalRow(
              'Taxable Amount',
              quotation.subtotal - quotation.discountAmount,
            ),
            pw.SizedBox(height: 4),
            _buildTotalRow('Tax (${quotation.taxRate}%)', quotation.taxAmount),
            pw.Divider(thickness: 2),
            _buildTotalRow('Grand Total', quotation.totalAmount, isBold: true),
          ],
        ),
      ),
    );
  }

  /// Build total row
  static pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: isBold ? 12 : 10,
          ),
        ),
        pw.Text(
          'Rs. ${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: isBold ? 12 : 10,
          ),
        ),
      ],
    );
  }

  /// Build notes section
  static pw.Widget _buildNotes(String notes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Notes:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  /// Build terms and conditions section
  static pw.Widget _buildTerms(String terms) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Terms & Conditions:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Text(terms, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  /// Build footer
  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 8),
        pw.Text(
          'Thank you for your business!',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(
          'Generated by SBS CRM',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  /// Get status color
  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return PdfColors.grey;
      case 'sent':
        return PdfColors.blue;
      case 'accepted':
        return PdfColors.green;
      case 'rejected':
        return PdfColors.red;
      case 'converted':
        return PdfColors.purple;
      default:
        return PdfColors.grey;
    }
  }

  /// Save and share PDF
  static Future<void> saveAndSharePDF({
    required pw.Document pdf,
    required String fileName,
  }) async {
    try {
      // Get the appropriate directory for sharing
      // Use external storage on Android for better sharing compatibility with WhatsApp, etc.
      Directory output;
      if (Platform.isAndroid) {
        // External storage directory is accessible by other apps
        final externalDir = await getExternalStorageDirectory();
        output = externalDir ?? await getTemporaryDirectory();
        debugPrint('📂 Using directory: ${output.path}');
      } else {
        output = await getTemporaryDirectory();
      }

      final file = File('${output.path}/$fileName.pdf');

      // Write PDF to file
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);
      debugPrint('✅ PDF saved to: ${file.path}');
      debugPrint('📊 PDF size: ${bytes.length} bytes');

      // Verify file exists and is readable
      if (!await file.exists()) {
        throw Exception('PDF file was not created successfully');
      }

      final fileSize = await file.length();
      debugPrint('📁 File size on disk: $fileSize bytes');

      // Try to share the file
      debugPrint('📤 Attempting to share PDF...');
      try {
        final result = await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: fileName,
          text: 'Quotation from SBS CRM',
        );

        debugPrint('✅ Share result: ${result.status}');

        // If share was dismissed, that's still OK
        if (result.status == ShareResultStatus.dismissed) {
          debugPrint('ℹ️ User dismissed share dialog');
        } else if (result.status == ShareResultStatus.success) {
          debugPrint('✅ PDF shared successfully');
        }
      } catch (shareError) {
        debugPrint('❌ Share error: $shareError');
        // Re-throw so the UI can show the error
        throw Exception('Failed to open share dialog: $shareError');
      }
    } catch (e) {
      debugPrint('❌ PDF error: $e');
      throw Exception('Failed to save PDF: $e');
    }
  }

  /// Preview PDF by opening it with device's default PDF viewer
  static Future<void> previewPDF({
    required pw.Document pdf,
    required String fileName,
  }) async {
    try {
      // Save PDF to external storage first
      Directory output;
      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        output = externalDir ?? await getTemporaryDirectory();
      } else {
        output = await getTemporaryDirectory();
      }

      final file = File('${output.path}/$fileName.pdf');
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);

      debugPrint('✅ PDF saved for preview: ${file.path}');

      // Open PDF with default viewer using share
      // This is more reliable than Printing.layoutPdf on Android
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/pdf'),
      ], subject: fileName);

      debugPrint('✅ PDF preview opened');
    } catch (e) {
      debugPrint('❌ Preview error: $e');
      throw Exception('Failed to preview PDF: $e');
    }
  }

  /// Save PDF to device
  static Future<String> savePDFToDevice({
    required pw.Document pdf,
    required String fileName,
  }) async {
    try {
      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/$fileName.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    } catch (e) {
      throw Exception('Failed to save PDF: $e');
    }
  }
}
