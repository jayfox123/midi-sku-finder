import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String changelog;
  final String apkUrl;
  final String htmlUrl;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.changelog,
    required this.apkUrl,
    required this.htmlUrl,
  });
}

class UpdateService {
  static const String _githubReleaseUrl =
      'https://api.github.com/repos/jayfox123/midi-sku-finder/releases/latest';

  /// Fetches current app version from pubspec.yaml via PackageInfo.
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Checks GitHub API for the latest release.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final currentVerStr = await getCurrentVersion();
      final response = await http.get(
        Uri.parse(_githubReleaseUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawTag = (data['tag_name'] as String? ?? '').trim();
      final cleanLatestVer = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;

      if (cleanLatestVer.isEmpty) return null;

      final changelog = data['body'] as String? ?? 'Bug fixes & performance improvements.';
      final htmlUrl = data['html_url'] as String? ?? 'https://github.com/jayfox123/midi-sku-finder';

      // Find .apk asset download URL
      String apkUrl = '';
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String? ?? '';
          break;
        }
      }

      final hasUpdate = _isVersionHigher(cleanLatestVer, currentVerStr);

      return UpdateInfo(
        currentVersion: currentVerStr,
        latestVersion: cleanLatestVer,
        hasUpdate: hasUpdate,
        changelog: changelog,
        apkUrl: apkUrl,
        htmlUrl: htmlUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Trigger OTA Update stream or fallback installer.
  static Stream<OtaEvent> downloadAndInstallOta(String apkUrl) {
    return OtaUpdate().execute(
      apkUrl,
      destinationFilename: 'midi-sku-finder-update.apk',
    );
  }

  /// Fallback manual HTTP downloader with progress callback and OpenFilex.
  static Future<bool> downloadAndInstallHttp({
    required String apkUrl,
    required void Function(double progress) onProgress,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) return false;

      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/update.apk');
      final sink = file.openWrite();

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(downloadedBytes / totalBytes);
        }
      });

      await sink.flush();
      await sink.close();

      final result = await OpenFilex.open(file.path);
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }

  /// Compares semantic versions (e.g. "1.0.1" > "1.0.0").
  static bool _isVersionHigher(String latest, String current) {
    try {
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < lParts.length && i < cParts.length; i++) {
        if (lParts[i] > cParts[i]) return true;
        if (lParts[i] < cParts[i]) return false;
      }
      return lParts.length > cParts.length;
    } catch (_) {
      return false;
    }
  }
}
