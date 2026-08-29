import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Handles downloading rendered clips to local device storage.
class DownloadService {
  /// Download a file from a URL to the device's downloads directory.
  ///
  /// Returns the local file path.
  Future<String> downloadFile(String url, String filename) async {
    final dir = await _getDownloadDirectory();
    final filePath = '${dir.path}/$filename';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Download failed with status ${response.statusCode}');
    }

    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  /// Get the appropriate download directory for the platform.
  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Use external storage downloads on Android
      final dir = Directory('/storage/emulated/0/Download/ClipCreator');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } else if (Platform.isWindows) {
      // Use the user's Downloads folder on Windows
      final userHome = Platform.environment['USERPROFILE'] ?? '';
      final dir = Directory('$userHome\\Downloads\\ClipCreator');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } else {
      // Fallback to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/ClipCreator');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }
}
