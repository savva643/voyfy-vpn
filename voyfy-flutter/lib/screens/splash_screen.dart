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
    final refresh = prefs.getString('refresh_token');

    if (tk != null && tk.isNotEmpty) {
      try {
        final uri =
            Uri.parse('http://localhost:4000/api/auth/validate-session');
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $tk',
            'platform': Platform.isIOS ? 'ios' : 'android',
            'device-type': 'mobile',
            'app-version': '1.0.0',
          },
        );

        if (res.statusCode == 200) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
          return;
        }
      } catch (_) {
        // ignore and try refresh
      }
    }

    if ((tk == null || tk.isEmpty) && refresh != null && refresh.isNotEmpty) {
      try {
        final uri = Uri.parse('http://localhost:4000/api/auth/refresh');
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: '{"refreshToken":"$refresh"}',
        );

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body.toString());
          final newToken = decoded['token'];
          if (newToken != null) {
            await prefs.setString('access_token', newToken);
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
            return;
          }
        }
      } catch (_) {
        // ignore
      }
    }

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
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
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              const Color(0xFFF8F9FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: isDesktop || isTablet
                ? _buildDesktopLayout(size)
                : _buildMobileLayout(size),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(Size size) {
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
                color: const Color(0xFF0038FF).withOpacity(0.15),
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
            const Text(
              'VoyFy',
              style: TextStyle(
                fontSize: 42,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w900,
                color: Color(0xFF0038FF),
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
                color: Colors.grey.shade600,
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
              const Color(0xFF0038FF).withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0038FF).withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Brand Name and Tagline
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VoyFy',
              style: TextStyle(
                fontSize: 48,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w900,
                color: Color(0xFF0038FF),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Secure VPN Connection',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(width: 40),
        // Loading Indicator
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color(0xFF0038FF).withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }
}
