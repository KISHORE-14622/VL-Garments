// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../services/data_service.dart';

/// Triggers a native browser file download via anchor element
void triggerBrowserDownload(String url) {
  html.AnchorElement(href: url)
    ..setAttribute('download', '')
    ..click();
}

/// Not used on web (we use triggerBrowserDownload instead)
Future<void> downloadAndShare(
    BuildContext context, DataService ds, String type, String url) async {}
