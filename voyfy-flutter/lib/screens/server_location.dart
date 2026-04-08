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
          child: isWideView 
            ? _buildTabletLayout() 
            : _buildMobileLayout(),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildMobileHeader(),
        const SizedBox(height: 16),
        _buildMobileSearchBar(),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - Sidebar with title and search
        Container(
          width: 350,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0038FF),
                const Color(0xFF8220F9),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Server Location',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Gilroy',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextFormField(
                      controller: _searchServerController,
                      onChanged: _loadSearchedServers,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                        hintText: 'Search servers...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        suffixIcon: _searchServerController.text.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white70), 
                              onPressed: _clearSearch,
                            ) 
                          : null,
                      ),
                    ),
                  ),
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
                  _buildDesktopRecommendedCard(
                    icon: Icons.star,
                    iconColor: Colors.orange,
                    title: 'Fastest Server',
                    subtitle: 'Premium',
                    subtitleColor: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildDesktopRecommendedCard(
                    icon: Icons.electric_bolt_outlined,
                    iconColor: const Color(0xff28C0C1),
                    title: 'Free Server',
                    subtitle: 'Free',
                    subtitleColor: const Color(0xff28C0C1),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right side - Server list
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'All Servers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Gilroy',
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _searchedServerData.length,
                  itemBuilder: (context, index) => _buildDesktopServerCard(_searchedServerData[index]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopRecommendedCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Container(
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
    );
  }

  Widget _buildDesktopServerCard(dynamic server) {
    final isSelected = _selectedServerId == server['serverId'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isSelected 
          ? Border.all(color: const Color(0xFF0038FF), width: 2)
          : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('idserv', server['serverId']);
          Navigator.pop(context, server['serverId']);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    server['src'],
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          (server['name'].toString()).tr().toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            fontFamily: 'Gilroy',
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
                    const SizedBox(height: 4),
                    Text(
                      '${server['locations']} locations',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0038FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Color(0xFF0038FF), size: 16),
                )
              else
                Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Text(
              'Server Location',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                fontFamily: 'Gilroy',
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMobileSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Center(
          child: TextFormField(
            controller: _searchServerController,
            onChanged: _loadSearchedServers,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Gilroy',
              fontSize: 16,
              height: 1.2,
            ),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              icon: Icon(Icons.search, color: Colors.white.withOpacity(0.8), size: 22),
              hintText: 'Search servers...',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontFamily: 'Gilroy',
                fontSize: 16,
                height: 1.2,
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
        ),
      ),
    );
  }

  Widget _buildRecommendedServers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'Gilroy',
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        _buildRecommendedCard(
          icon: Icons.star,
          iconColor: Colors.orange,
          iconBgColor: Colors.orange.withOpacity(0.1),
          title: 'Fastest Server',
          badgeText: 'Premium',
          badgeColor: Colors.blueAccent,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 10),
        _buildRecommendedCard(
          icon: Icons.electric_bolt_outlined,
          iconColor: const Color(0xff28C0C1),
          iconBgColor: const Color(0xff28C0C1).withOpacity(0.1),
          title: 'Free Server',
          badgeText: 'Free',
          badgeColor: Colors.orange,
          onTap: () => Navigator.pop(context),
        ),
      ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    fontFamily: 'Gilroy',
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
    );
  }

  Widget _buildMobileRecommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'Gilroy',
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        _buildRecommendedCard(
          icon: Icons.star,
          iconColor: Colors.orange,
          iconBgColor: Colors.orange.withOpacity(0.1),
          title: 'Fastest Server',
          badgeText: 'Premium',
          badgeColor: Colors.blueAccent,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 10),
        _buildRecommendedCard(
          icon: Icons.electric_bolt_outlined,
          iconColor: const Color(0xff28C0C1),
          iconBgColor: const Color(0xff28C0C1).withOpacity(0.1),
          title: 'Free Server',
          badgeText: 'Free',
          badgeColor: Colors.orange,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildMobileAllServersHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'All Servers',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'Gilroy',
            color: Colors.grey.shade800,
          ),
        ),
        Text(
          '${_searchedServerData.length} available',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
            fontFamily: 'Gilroy',
          ),
        ),
      ],
    );
  }

  Widget _buildMobileServerList() {
    return Column(
      children: _searchedServerData.map((server) {
        final isSelected = _selectedServerId == server['serverId'];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: isSelected 
              ? Border.all(color: const Color(0xFF0038FF), width: 2)
              : null,
          ),
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
                      child: Image.asset(
                        server['src'],
                        fit: BoxFit.cover,
                      ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  fontFamily: 'Gilroy',
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
                            color: Colors.grey.shade500,
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
        );
      }).toList(),
    );
  }

  // ==================== TABLET LAYOUT ====================
  Widget _buildTabletLayout() {
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
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Server Location',
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: TextFormField(
                      controller: _searchServerController,
                      onChanged: _loadSearchedServers,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy',
                        fontSize: 16,
                        height: 1.2,
                      ),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        icon: Icon(Icons.search, color: Colors.white.withOpacity(0.8), size: 22),
                        hintText: 'Search servers...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontFamily: 'Gilroy',
                          fontSize: 16,
                          height: 1.2,
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
                  ),
                ),
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
                  title: 'Fastest Server',
                  subtitle: 'Premium',
                  subtitleColor: Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildTabletRecommendedCard(
                  icon: Icons.electric_bolt_outlined,
                  iconColor: const Color(0xff28C0C1),
                  title: 'Free Server',
                  subtitle: 'Free',
                  subtitleColor: const Color(0xff28C0C1),
                ),
              ],
            ),
          ),
        ),
        // Right Panel - Server List
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
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'All Servers (${_searchedServerData.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Gilroy',
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
  }) {
    return Container(
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
    );
  }

  Widget _buildTabletServerCard(dynamic server) {
    final isSelected = _selectedServerId == server['serverId'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: isSelected 
          ? Border.all(color: const Color(0xFF0038FF), width: 2)
          : null,
      ),
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
                  child: Image.asset(
                    server['src'],
                    fit: BoxFit.cover,
                  ),
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
                          (server['name'].toString()).tr().toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            fontFamily: 'Gilroy',
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
                      '${server['locations']} locations',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
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
    );
  }

  // Legacy methods for backwards compatibility
  Widget _buildAllServersHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'All Servers',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'Gilroy',
            color: Colors.grey.shade800,
          ),
        ),
        Text(
          '${_searchedServerData.length} available',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
            fontFamily: 'Gilroy',
          ),
        ),
      ],
    );
  }

  Widget _buildServerList() {
    return Column(
      children: _searchedServerData.map((server) {
        final isSelected = _selectedServerId == server['serverId'];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isSelected 
              ? Border.all(color: const Color(0xFF0038FF), width: 2)
              : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('idserv', server['serverId']);
              Navigator.pop(context, server['serverId']);
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        server['src'],
                        fit: BoxFit.cover,
                      ),
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
                              (server['name'].toString()).tr().toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                fontFamily: 'Gilroy',
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (server['isFree'])
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xff28C0C1).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'FREE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff28C0C1),
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PREMIUM',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${server['locations']} locations',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontFamily: 'Gilroy',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0038FF).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Color(0xFF0038FF), size: 18),
                    )
                  else
                    Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
