import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/data_service.dart';

/// Not used on mobile/desktop
void triggerBrowserDownload(String url) {
  throw UnsupportedError('Browser download only supported on web');
}

/// Mobile/Desktop: fetch bytes, save to temp file, share
Future<void> downloadAndShare(
    BuildContext context, DataService dataService, String type, String url) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating Excel...', style: TextStyle(fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    ),
  );

  try {
    final bytes = await dataService.downloadExport(type);
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate export'), backgroundColor: Colors.red),
      );
      return;
    }

    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}';
    final fileName = '${type}_Report_$dateStr.xlsx';
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes);

    await Share.shareXFiles([XFile(filePath)], subject: '$type Report');
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
