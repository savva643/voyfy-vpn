import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
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
      targetName: 'xray-${platform}-${arch}',
    );
  }

  /// Get Windows Public app data directory (matches C++ code)
  Directory _getWindowsPublicDir() {
    // C:\Users\Public\VoyfyVPN - matches Windows C++ GetAppDataDir()
    return Directory('C:\\Users\\Public\\VoyfyVPN');
  }

  /// Get path where Xray binary should be stored
  /// Returns path to extracted xray binary, or expected path if not found
  Future<String> get binaryPath async {
    // First try to find existing xray binary
    final existing = await _findXrayBinary();
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
      return '${publicDir.path}\\xray.exe';
    } else {
      // Linux/macOS: use application support directory
      final appDir = await getApplicationSupportDirectory();
      final binDir = Directory('${appDir.path}/bin');
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }
      return '${binDir.path}/xray';
    }
  }

  /// Find xray binary in the correct directory
  Future<String?> _findXrayBinary() async {
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
    
    // Look for xray binary (exact match: 'xray' or 'xray.exe')
    await for (final entity in searchDir.list()) {
      if (entity is File) {
        final fileName = entity.path.split(Platform.pathSeparator).last;
        if (fileName == 'xray' || fileName == 'xray.exe') {
          final size = await entity.length();
          if (size > 10 * 1024 * 1024) {
            return entity.path;
          }
        }
      }
    }
    return null;
  }

  /// Check if Xray binary exists and is valid
  Future<bool> isBinaryExists() async {
    final path = await _findXrayBinary();
    return path != null;
  }

  /// Download Xray binary from backend (ZIP archive)
  /// Extracts and returns path to binary on success, null on failure
  Future<String?> downloadXray() async {
    try {
      final info = platformInfo;
      print('XRAY DOWNLOADER: Platform: ${info.platform}, Arch: ${info.arch}');
      
      // Backend endpoint for Xray binary (returns ZIP)
      final downloadUrl = '${ApiConfig.baseUrl}/xray/download?platform=${info.platform}&arch=${info.arch}';
      print('XRAY DOWNLOADER: Downloading from: $downloadUrl');
      
      final response = await http.get(Uri.parse(downloadUrl));
      
      if (response.statusCode != 200) {
        print('XRAY DOWNLOADER: Download failed with status ${response.statusCode}');
        return null;
      }
      
      print('XRAY DOWNLOADER: Downloaded ${response.bodyBytes.length} bytes, extracting ZIP...');
      
      // Extract ZIP archive
      final archive = ZipDecoder().decodeBytes(response.bodyBytes);
      
      // Get target directory based on platform
      Directory extractDir;
      if (Platform.isWindows) {
        extractDir = _getWindowsPublicDir();
      } else {
        final appDir = await getApplicationSupportDirectory();
        extractDir = Directory('${appDir.path}/bin');
      }
      
      if (!await extractDir.exists()) {
        await extractDir.create(recursive: true);
      }
      
      String? xrayPath;
      
      for (final file in archive) {
        final fileName = file.name;
        final separator = Platform.isWindows ? '\\' : '/';
        final filePath = '${extractDir.path}$separator$fileName';
        
        if (file.isFile) {
          final data = file.content as List<int>;
          await File(filePath).writeAsBytes(data);
          print('XRAY DOWNLOADER: Extracted: $fileName (${data.length} bytes)');
          
          // Find xray binary (xray on Linux/macOS, xray.exe on Windows)
          if (fileName == 'xray' || fileName == 'xray.exe') {
            xrayPath = filePath;
          }
        }
      }
      
      if (xrayPath == null) {
        print('XRAY DOWNLOADER: xray binary not found in archive');
        return null;
      }
      
      // Make executable on Unix systems
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', xrayPath]);
      }
      
      print('XRAY DOWNLOADER: Extracted xray to: $xrayPath');
      return xrayPath;
      
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
