import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vpni/screens/account_sccreen.dart';
import 'package:flutter_vpni/screens/change_language.dart';
import 'package:flutter_vpni/screens/login_screen.dart';
import 'package:flutter_vpni/screens/server_location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import 'home/home_content.dart';
import 'home/premium_content.dart';
import 'home/settings_content.dart';
import '../widgets/navigation_widgets.dart';

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
  AssetImage am = const AssetImage('assets/images/usa.jpeg');
  String nameserver = "usa".tr().toString();
  int idserv = 1;
  bool isfree = false;
  bool _isConnected = false;
  Duration _duration = const Duration();
  Timer? _timer;
  Timer? _pingTimer;
  String _pingResult = '0';
  double downloadSpeed = 0;
  double uploadSpeed = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadServer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadServer() async {
    final prefs = await SharedPreferences.getInstance();
    final counter = prefs.getInt('idserv') ?? 1;
    await changeServer(counter);
  }

  void startTimer() {
    _pingHost('google.com');
    _startPingLoop();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _duration = Duration(seconds: _duration.inSeconds + 1);
      });
    });
  }

  void stopTimer() {
    _pingTimer?.cancel();
    _timer?.cancel();
    setState(() {
      _duration = const Duration();
      _pingResult = '0';
    });
  }

  void _startPingLoop() {
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pingHost('google.com');
    });
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

  Future<void> checkSpeed() async {
    setState(() {
      downloadSpeed = 45.2;
      uploadSpeed = 32.8;
    });
  }

  Future<void> changeServer(int serverId) async {
    try {
      final uri = Uri.parse('http://localhost:4000/api/servers');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body.toString());
        final list = decoded['servers'] as List<dynamic>? ?? [];
        final server = list.firstWhere(
              (s) => s['serverId'] == serverId,
          orElse: () => null,
        );
        if (server != null) {
          setState(() {
            idserv = serverId;
            am = AssetImage(server["src"]);
            nameserver = server["name"].toString().tr();
            isfree = server["isFree"] == true;
          });
          return;
        }
      }
    } catch (_) {}

    try {
      final String response = await rootBundle.loadString('server/server.json');
      final tagsJson = jsonDecode(response)[serverId - 1];
      setState(() {
        idserv = serverId;
        am = AssetImage(tagsJson["src"]);
        nameserver = tagsJson["name"].toString().tr();
        isfree = tagsJson["isFree"];
      });
    } catch (_) {}
  }

  String formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  void toggleConnection() {
    if (_isConnected) {
      stopTimer();
    } else {
      startTimer();
    }
    setState(() => _isConnected = !_isConnected);
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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
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
          onSubscriptionTap: () => navigateToScreen(const AccountScreen()),
          onLogoutTap: showLogoutDialog,
        );
      default:
        return HomeContent(
          isDesktop: isDesktop,
          am: am,
          nameserver: nameserver,
          isfree: isfree,
          isConnected: _isConnected,
          duration: _duration,
          pingResult: _pingResult,
          downloadSpeed: downloadSpeed,
          uploadSpeed: uploadSpeed,
          formatDuration: formatDuration,
          onToggleConnection: toggleConnection,
          onCheckSpeed: checkSpeed,
          onChangeServer: _openServerSelection, // Теперь передаем метод без параметров
        );
    }
  }
}