import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_vpni/screens/settings_screen.dart';
import 'package:flutter_vpni/screens/account_sccreen.dart';
import 'package:flutter_vpni/screens/change_language.dart';
import 'package:flutter_vpni/screens/server_location.dart';
import 'package:flutter_vpni/screens/aboutsub_sccreen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
    await chacngeserveri(counter);
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

  Future<void> checkspeed() async {
    // Simulated speed test
    setState(() {
      downloadSpeed = 45.2;
      uploadSpeed = 32.8;
    });
  }

  Future<void> chacngeserveri(int serverId) async {
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

    // Fallback to local JSON
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

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  void _toggleConnection() {
    if (_isConnected) {
      stopTimer();
    } else {
      startTimer();
    }
    setState(() => _isConnected = !_isConnected);
  }

  bool _isDesktop(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > 900;
  }

  bool _isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > 600 && width <= 900;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isTablet = size.width > 600 && size.width <= 900;

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
          child: Column(
            children: [
              Expanded(
                child: isDesktop
                    ? _buildDesktopLayout()
                    : (isTablet ? _buildTabletLayout() : _buildMobileLayout()),
              ),
              if (!isDesktop) _buildBottomNavBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0),
              _buildNavItem(Icons.workspace_premium_rounded, 'Premium', 1),
              _buildNavItem(Icons.settings_rounded, 'Settings', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0038FF).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF0038FF) : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0038FF) : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontFamily: 'Gilroy',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MOBILE LAYOUT ====================
  Widget _buildMobileLayout() {
    // Show different content based on selected tab
    switch (_currentIndex) {
      case 1:
        return _buildPremiumContent();
      case 2:
        return _buildSettingsContent();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        // Header
        _buildHeader(),
        
        // Connection Button Section - fixed height
        SizedBox(
          height: 240,
          child: _buildConnectionSection(),
        ),
        
        // Stats Section - expands to fill remaining space
        Expanded(
          child: _buildMobileStatsSection(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Image.asset('assets/images/logo.png', width: 26),
              const SizedBox(width: 10),
              const Text(
                'VoyFy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Gilroy',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Main Connection Button
        GestureDetector(
          onTap: _toggleConnection,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isConnected ? Icons.power_settings_new : Icons.power_settings_new,
                      size: 40,
                      color: _isConnected ? Colors.green : kBgColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isConnected ? 'disconnect'.tr() : 'connect'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isConnected ? Colors.green : kBgColor,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // Connection Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _isConnected ? 'connected'.tr() : 'disconnected'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Gilroy',
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Timer
        if (_isConnected)
          Text(
            _formatDuration(_duration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w300,
              fontFamily: 'Gilroy',
              letterSpacing: 2,
            ),
          ),
      ],
    );
  }

  Widget _buildMobileStatsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Server Info Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _buildServerCard(),
          ),
          
          // Stats Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildStatCard(
                  icon: Icons.equalizer,
                  iconColor: Colors.orange,
                  value: _pingResult,
                  unit: 'ms',
                  label: 'ping'.tr(),
                )),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard(
                  icon: Icons.arrow_downward,
                  iconColor: const Color(0xff20C4F8),
                  value: downloadSpeed.toStringAsFixed(1),
                  unit: 'MB/s',
                  label: 'download'.tr(),
                  onTap: checkspeed,
                )),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard(
                  icon: Icons.arrow_upward,
                  iconColor: const Color(0xff8220F9),
                  value: uploadSpeed.toStringAsFixed(1),
                  unit: 'MB/s',
                  label: 'upload'.tr(),
                  onTap: checkspeed,
                )),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Change Location Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildLocationButton(),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ==================== DESKTOP LAYOUT ====================
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Sidebar - Navigation
        Container(
          width: 250,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              // Logo
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Image.asset('assets/images/logo.png', width: 40, height: 40),
                    const SizedBox(width: 12),
                    const Text(
                      'VoyFy',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Gilroy',
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              // Navigation Items
              _buildDesktopNavItem(Icons.home_rounded, 'Home', 0),
              _buildDesktopNavItem(Icons.workspace_premium_rounded, 'Premium', 1),
              _buildDesktopNavItem(Icons.settings_rounded, 'Settings', 2),
              const Spacer(),
              // Version
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Main Content Area
        Expanded(
          child: _buildDesktopContent(),
        ),
      ],
    );
  }

  Widget _buildDesktopNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return ListTile(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF0038FF) : Colors.white70,
        size: 24,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontFamily: 'Gilroy',
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
  }

  Widget _buildDesktopContent() {
    switch (_currentIndex) {
      case 1:
        return _buildDesktopPremiumContent();
      case 2:
        return _buildDesktopSettingsContent();
      default:
        return _buildDesktopHomeContent();
    }
  }

  Widget _buildDesktopHomeContent() {
    return Row(
      children: [
        // Left Panel - Connection
        Expanded(
          flex: 1,
          child: Column(
            children: [
              const SizedBox(height: 24),
              Expanded(
                child: _buildDesktopConnectionSection(),
              ),
            ],
          ),
        ),
        // Right Panel - Stats
        Expanded(
          flex: 1,
          child: Container(
            margin: const EdgeInsets.only(left: 1),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(30)),
            ),
            child: _buildDesktopStatsSection(),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopPremiumContent() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Plans',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Gilroy',
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the best plan for you',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Gilroy',
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPlanCard(
                      title: 'Monthly',
                      price: '\$9.99',
                      period: '/month',
                      features: ['All servers', 'Unlimited bandwidth', 'Priority support'],
                      isPopular: false,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPlanCard(
                      title: 'Yearly',
                      price: '\$59.99',
                      period: '/year',
                      features: ['All servers', 'Unlimited bandwidth', 'Priority support', 'Save 50%'],
                      isPopular: true,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPlanCard(
                      title: 'Lifetime',
                      price: '\$149.99',
                      period: 'one-time',
                      features: ['All servers forever', 'Unlimited bandwidth', 'Lifetime updates', 'Best value'],
                      isPopular: false,
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSettingsContent() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildSettingsSection(
                        title: 'Preferences',
                        items: [
                          _buildSettingsTile(
                            icon: Icons.dark_mode_outlined,
                            title: 'Dark Mode',
                            trailing: Switch(
                              value: false,
                              onChanged: (v) {},
                              activeColor: const Color(0xFF0038FF),
                            ),
                          ),
                          _buildSettingsTile(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            trailing: Switch(
                              value: true,
                              onChanged: (v) {},
                              activeColor: const Color(0xFF0038FF),
                            ),
                          ),
                          _buildSettingsTile(
                            icon: Icons.language_outlined,
                            title: 'Language',
                            subtitle: 'English',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _buildSettingsSection(
                        title: 'Account',
                        items: [
                          _buildSettingsTile(
                            icon: Icons.person_outline,
                            title: 'Profile',
                            onTap: () {},
                          ),
                          _buildSettingsTile(
                            icon: Icons.logout,
                            title: 'Log Out',
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsSection(
                        title: 'About',
                        items: [
                          _buildSettingsTile(
                            icon: Icons.info_outline,
                            title: 'Version',
                            subtitle: '1.0.0',
                          ),
                          _buildSettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopConnectionSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large Connection Button
          GestureDetector(
            onTap: _toggleConnection,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 3,
                ),
              ),
              child: Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.power_settings_new,
                        size: 50,
                        color: _isConnected ? Colors.green : kBgColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isConnected ? 'disconnect'.tr() : 'connect'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _isConnected ? Colors.green : kBgColor,
                          fontFamily: 'Gilroy',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isConnected ? 'connected'.tr() : 'disconnected'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Gilroy',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Timer
          if (_isConnected)
            Text(
              _formatDuration(_duration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w300,
                fontFamily: 'Gilroy',
                letterSpacing: 3,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopStatsSection() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'connection_stats'.tr(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'Gilroy',
            ),
          ),
          const SizedBox(height: 24),
          
          // Server Card
          _buildServerCard(),
          const SizedBox(height: 24),
          
          // Stats Grid (2x2)
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildDesktopStatCard(
                  icon: Icons.equalizer,
                  iconColor: Colors.orange,
                  value: _pingResult,
                  unit: 'ms',
                  label: 'ping'.tr(),
                ),
                _buildDesktopStatCard(
                  icon: Icons.arrow_downward,
                  iconColor: const Color(0xff20C4F8),
                  value: downloadSpeed.toStringAsFixed(1),
                  unit: 'MB/s',
                  label: 'download'.tr(),
                  onTap: checkspeed,
                ),
                _buildDesktopStatCard(
                  icon: Icons.arrow_upward,
                  iconColor: const Color(0xff8220F9),
                  value: uploadSpeed.toStringAsFixed(1),
                  unit: 'MB/s',
                  label: 'upload'.tr(),
                  onTap: checkspeed,
                ),
                _buildDesktopStatCard(
                  icon: Icons.timer,
                  iconColor: Colors.green,
                  value: _isConnected ? _formatDuration(_duration) : '--:--:--',
                  unit: '',
                  label: 'duration'.tr(),
                ),
              ],
            ),
          ),
          
          // Change Location Button
          _buildLocationButton(),
        ],
      ),
    );
  }

  // ==================== SHARED COMPONENTS ====================
  Widget _buildServerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: am,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameserver,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Gilroy',
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isfree ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isfree ? 'free'.tr() : 'premium'.tr(),
                    style: TextStyle(
                      color: isfree ? Colors.orange : Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Gilroy',
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServerLocation()),
        );
        if (result != null) {
          setState(() => chacngeserveri(result));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: kBgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'changeloc'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Gilroy',
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ==================== TABLET LAYOUT ====================
  Widget _buildTabletLayout() {
    return Row(
      children: [
        // Left Panel - Connection (50%)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: _buildDesktopConnectionSection(),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right Panel - Info (50%)
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 24, top: 24, bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildServerCard(),
                          const SizedBox(height: 20),
                          _buildLocationButton(),
                          const SizedBox(height: 20),
                          _buildTabletStatsGrid(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(
              icon: Icons.equalizer,
              iconColor: Colors.orange,
              value: _pingResult,
              unit: 'ms',
              label: 'ping'.tr(),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              icon: Icons.arrow_downward,
              iconColor: const Color(0xff20C4F8),
              value: downloadSpeed.toStringAsFixed(1),
              unit: 'MB/s',
              label: 'download'.tr(),
              onTap: checkspeed,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(
              icon: Icons.arrow_upward,
              iconColor: const Color(0xff8220F9),
              value: uploadSpeed.toStringAsFixed(1),
              unit: 'MB/s',
              label: 'upload'.tr(),
              onTap: checkspeed,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              icon: Icons.timer,
              iconColor: Colors.green,
              value: _isConnected ? _formatDuration(_duration) : '--:--',
              unit: '',
              label: 'duration'.tr(),
            )),
          ],
        ),
      ],
    );
  }

  // ==================== PREMIUM CONTENT ====================
  Widget _buildPremiumContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          // Premium Title
          Text(
            'Premium Plans',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Gilroy',
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the best plan for you',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Gilroy',
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 32),
          // Monthly Plan
          _buildPlanCard(
            title: 'Monthly',
            price: '\$9.99',
            period: '/month',
            features: ['All servers', 'Unlimited bandwidth', 'Priority support'],
            isPopular: false,
          ),
          const SizedBox(height: 16),
          // Yearly Plan
          _buildPlanCard(
            title: 'Yearly',
            price: '\$59.99',
            period: '/year',
            features: ['All servers', 'Unlimited bandwidth', 'Priority support', 'Save 50%'],
            isPopular: true,
          ),
          const SizedBox(height: 16),
          // Lifetime Plan
          _buildPlanCard(
            title: 'Lifetime',
            price: '\$149.99',
            period: 'one-time',
            features: ['All servers forever', 'Unlimited bandwidth', 'Lifetime updates', 'Best value'],
            isPopular: false,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required bool isPopular,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isPopular
            ? Border.all(color: const Color(0xFF0038FF), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0038FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'POPULAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Gilroy',
                ),
              ),
            ),
          if (isPopular) const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Gilroy',
                    color: Color(0xFF0038FF),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Gilroy',
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    period,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Gilroy',
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: const Color(0xFF0038FF), size: 20),
                const SizedBox(width: 8),
                Text(
                  feature,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Gilroy',
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          )).toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0038FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Subscribe',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Gilroy',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SETTINGS CONTENT ====================
  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Text(
            'Settings',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Gilroy',
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          _buildSettingsSection(
            title: 'Preferences',
            items: [
              _buildSettingsTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                trailing: Switch(
                  value: false,
                  onChanged: (v) {},
                  activeColor: const Color(0xFF0038FF),
                ),
              ),
              _buildSettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                trailing: Switch(
                  value: true,
                  onChanged: (v) {},
                  activeColor: const Color(0xFF0038FF),
                ),
              ),
              _buildSettingsTile(
                icon: Icons.language_outlined,
                title: 'Language',
                subtitle: 'English',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsSection(
            title: 'Account',
            items: [
              _buildSettingsTile(
                icon: Icons.person_outline,
                title: 'Profile',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.logout,
                title: 'Log Out',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsSection(
            title: 'About',
            items: [
              _buildSettingsTile(
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: '1.0.0',
              ),
              _buildSettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({required String title, required List<Widget> items}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Gilroy',
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0038FF), size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontFamily: 'Gilroy',
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Gilroy',
                color: Colors.grey.shade500,
              ),
            )
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey) : null),
      onTap: onTap,
    );
  }
}
