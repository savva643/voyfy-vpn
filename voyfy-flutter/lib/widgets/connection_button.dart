import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

const kBgColor = Color(0xFF0038FF);

class ConnectionButton extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final bool isDisconnecting;
  final Duration duration;
  final String Function(Duration) formatDuration;
  final VoidCallback onTap;
  final bool isDesktop;

  const ConnectionButton({
    Key? key,
    required this.isConnected,
    this.isConnecting = false,
    this.isDisconnecting = false,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine button state
    final bool isBusy = isConnecting || isDisconnecting;
    final Color buttonColor = isConnected ? Colors.green : (isBusy ? Colors.orange : kBgColor);
    final String buttonText = isConnected 
        ? 'disconnect'.tr() 
        : (isConnecting 
            ? 'connecting'.tr() 
            : (isDisconnecting ? 'disconnecting'.tr() : 'connect'.tr()));
    final String statusText = isConnected 
        ? 'connected'.tr() 
        : (isConnecting 
            ? 'connecting'.tr() 
            : (isDisconnecting ? 'disconnecting'.tr() : 'disconnected'.tr()));
    final Color statusColor = isConnected ? Colors.green : (isBusy ? Colors.orange : Colors.red);

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
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.15),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.3),
                width: isDesktop ? 3 : 2,
              ),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                    isBusy
                        ? SizedBox(
                            width: iconSize,
                            height: iconSize,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                            ),
                          )
                        : Icon(
                            Icons.power_settings_new,
                            size: iconSize,
                            color: buttonColor,
                          ),
                    const SizedBox(height: 8),
                    Text(
                      buttonText,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: buttonColor,
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
            color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.2),
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
                  color: isBusy ? Colors.orange : statusColor,
                ),
                child: isBusy
                    ? Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                statusText,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Gilroy',
                ),
              ),
            ],
          ),
        ),
        if (isConnected && !isBusy) ...[
          const SizedBox(height: 12),
          Text(
            formatDuration(duration),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.white,
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