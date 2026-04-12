import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_vpni/screens/home_screen.dart';
import 'package:flutter_vpni/screens/login_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Future<void> getlatloc() async {
    final prefs = await SharedPreferences.getInstance();

    final tk = prefs.getString('access_token');

    // Simply check if token exists - no backend validation to avoid issues
    if (tk != null && tk.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
      return;
    }

    // No token - go to login
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void initState() {
    Future.delayed(const Duration(seconds: 3), () {
      getlatloc();
    });
    //
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isTablet = size.width > 600 && size.width <= 900;
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0B1220) : Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    const Color(0xFF0B1220),
                    const Color(0xFF1A1A2E),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFF8F9FF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: isDesktop || isTablet
                ? _buildDesktopLayout(size, isDarkMode)
                : _buildMobileLayout(size, isDarkMode),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(Size size, bool isDarkMode) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0038FF).withOpacity(isDarkMode ? 0.4 : 0.15),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Brand Name
        Column(
          children: [
            Text(
              'VoyFy',
              style: TextStyle(
                fontSize: 42,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w900,
                color: isDarkMode ? Colors.white : const Color(0xFF0038FF),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Secure VPN Connection',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 60),
        // Loading Indicator
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              isDarkMode ? Colors.white : const Color(0xFF0038FF),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(Size size, bool isDarkMode) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0038FF).withOpacity(isDarkMode ? 0.5 : 0.2),
                blurRadius: 50,
                spreadRadius: 10,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Brand Name
        Text(
          'VoyFy',
          style: TextStyle(
            fontSize: 56,
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w900,
            color: isDarkMode ? Colors.white : const Color(0xFF0038FF),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Secure VPN Connection',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 48),
        // Loading Indicator
        SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              isDarkMode ? Colors.white : const Color(0xFF0038FF),
            ),
          ),
        ),
      ],
    );
  }
}
