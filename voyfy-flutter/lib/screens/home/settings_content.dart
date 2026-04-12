import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/settings_tile.dart';

class SettingsContent extends StatelessWidget {
  final bool isDesktop;
  final String currentLanguage;
  final VoidCallback onLanguageTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSubscriptionTap;
  final VoidCallback onPrivacyPolicyTap;
  final VoidCallback onTermsOfServiceTap;
  final VoidCallback onLogoutTap;

  const SettingsContent({
    Key? key,
    required this.isDesktop,
    required this.currentLanguage,
    required this.onLanguageTap,
    required this.onProfileTap,
    required this.onSubscriptionTap,
    required this.onPrivacyPolicyTap,
    required this.onTermsOfServiceTap,
    required this.onLogoutTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _buildDesktopLayout(context);
    } else {
      return _buildMobileLayout(context);
    }
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Text(
                    'settings'.tr(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Gilroy',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildPreferencesSection(context),
                  const SizedBox(height: 16),
                  _buildAccountSection(context),
                  const SizedBox(height: 16),
                  _buildAboutSection(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settings'.tr(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Gilroy',
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'manage_preferences'.tr(),
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
                        Expanded(
                          child: Column(
                            children: [
                              _buildPreferencesSection(context),
                              const SizedBox(height: 20),
                              _buildAccountSection(context),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildAboutSection(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    return _buildSettingsSection(
      context: context,
      title: 'preferences'.tr(),
      items: [
        SettingsTile(
          icon: Icons.dark_mode_outlined,
          title: 'dark_mode'.tr(),
          trailing: Builder(
            builder: (context) {
              final themeProvider = context.watch<ThemeProvider>();
              return Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.setDarkMode(value);
                },
                activeColor: const Color(0xFF0038FF),
              );
            },
          ),
        ),
        SettingsTile(
          icon: Icons.notifications_outlined,
          title: 'notifications'.tr(),
          trailing: Switch(
            value: true,
            onChanged: (v) {},
            activeColor: const Color(0xFF0038FF),
          ),
        ),
        SettingsTile(
          icon: Icons.language_outlined,
          title: 'languages'.tr(),
          subtitle: currentLanguage,
          onTap: onLanguageTap,
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return _buildSettingsSection(
      context: context,
      title: 'account'.tr(),
      items: [
        SettingsTile(
          icon: Icons.person_outline,
          title: 'profile'.tr(),
          onTap: onProfileTap,
        ),
        SettingsTile(
          icon: Icons.workspace_premium_outlined,
          title: 'subscription'.tr(),
          onTap: onSubscriptionTap,
        ),
        SettingsTile(
          icon: Icons.logout,
          title: 'logout'.tr(),
          onTap: onLogoutTap,
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return _buildSettingsSection(
      context: context,
      title: 'about'.tr(),
      items: [
        SettingsTile(
          icon: Icons.info_outline,
          title: 'version'.tr(),
          subtitle: '1.0.0',
        ),
        SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'privacy_policy'.tr(),
          onTap: onPrivacyPolicyTap,
        ),
        SettingsTile(
          icon: Icons.description_outlined,
          title: 'terms_of_service'.tr(),
          onTap: onTermsOfServiceTap,
        ),
      ],
    );
  }

  Widget _buildSettingsSection({required BuildContext context, required String title, required List<Widget> items}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                color: isDark ? const Color(0xFFB0B0B0) : Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }
}