import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import '../config/api_config.dart';

/// Hysteria2 Binary Downloader
/// Downloads platform-specific Hysteria2 binary from GitHub releases
class Hysteria2Downloader {
  static final Hysteria2Downloader _instance = Hysteria2Downloader._internal();
  factory Hysteria2Downloader() => _instance;
  Hysteria2Downloader._internal();

  /// Download progress callback: (downloadedBytes, totalBytes, percentage)
  void Function(int downloaded, int total, double percentage)? onProgress;

  /// Platform and architecture info
  static PlatformArchInfo get platformInfo {
    final rawPlatform = Platform.operatingSystem; // windows, linux, macos
    String arch;
    
    // Map platform names for backend API
    // Backend expects: windows, linux, darwin (not macos)
    String platform;
    switch (rawPlatform) {
      case 'macos':
        platform = 'darwin';
        break;
      case 'windows':
      case 'linux':
        platform = rawPlatform;
        break;
      default:
        platform = rawPlatform;
    }
    
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
      extension: rawPlatform == 'windows' ? '.exe' : '',
      targetName: 'hysteria2-${platform}-${arch}',
    );
  }

  /// Get Windows Public app data directory (matches C++ code)
  Directory _getWindowsPublicDir() {
    // C:\Users\Public\VoyfyVPN - matches Windows C++ GetAppDataDir()
    return Directory('C:\\Users\\Public\\VoyfyVPN');
  }

  /// Get path where Hysteria2 binary should be stored
  /// Returns path to extracted hysteria2 binary, or expected path if not found
  Future<String> get binaryPath async {
    // First try to find existing hysteria2 binary
    final existing = await _findHysteria2Binary();
    if (existing != null) {
      return existing;
    }
    
    // Return expected path for new download
    if (Platform.isWindows) {
      // Windows: use Public directory (matches C++ code)
      final publicDir = _getWindowsPublicDir();
      if (!await publicDir.exists()) {
        await publicDir.create(recursive: true);
      }
      return '${publicDir.path}\\hysteria2.exe';
    } else {
      // Linux/macOS: use application support directory
      final appDir = await getApplicationSupportDirectory();
      final binDir = Directory('${appDir.path}/bin');
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }
      return '${binDir.path}/hysteria2';
    }
  }

  /// Find Hysteria2 binary in the correct directory
  Future<String?> _findHysteria2Binary() async {
    Directory searchDir;
    if (Platform.isWindows) {
      searchDir = _getWindowsPublicDir();
    } else {
      final appDir = await getApplicationSupportDirectory();
      searchDir = Directory('${appDir.path}/bin');
    }
    
    if (!await searchDir.exists()) {
      return null;
    }
    
    // Look for hysteria2 binary (exact match: 'hysteria2' or 'hysteria2.exe')
    await for (final entity in searchDir.list()) {
      if (entity is File) {
        final fileName = entity.path.split(Platform.pathSeparator).last;
        if (fileName == 'hysteria2' || fileName == 'hysteria2.exe') {
          final size = await entity.length();
          if (size > 5 * 1024 * 1024) { // Hysteria2 ~20MB
            return entity.path;
          }
        }
      }
    }
    return null;
  }

  /// Check if Hysteria2 binary exists and is valid
  Future<bool> isBinaryExists() async {
    final path = await _findHysteria2Binary();
    return path != null;
  }

  /// Download Hysteria2 binary from GitHub releases
  /// Extracts and returns path to binary on success, null on failure
  Future<String?> downloadHysteria2() async {
    try {
      final info = platformInfo;
      print('HYSTERIA2 DOWNLOADER: Platform: ${info.platform}, Arch: ${info.arch}');
      
      // GitHub release URL for Hysteria2 v2.5.1
      const version = 'app/v2.5.1';
      final downloadUrl = 'https://github.com/apernet/hysteria/releases/download/$version/hysteria-${info.platform}-${info.arch}${info.extension}';
      print('HYSTERIA2 DOWNLOADER: Downloading from: $downloadUrl');
      
      final response = await http.get(Uri.parse(downloadUrl));
      
      if (response.statusCode != 200) {
        print('HYSTERIA2 DOWNLOADER: Download failed with status ${response.statusCode}');
        return null;
      }
      
      print('HYSTERIA2 DOWNLOADER: Downloaded ${response.bodyBytes.length} bytes');
      
      // Get target path
      final targetPath = await binaryPath;
      final file = File(targetPath);
      
      // Write binary directly (no ZIP extraction needed for Hysteria2)
      await file.writeAsBytes(response.bodyBytes);
      print('HYSTERIA2 DOWNLOADER: Saved binary to: $targetPath');
      
      // Make executable on Unix systems
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', targetPath]);
      }
      
      print('HYSTERIA2 DOWNLOADER: Hysteria2 ready at: $targetPath');
      return targetPath;
      
    } catch (e) {
      print('HYSTERIA2 DOWNLOADER: Error downloading: $e');
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
      
      print('HYSTERIA2 DOWNLOADER: SHA256: $hashString');
      
      return hashString == expectedHash;
    } catch (e) {
      print('HYSTERIA2 DOWNLOADER: Error verifying checksum: $e');
      return false;
    }
  }

  /// Get checksum from GitHub releases for verification
  /// Note: Hysteria2 doesn't provide checksum API, skipping
  Future<String?> fetchChecksum() async {
    // Hysteria2 doesn't provide checksums via API
    return null;
  }

  /// Full download and verify flow
  Future<String?> downloadAndVerify() async {
    // Check if already exists
    if (await isBinaryExists()) {
      print('HYSTERIA2 DOWNLOADER: Binary already exists');
      final path = await binaryPath;
      return path;
    }
    
    // Download
    final path = await downloadHysteria2();
    if (path == null) {
      return null;
    }
    
    // Verify (optional) - Hysteria2 doesn't provide checksums
    final expectedHash = await fetchChecksum();
    if (expectedHash != null) {
      final isValid = await verifyChecksum(expectedHash);
      if (!isValid) {
        print('HYSTERIA2 DOWNLOADER: Checksum verification failed!');
        // Delete corrupted file
        await File(path).delete();
        return null;
      }
      print('HYSTERIA2 DOWNLOADER: Checksum verified successfully');
    }
    
    return path;
  }

  /// Download and install Hysteria2 binary
  Future<String?> downloadAndInstall() async {
    return await downloadAndVerify();
  }

  /// Static method to download and verify Hysteria2 (used by VpnService)
  static Future<bool> downloadAndVerifyHysteria2() async {
    final downloader = Hysteria2Downloader();
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
