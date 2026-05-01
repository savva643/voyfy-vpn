import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kGradientStart = Color(0xFF0038FF);
const kGradientEnd = Color(0xFF8220F9);

class AboutsubScreen extends StatefulWidget {
  const AboutsubScreen({Key? key}) : super(key: key);

  @override
  State<AboutsubScreen> createState() => _AboutsubScreenState();
}

class _AboutsubScreenState extends State<AboutsubScreen> {
  String subscriptionType = 'Free';
  String subscriptionStatus = 'Active';
  String email = 'user@example.com';
  bool isLoading = true;

  bool get isDesktop => MediaQuery.of(context).size.width > 900;
  bool get isWideView => MediaQuery.of(context).size.width > 600;

  final List<Map<String, dynamic>> _plans = [
    {
      'name': 'Free',
      'price': '\$0',
      'period': '/month',
      'features': ['3 servers', '1GB bandwidth/day', 'Standard speed'],
      'isPopular': false,
      'color': const Color(0xff28C0C1),
    },
    {
      'name': 'Premium',
      'price': '\$9.99',
      'period': '/month',
      'features': ['All servers', 'Unlimited bandwidth', 'Max speed', 'Priority support'],
      'isPopular': true,
      'color': Colors.orange,
    },
    {
      'name': 'Yearly',
      'price': '\$59.99',
      'period': '/year',
      'features': ['All servers', 'Unlimited bandwidth', 'Max speed', 'Save 50%'],
      'isPopular': false,
      'color': const Color(0xFF8220F9),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      email = prefs.getString('email') ?? 'user@example.com';
      subscriptionType = prefs.getString('subscription_type') ?? 'Free';
      isLoading = false;
    });
  }

  String _getLocalizedFeature(String feature) {
    final keyMap = {
      '3 servers': '3_servers',
      '1GB bandwidth/day': '1gb_bandwidth_day',
      'Standard speed': 'standard_speed',
      'All servers': 'all_servers',
      'Unlimited bandwidth': 'unlimited_bandwidth',
      'Max speed': 'max_speed',
      'Priority support': 'priority_support',
      'Save 50%': 'save_50',
    };
    final key = keyMap[feature] ?? feature.toLowerCase().replaceAll(' ', '_');
    return key.tr();
  }

  @override
  Widget build(BuildContext context) {
    if (isWideView) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kGradientStart, kGradientEnd],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildMobileHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCurrentPlanCard(),
                        const SizedBox(height: 32),
                        _buildPlanFeaturesList(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanFeaturesList() {
    final isPremium = subscriptionType.toLowerCase() != 'free';
    final isDesktop = MediaQuery.of(context).size.width > 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = _plans.firstWhere((p) => 
      isPremium ? p['name'] == 'Premium' : p['name'] == 'Free',
      orElse: () => _plans.first,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'your_plan_features'.tr(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Gilroy',
            color: isDesktop ? Colors.white : (isDark ? Colors.white : Colors.grey.shade800),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDesktop 
                ? Colors.white.withOpacity(0.15) 
                : (isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDesktop 
                  ? Colors.white.withOpacity(0.2) 
                  : (isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade200),
            ),
          ),
          child: Column(
            children: [
              ...plan['features'].map<Widget>((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: isPremium ? Colors.orange : const Color(0xff28C0C1),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getLocalizedFeature(feature),
                        style: TextStyle(
                          fontSize: 15,
                          color: isDesktop ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
                          fontFamily: 'Gilroy',
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kGradientStart, kGradientEnd],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildDesktopTopHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCurrentPlanCard(),
                          const SizedBox(height: 32),
                          _buildPlanFeaturesList(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
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
          ),
          Text(
            'subscription'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 28,
              fontFamily: 'Gilroy',
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPlanFeaturesCard() {
    final isPremium = subscriptionType.toLowerCase() != 'free';
    final plan = _plans.firstWhere((p) => 
      isPremium ? p['name'] == 'Premium' : p['name'] == 'Free',
      orElse: () => _plans.first,
    );
    
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isPremium ? Colors.orange : const Color(0xff28C0C1)).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPremium ? Icons.workspace_premium : Icons.electric_bolt,
                  color: isPremium ? Colors.orange : const Color(0xff28C0C1),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'your_plan_features'.tr(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Gilroy',
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...plan['features'].map<Widget>((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: isPremium ? Colors.orange : const Color(0xff28C0C1),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _getLocalizedFeature(feature),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontFamily: 'Gilroy',
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
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
          ),
          Text(
            'subscription'.tr(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Gilroy',
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard() {
    final isPremium = subscriptionType.toLowerCase() != 'free';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPremium
              ? (isDark ? [Colors.orange.shade800, Colors.deepOrange.shade900] : [Colors.orange, Colors.deepOrange])
              : (isDark ? [const Color(0xff1A5F5F), const Color(0xff0D7377)] : [const Color(0xff28C0C1), const Color(0xff20B2AA)]),
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? Colors.orange : const Color(0xff28C0C1)).withOpacity(isDark ? 0.5 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPremium ? Icons.workspace_premium : Icons.electric_bolt,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'current_plan'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontFamily: 'Gilroy',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPremium ? 'voyfy_premium'.tr() : 'voyfy_free'.tr(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Gilroy',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              subscriptionStatus,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                fontFamily: 'Gilroy',
              ),
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff28C0C1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'upgrade_now'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Gilroy',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopCurrentPlanCard() {
    final isPremium = subscriptionType.toLowerCase() != 'free';
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium ? Icons.workspace_premium : Icons.electric_bolt,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${'current_plan_label'.tr()}: ${isPremium ? 'premium'.tr() : 'free'.tr()}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontFamily: 'Gilroy',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Gilroy',
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPremium ? Colors.orange : const Color(0xff28C0C1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    subscriptionStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFamily: 'Gilroy',
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

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: plan['isPopular']
            ? Border.all(color: plan['color'], width: 2)
            : null,
      ),
      child: Column(
        children: [
          if (plan['isPopular'])
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: plan['color'],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Text(
                'most_popular'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  fontFamily: 'Gilroy',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan['name'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Gilroy',
                        color: plan['color'],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          plan['price'],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Gilroy',
                          ),
                        ),
                        Text(
                          plan['period'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            fontFamily: 'Gilroy',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...plan['features'].map<Widget>((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: plan['color'],
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        feature,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontFamily: 'Gilroy',
                        ),
                      ),
                    ],
                  ),
                )).toList(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan['color'],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      plan['name'] == 'Free' ? 'current_plan_button'.tr() : 'subscribe'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Gilroy',
                      ),
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

  Widget _buildDesktopPlanCard(Map<String, dynamic> plan) {
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
        border: plan['isPopular']
            ? Border.all(color: plan['color'], width: 2)
            : null,
      ),
      child: Column(
        children: [
          if (plan['isPopular'])
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: plan['color'],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Text(
                'most_popular'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  fontFamily: 'Gilroy',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: plan['color'].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    plan['name'] == 'Free' ? Icons.electric_bolt : Icons.workspace_premium,
                    color: plan['color'],
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  plan['name'],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Gilroy',
                    color: plan['color'],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      plan['price'],
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                    Text(
                      plan['period'],
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ...plan['features'].map<Widget>((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: plan['color'],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            fontFamily: 'Gilroy',
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan['color'],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      plan['name'] == 'Free' ? 'current_plan_button'.tr() : 'subscribe'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Gilroy',
                      ),
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
}