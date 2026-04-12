import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const kGradientStart = Color(0xFF0038FF);
const kGradientEnd = Color(0xFF8220F9);

class ServerLocation extends StatefulWidget {
  const ServerLocation({Key? key}) : super(key: key);

  @override
  State<ServerLocation> createState() => _ServerLocationState();
}

class _ServerLocationState extends State<ServerLocation> {
  List _serverData = [];
  List _searchedServerData = [];
  int? _selectedServerId;

  final _searchServerController = TextEditingController();

  bool get isDesktop => MediaQuery.of(context).size.width > 900;
  bool get isTablet => MediaQuery.of(context).size.width > 600 && MediaQuery.of(context).size.width <= 900;

  @override
  void initState() {
    _loadServerData();
    _loadSelectedServer();
    super.initState();
  }

  Future<void> _loadSelectedServer() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedServerId = prefs.getInt('idserv');
    });
  }

  @override
  void dispose() {
    _searchServerController.dispose();
    super.dispose();
  }

  Future<void> _loadServerData() async {
    try {
      final uri = Uri.parse('http://localhost:4000/api/servers');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body.toString());
        final data = decoded['servers'] as List<dynamic>? ?? [];
        setState(() {
          _serverData = data;
          _searchedServerData = data;
        });
        return;
      }
    } catch (_) {
      // ignore and fallback to local json
    }

    final String response = await rootBundle.loadString('server/server.json');
    final data = await json.decode(response);
    setState(() {
      _serverData = data;
      _searchedServerData = data;
    });
  }

  _loadSearchedServers(String? textVal) {
    if(textVal != null && textVal.isNotEmpty) {
      final data = _serverData.where((server) {
        return server['name'].toLowerCase().contains(textVal.toLowerCase());
      }).toList();
      setState(() => _searchedServerData = data);
    } else {
      setState(() => _searchedServerData = _serverData);
    }
  }

  _clearSearch() {
    _searchServerController.clear();
    setState(() => _searchedServerData = _serverData);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWideView = size.width > 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: isDark
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
          child: isWideView 
            ? _buildTabletLayout() 
            : _buildMobileLayout(),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        _buildMobileHeader(),
        const SizedBox(height: 16),
        _buildTabletSearchBar(),
        const SizedBox(height: 16),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildMobileRecommendedSection(),
                    const SizedBox(height: 24),
                    _buildMobileAllServersHeader(),
                    const SizedBox(height: 12),
                    _buildMobileServerList(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'server_location'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Gilroy',
              ),
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _buildTabletSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchServerController,
        onChanged: _loadSearchedServers,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Gilroy',
          fontSize: 16,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.8), size: 22),
          hintText: 'search_servers'.tr(),
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontFamily: 'Gilroy',
            fontSize: 16,
          ),
          suffixIcon: _searchServerController.text.isNotEmpty 
            ? IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.8), size: 20), 
                onPressed: _clearSearch,
              ) 
            : null,
        ),
      ),
    );
  }

  Widget _buildRecommendedCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      fontFamily: 'Gilroy',
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      fontFamily: 'Gilroy',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileRecommendedSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'recommended'.tr(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'Gilroy',
            color: isDark ? Colors.white : Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        _buildRecommendedCard(
          icon: Icons.star,
          iconColor: Colors.orange,
          iconBgColor: Colors.orange.withOpacity(0.1),
          title: 'fastest_server'.tr(),
          badgeText: 'premium'.tr(),
          badgeColor: Colors.blueAccent,
          onTap: () => _selectFastestServer(),
        ),
        const SizedBox(height: 10),
        _buildRecommendedCard(
          icon: Icons.electric_bolt_outlined,
          iconColor: const Color(0xff28C0C1),
          iconBgColor: const Color(0xff28C0C1).withOpacity(0.1),
          title: 'free_server'.tr(),
          badgeText: 'free'.tr(),
          badgeColor: Colors.orange,
          onTap: () => _selectFreeServer(),
        ),
      ],
    );
  }

  Future<void> _selectFastestServer() async {
    // Select server with lowest load (simulating fastest)
    if (_serverData.isEmpty) return;

    final premiumServers = _serverData.where((s) => !s['isFree']).toList();
    if (premiumServers.isEmpty) {
      final server = _serverData.reduce((a, b) => a['load'] < b['load'] ? a : b);
      await _selectServer(server);
    } else {
      final server = premiumServers.reduce((a, b) => a['load'] < b['load'] ? a : b);
      await _selectServer(server);
    }
  }

  Future<void> _selectFreeServer() async {
    // Select random free server
    final freeServers = _serverData.where((s) => s['isFree']).toList();
    if (freeServers.isEmpty) return;

    final random = DateTime.now().millisecond % freeServers.length;
    await _selectServer(freeServers[random]);
  }

  Future<void> _selectServer(dynamic server) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('idserv', server['serverId']);
    Navigator.pop(context, server['serverId']);
  }

  Widget _buildMobileAllServersHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'all_servers'.tr(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'Gilroy',
            color: isDark ? Colors.white : Colors.grey.shade800,
          ),
        ),
        Text(
          '${_searchedServerData.length} available',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFFB0B0B0) : Colors.grey.shade500,
            fontFamily: 'Gilroy',
          ),
        ),
      ],
    );
  }

  Widget _buildMobileServerList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: _searchedServerData.map((server) {
        final isSelected = _selectedServerId == server['serverId'];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: isSelected 
              ? Border.all(color: const Color(0xFF0038FF), width: 2)
              : Border.all(color: isDark ? const Color(0xFF3C3C3C) : Colors.transparent),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('idserv', server['serverId']);
                Navigator.pop(context, server['serverId']);
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: server['countryCode'] != null
                            ? Image.network(
                                'https://flagcdn.com/w80/${server['countryCode'].toLowerCase()}.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset('assets/images/placeholder.png', fit: BoxFit.cover);
                                },
                              )
                            : Image.asset(server['src'], fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  (server['name'].toString()).tr().toString(),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    fontFamily: 'Gilroy',
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: server['isFree'] 
                                    ? const Color(0xff28C0C1).withOpacity(0.1) 
                                    : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  server['isFree'] ? 'FREE' : 'PREMIUM',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: server['isFree'] ? const Color(0xff28C0C1) : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${server['locations']} locations',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFFB0B0B0) : Colors.grey.shade500,
                              fontFamily: 'Gilroy',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0038FF).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Color(0xFF0038FF), size: 16),
                      )
                    else
                      Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 14),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== TABLET LAYOUT ====================
  Widget _buildTabletLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        // Left Panel - Header and Search
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'server_location'.tr(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTabletSearchBar(),
                const SizedBox(height: 24),
                Text(
                  'Recommended',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.8),
                    fontFamily: 'Gilroy',
                  ),
                ),
                const SizedBox(height: 16),
                _buildTabletRecommendedCard(
                  icon: Icons.star,
                  iconColor: Colors.orange,
                  title: 'fastest_server'.tr(),
                  subtitle: 'premium'.tr(),
                  subtitleColor: Colors.orange,
                  onTap: _selectFastestServer,
                ),
                const SizedBox(height: 12),
                _buildTabletRecommendedCard(
                  icon: Icons.electric_bolt_outlined,
                  iconColor: const Color(0xff28C0C1),
                  title: 'free_server'.tr(),
                  subtitle: 'free'.tr(),
                  subtitleColor: const Color(0xff28C0C1),
                  onTap: _selectFreeServer,
                ),
              ],
            ),
          ),
        ),
        // Right Panel - Server List
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 24, top: 24, bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'All Servers (${_searchedServerData.length})',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Gilroy',
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _searchedServerData.length,
                      itemBuilder: (context, index) => _buildTabletServerCard(_searchedServerData[index]),
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

  Widget _buildTabletRecommendedCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Gilroy',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletServerCard(dynamic server) {
    final isSelected = _selectedServerId == server['serverId'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
          ? Border.all(color: const Color(0xFF0038FF), width: 2)
          : Border.all(color: isDark ? const Color(0xFF3C3C3C) : Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('idserv', server['serverId']);
            Navigator.pop(context, server['serverId']);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: server['countryCode'] != null
                        ? Image.network(
                            'https://flagcdn.com/w80/${server['countryCode'].toLowerCase()}.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset('assets/images/placeholder.png', fit: BoxFit.cover);
                            },
                          )
                        : Image.asset(server['src'], fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            server['name'].toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              fontFamily: 'Gilroy',
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: server['isFree'] ? const Color(0xff28C0C1).withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              server['isFree'] ? 'FREE' : 'PREMIUM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: server['isFree'] ? const Color(0xff28C0C1) : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        server['country'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFFB0B0B0) : Colors.grey.shade600,
                          fontFamily: 'Gilroy',
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0038FF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Color(0xFF0038FF), size: 16),
                  )
                else
                  Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}