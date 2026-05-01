import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/data_service.dart';
import 'export_helper_web.dart' if (dart.library.io) 'export_helper_stub.dart'
    as platform;

/// Reusable helper for exporting data to Excel across screens
class ExportHelper {
  /// Download an Excel export and share/save the file.
  /// [type]: 'gst-billing', 'revenue', 'production', 'inventory', 'payments'
  static Future<void> exportToExcel(
    BuildContext context,
    DataService dataService,
    String type, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Build the export URL
    var url = '${dotenv.env['API_URL']}/exports/$type';
    final params = <String>[];
    if (startDate != null) params.add('startDate=${startDate.toIso8601String()}');
    if (endDate != null) params.add('endDate=${endDate.toIso8601String()}');
    if (params.isNotEmpty) url += '?${params.join('&')}';

    if (kIsWeb) {
      // On Web: trigger native browser download
      platform.triggerBrowserDownload(url);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.file_download, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Downloading ${_getSubject(type)}...'),
            ]),
            backgroundColor: const Color(0xFF4A90E2),
          ),
        );
      }
    } else {
      // On Mobile/Desktop: fetch bytes, save, share
      await platform.downloadAndShare(context, dataService, type, url);
    }
  }

  static String _getSubject(String type) {
    switch (type) {
      case 'gst-billing': return 'GST Billing Report';
      case 'revenue': return 'Revenue Report';
      case 'production': return 'Production Report';
      case 'inventory': return 'Inventory Report';
      case 'payments': return 'Payment Report';
      default: return 'Export Report';
    }
  }

  /// Builds a standard export icon button for AppBar actions
  static Widget exportButton({
    required BuildContext context,
    required DataService dataService,
    required String type,
    DateTime? startDate,
    DateTime? endDate,
    String tooltip = 'Export to Excel',
  }) {
    return IconButton(
      icon: const Icon(Icons.file_download_outlined),
      tooltip: tooltip,
      onPressed: () => exportToExcel(context, dataService, type,
          startDate: startDate, endDate: endDate),
    );
  }
}
