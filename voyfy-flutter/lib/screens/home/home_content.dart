import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../widgets/connection_button.dart';
import '../../widgets/server_card.dart';
import '../../widgets/stat_card.dart';

class HomeContent extends StatelessWidget {
  final bool isDesktop;
  final String flagUrl;
  final String nameserver;
  final bool isfree;
  final bool isConnected;
  final Duration duration;
  final String pingResult;
  final int bytesReceived;
  final int bytesSent;
  final String Function(int) formatBytes;
  final String Function(Duration) formatDuration;
  final VoidCallback onToggleConnection;
  final VoidCallback onCheckSpeed;
  final VoidCallback onChangeServer; // Изменено с Function на VoidCallback

  const HomeContent({
    Key? key,
    required this.isDesktop,
    required this.flagUrl,
    required this.nameserver,
    required this.isfree,
    required this.isConnected,
    required this.duration,
    required this.pingResult,
    required this.bytesReceived,
    required this.bytesSent,
    required this.formatBytes,
    required this.formatDuration,
    required this.onToggleConnection,
    required this.onCheckSpeed,
    required this.onChangeServer, // Теперь это VoidCallback
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        _buildHeader(context),
        SizedBox(
          height: 240,
          child: ConnectionButton(
            isConnected: isConnected,
            duration: duration,
            formatDuration: formatDuration,
            onTap: onToggleConnection,
          ),
        ),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: ServerCard(
                    flagUrl: flagUrl,
                    nameserver: nameserver,
                    isfree: isfree,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.equalizer,
                          iconColor: Colors.orange,
                          value: pingResult,
                          unit: 'ms',
                          label: 'ping'.tr(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          icon: Icons.arrow_downward,
                          iconColor: const Color(0xff20C4F8),
                          value: formatBytes(bytesReceived),
                          unit: '',
                          label: 'received'.tr(),
                          onTap: onCheckSpeed,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          icon: Icons.arrow_upward,
                          iconColor: const Color(0xff8220F9),
                          value: formatBytes(bytesSent),
                          unit: '',
                          label: 'sent'.tr(),
                          onTap: onCheckSpeed,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildLocationButton(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Column(
            children: [
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: ConnectionButton(
                    isConnected: isConnected,
                    duration: duration,
                    formatDuration: formatDuration,
                    onTap: onToggleConnection,
                    isDesktop: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(left: 1),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(30)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'connection_stats'.tr(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Gilroy',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ServerCard(
                    flagUrl: flagUrl,
                    nameserver: nameserver,
                    isfree: isfree,
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        StatCard(
                          icon: Icons.equalizer,
                          iconColor: Colors.orange,
                          value: pingResult,
                          unit: 'ms',
                          label: 'ping'.tr(),
                          isDesktop: true,
                        ),
                        StatCard(
                          icon: Icons.arrow_downward,
                          iconColor: const Color(0xff20C4F8),
                          value: formatBytes(bytesReceived),
                          unit: '',
                          label: 'received'.tr(),
                          onTap: onCheckSpeed,
                          isDesktop: true,
                        ),
                        StatCard(
                          icon: Icons.arrow_upward,
                          iconColor: const Color(0xff8220F9),
                          value: formatBytes(bytesSent),
                          unit: '',
                          label: 'sent'.tr(),
                          onTap: onCheckSpeed,
                          isDesktop: true,
                        ),
                        StatCard(
                          icon: Icons.timer,
                          iconColor: Colors.green,
                          value: isConnected ? formatDuration(duration) : '--:--:--',
                          unit: '',
                          label: 'duration'.tr(),
                          isDesktop: true,
                        ),
                      ],
                    ),
                  ),
                  _buildLocationButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Image.asset('assets/images/logo.png', width: 26),
              const SizedBox(width: 10),
              Text(
                'VoyFy',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.white,
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

  Widget _buildLocationButton() {
    return GestureDetector(
      onTap: onChangeServer, // Теперь просто вызываем VoidCallback
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0038FF),
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
}