import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';

import '../providers/theme_provider.dart';
import '../providers/vpn_provider.dart';
import '../services/vpn_service.dart';
import '../models/vpn_server.dart';
import 'home/home_content.dart';
import 'home/premium_content.dart';
import 'home/settings_content.dart';
import '../widgets/navigation_widgets.dart';
import 'login_screen.dart';
import 'server_location.dart';
import 'change_language.dart';
import 'account_sccreen.dart';
import 'aboutsub_sccreen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

const kBgColor = Color(0xFF0038FF);
const kBgColorLight = Color(0xFF4B6FFF);
const kGradientStart = Color(0xFF0038FF);
const kGradientEnd = Color(0xFF8220F9);

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String flagUrl = 'https://flagcdn.com/w80/us.png';
  String nameserver = "usa".tr().toString();
  int idserv = 1;
  bool isfree = false;
  Timer? _pingTimer;
  String _pingResult = '0';
  double downloadSpeed = 0;
  double uploadSpeed = 0;
  int _bytesReceived = 0;
  int _bytesSent = 0;
  int _currentIndex = 0;

  String? _userUuid;
  String? _subscriptionUrl;
  Map<String, dynamic>? _selectedServer;

  @override
  void initState() {
    super.initState();
    _loadServer();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userUuid = prefs.getString('user_uuid');
    if (_userUuid != null) {
      _subscriptionUrl = ApiConfig.subscriptionByUuid(_userUuid!);
    }
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadServer() async {
    final prefs = await SharedPreferences.getInstance();
    final counter = prefs.getInt('idserv') ?? 1;
    await changeServer(counter);
  }

  Future<void> _pingHost(String host) async {
    try {
      final result = await Process.run('ping', ['-n', '1', host]);
      final rtt = _parsePingOutput(result.stdout.toString());
      setState(() {
        _pingResult = rtt;
      });
    } catch (e) {
      setState(() => _pingResult = '0');
    }
  }

  String _parsePingOutput(String output) {
    final pattern = RegExp(r'time[=:](\d+)[msмс]');
    final match = pattern.firstMatch(output);
    return match?.group(1) ?? '0';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }
  
  Future<void> checkSpeed() async {
    // Speed test not implemented - now shows data usage instead
    setState(() {
      // Just refresh the UI
    });
  }

  Future<void> changeServer(int serverId) async {
    final vpnProvider = context.read<VpnProvider>();
    
    try {
      final uri = Uri.parse(ApiConfig.servers);
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body.toString());
        final list = decoded['success'] != null && decoded['data'] != null
            ? decoded['data']['servers'] as List<dynamic>?
            : decoded['servers'] as List<dynamic>? ?? [];
        final server = list?.firstWhere(
              (s) => s['serverId'] == serverId,
          orElse: () => null,
        );
        if (server != null) {
          setState(() {
            idserv = serverId;
            final countryCode = server["countryCode"]?.toString().toLowerCase() ?? 'us';
            flagUrl = 'https://flagcdn.com/w80/$countryCode.png';
            nameserver = server["name"].toString();
            isfree = server["isFree"] == true;
          });
          
          // Also update VpnProvider with selected server
          final vpnServer = VpnServer.fromJson(server);
          vpnProvider.selectServer(vpnServer);
          
          // Save to prefs
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('idserv', serverId);
          return;
        }
      }
    } catch (e) {
      print('changeServer API error: $e');
    }

    // Fallback to local server.json
    try {
      final String response = await rootBundle.loadString('server/server.json');
      final tagsJson = jsonDecode(response)[serverId - 1];
      setState(() {
        idserv = serverId;
        final countryCode = tagsJson["countryCode"]?.toString().toLowerCase() ?? 'us';
        flagUrl = 'https://flagcdn.com/w80/$countryCode.png';
        nameserver = tagsJson["name"].toString().tr();
        isfree = tagsJson["isFree"];
      });
      
      // Also update VpnProvider with selected server from local
      final vpnServer = VpnServer.fromJson(tagsJson);
      vpnProvider.selectServer(vpnServer);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('idserv', serverId);
    } catch (e) {
      print('changeServer local error: $e');
    }
  }

  String formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  Future<void> toggleConnection() async {
    // Use VpnProvider which has proper server selection logic
    final vpnProvider = context.read<VpnProvider>();
    
    if (!vpnProvider.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VPN not initialized. Please login first.')),
      );
      return;
    }
    
    final result = await vpnProvider.toggleConnection();
    
    if (!result && mounted) {
      final error = vpnProvider.lastError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.message ?? 'Failed to connect to VPN')),
      );
    }
  }

  void navigateToScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(fontFamily: 'Gilroy'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Gilroy')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('access_token');
              await prefs.remove('refresh_token');
              await prefs.remove('email');
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String get currentLanguage {
    final locale = context.locale;
    return locale.languageCode == 'ru' ? 'Русский' : 'English';
  }

  // Метод для открытия выбора сервера
  Future<void> _openServerSelection() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServerLocation()),
    );
    if (result != null) {
      await changeServer(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;
    final isTablet = false;
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kGradientStart, kGradientEnd],
                ),
        ),
        child: SafeArea(
          child: isDesktop
              ? Row(
            children: [
              NavigationRailWidget(
                currentIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
              ),
              Expanded(
                child: _buildCurrentContent(isDesktop: true),
              ),
            ],
          )
              : Column(
            children: [
              Expanded(
                child: _buildCurrentContent(isDesktop: false),
              ),
              if (!isDesktop && !isTablet)
                BottomNavBarWidget(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() => _currentIndex = index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentContent({required bool isDesktop}) {
    switch (_currentIndex) {
      case 1:
        return PremiumContent(isDesktop: isDesktop);
      case 2:
        return SettingsContent(
          isDesktop: isDesktop,
          currentLanguage: currentLanguage,
          onLanguageTap: () => navigateToScreen(const ChangeLanguage()),
          onProfileTap: () => navigateToScreen(const AccountScreen()),
          onSubscriptionTap: () => navigateToScreen(const AboutsubScreen()),
          onPrivacyPolicyTap: () => navigateToScreen(const PrivacyPolicyScreen()),
          onTermsOfServiceTap: () => navigateToScreen(const TermsOfServiceScreen()),
          onLogoutTap: showLogoutDialog,
        );
      default:
        // Watch VpnProvider for connection status
        return Consumer<VpnProvider>(
          builder: (context, vpnProvider, child) {
            return HomeContent(
              isDesktop: isDesktop,
              flagUrl: flagUrl,
              nameserver: nameserver,
              isfree: isfree,
              isConnected: vpnProvider.isConnected,
              isConnecting: vpnProvider.isConnecting,
              isDisconnecting: vpnProvider.isDisconnecting,
              duration: vpnProvider.connectionDuration ?? const Duration(),
              pingResult: _pingResult,
              bytesReceived: _bytesReceived,
              bytesSent: _bytesSent,
              formatBytes: _formatBytes,
              formatDuration: formatDuration,
              onToggleConnection: toggleConnection,
              onCheckSpeed: checkSpeed,
              onChangeServer: _openServerSelection,
            );
          },
        );
    }
  }
}