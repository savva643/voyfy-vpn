import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

const kBgColor = Color(0xFF0038FF);

class ConnectionButton extends StatelessWidget {
  final bool isConnected;
  final Duration duration;
  final String Function(Duration) formatDuration;
  final VoidCallback onTap;
  final bool isDesktop;

  const ConnectionButton({
    Key? key,
    required this.isConnected,
    required this.duration,
    required this.formatDuration,
    required this.onTap,
    this.isDesktop = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonSize = isDesktop ? 200.0 : 160.0;
    final innerSize = isDesktop ? 150.0 : 120.0;
    final iconSize = isDesktop ? 50.0 : 40.0;
    final fontSize = isDesktop ? 16.0 : 14.0;
    final durationFontSize = isDesktop ? 36.0 : 28.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: isDesktop ? 3 : 2,
              ),
            ),
            child: Center(
              child: Container(
                width: innerSize,
                height: innerSize,
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
                      Icons.power_settings_new,
                      size: iconSize,
                      color: isConnected ? Colors.green : kBgColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isConnected ? 'disconnect'.tr() : 'connect'.tr(),
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: isConnected ? Colors.green : kBgColor,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isConnected ? 'connected'.tr() : 'disconnected'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Gilroy',
                ),
              ),
            ],
          ),
        ),
        if (isConnected) ...[
          const SizedBox(height: 12),
          Text(
            formatDuration(duration),
            style: TextStyle(
              color: Colors.white,
              fontSize: durationFontSize,
              fontWeight: FontWeight.w300,
              fontFamily: 'Gilroy',
              letterSpacing: 2,
            ),
          ),
        ],
      ],
    );
  }
}