import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';

/// Xray Binary Downloader
/// Downloads platform-specific Xray binary from backend server
class XrayDownloader {
  static final XrayDownloader _instance = XrayDownloader._internal();
  factory XrayDownloader() => _instance;
  XrayDownloader._internal();

  /// Download progress callback: (downloadedBytes, totalBytes, percentage)
  void Function(int downloaded, int total, double percentage)? onProgress;

  /// Platform and architecture info
  static PlatformArchInfo get platformInfo {
    final platform = Platform.operatingSystem; // windows, linux, macos
    String arch;
    
    // Detect architecture
    if (Platform.version.contains('arm64') || 
        Platform.version.contains('aarch64') ||
        Platform.environment['PROCESSOR_ARCHITECTURE']?.toLowerCase().contains('arm') == true) {
      arch = 'arm64';
    } else {
      arch = 'amd64'; // x86_64
    }
    
    // Override for testing or specific platforms
    if (Platform.isMacOS && Platform.environment['ROSETTA'] == '1') {
      arch = 'amd64'; // Running under Rosetta
    }
    
    return PlatformArchInfo(
      platform: platform,
      arch: arch,
      extension: platform == 'windows' ? '.exe' : '',
      targetName: 'xray-${platform}-${arch}',
    );
  }

  /// Get path where Xray binary should be stored
  Future<String> get binaryPath async {
    final info = platformInfo;
    final appDir = await getApplicationSupportDirectory();
    final binDir = Directory('${appDir.path}/bin');
    
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }
    
    return '${binDir.path}/${info.targetName}${info.extension}';
  }

  /// Check if Xray binary exists and is valid
  Future<bool> isBinaryExists() async {
    final path = await binaryPath;
    final file = File(path);
    
    if (!await file.exists()) {
      return false;
    }
    
    // Check file size (should be > 10MB)
    final size = await file.length();
    if (size < 10 * 1024 * 1024) {
      print('XRAY DOWNLOADER: Binary too small (${size} bytes), likely corrupted');
      return false;
    }
    
    return true;
  }

  /// Download Xray binary from backend
  /// Returns path to binary on success, null on failure
  Future<String?> downloadXray() async {
    try {
      final info = platformInfo;
      print('XRAY DOWNLOADER: Platform: ${info.platform}, Arch: ${info.arch}');
      
      // Backend endpoint for Xray binary
      final downloadUrl = '${ApiConfig.baseUrl}/xray/download?platform=${info.platform}&arch=${info.arch}';
      print('XRAY DOWNLOADER: Downloading from: $downloadUrl');
      
      final request = http.Request('GET', Uri.parse(downloadUrl));
      
      // Add auth headers if needed
      // request.headers['Authorization'] = 'Bearer $token';
      
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) {
        print('XRAY DOWNLOADER: Download failed with status ${response.statusCode}');
        return null;
      }
      
      final contentLength = response.contentLength ?? 0;
      print('XRAY DOWNLOADER: Content length: $contentLength bytes');
      
      final path = await binaryPath;
      final file = File(path);
      final sink = file.openWrite();
      
      int downloaded = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        
        if (contentLength > 0 && onProgress != null) {
          final percentage = (downloaded / contentLength) * 100;
          onProgress!(downloaded, contentLength, percentage);
        }
      }
      
      await sink.close();
      
      // Make executable on Unix systems
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', path]);
      }
      
      print('XRAY DOWNLOADER: Download complete: $path');
      return path;
      
    } catch (e) {
      print('XRAY DOWNLOADER: Error downloading: $e');
      return null;
    }
  }

  /// Verify binary checksum (optional security)
  Future<bool> verifyChecksum(String expectedHash) async {
    try {
      final path = await binaryPath;
      final file = File(path);
      
      if (!await file.exists()) return false;
      
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes);
      final hashString = hash.toString();
      
      print('XRAY DOWNLOADER: SHA256: $hashString');
      
      return hashString == expectedHash;
    } catch (e) {
      print('XRAY DOWNLOADER: Error verifying checksum: $e');
      return false;
    }
  }

  /// Get checksum from backend for verification
  Future<String?> fetchChecksum() async {
    try {
      final info = platformInfo;
      final url = '${ApiConfig.baseUrl}/xray/checksum?platform=${info.platform}&arch=${info.arch}';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sha256'] as String?;
      }
      
      return null;
    } catch (e) {
      print('XRAY DOWNLOADER: Error fetching checksum: $e');
      return null;
    }
  }

  /// Full download and verify flow
  Future<String?> downloadAndVerify() async {
    // Check if already exists
    if (await isBinaryExists()) {
      print('XRAY DOWNLOADER: Binary already exists');
      final path = await binaryPath;
      return path;
    }
    
    // Download
    final path = await downloadXray();
    if (path == null) {
      return null;
    }
    
    // Verify (optional)
    final expectedHash = await fetchChecksum();
    if (expectedHash != null) {
      final isValid = await verifyChecksum(expectedHash);
      if (!isValid) {
        print('XRAY DOWNLOADER: Checksum verification failed!');
        // Delete corrupted file
        await File(path).delete();
        return null;
      }
      print('XRAY DOWNLOADER: Checksum verified successfully');
    }
    
    return path;
  }

  /// Download and install Xray binary
  Future<String?> downloadAndInstall() async {
    return await downloadAndVerify();
  }

  /// Static method to download and verify Xray (used by VpnService)
  static Future<bool> downloadAndVerifyXray() async {
    final downloader = XrayDownloader();
    final path = await downloader.downloadAndInstall();
    return path != null;
  }
}

/// Platform and architecture information
class PlatformArchInfo {
  final String platform;
  final String arch;
  final String extension;
  final String targetName;
  
  PlatformArchInfo({
    required this.platform,
    required this.arch,
    required this.extension,
    required this.targetName,
  });
  
  @override
  String toString() => 'PlatformArchInfo(platform: $platform, arch: $arch, target: $targetName$extension)';
}
