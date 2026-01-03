import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateChecker {
  final String updateUrl =
      'https://ravell.wasmer.app/updates/check_update.php';

  Future<void> checkUpdate(BuildContext context) async {
    final response = await http.get(Uri.parse(updateUrl));
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    if (data['error'] != null) return;

    final remoteVersion = data['version'];
    final apkUrl = data['url'];

    final info = await PackageInfo.fromPlatform();
    final localVersion = info.version;

    if (_isNewer(remoteVersion, localVersion)) {
      _showDialog(context, remoteVersion, apkUrl);
    }
  }

  bool _isNewer(String r, String l) {
    final rv = r.split('.').map(int.parse).toList();
    final lv = l.split('.').map(int.parse).toList();

    for (int i = 0; i < rv.length; i++) {
      final lvPart = i < lv.length ? lv[i] : 0;
      if (rv[i] > lvPart) return true;
      if (rv[i] < lvPart) return false;
    }
    return false;
  }

  void _showDialog(BuildContext context, String version, String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Доступно обновление'),
        content: Text('Новая версия: $version'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Позже'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Скачать'),
          ),
        ],
      ),
    );
  }
}
