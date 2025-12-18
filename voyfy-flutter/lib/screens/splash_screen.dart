import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

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

    final tk = prefs.getString('token');
    final refresh = prefs.getString('refreshToken');

    if (tk != null && tk.isNotEmpty) {
      try {
        final uri =
            Uri.parse('http://10.0.2.2:4000/api/auth/validate-session');
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
          return;
        }
      } catch (_) {
        // ignore and try refresh
      }
    }

    if ((tk == null || tk.isEmpty) && refresh != null && refresh.isNotEmpty) {
      try {
        final uri = Uri.parse('http://10.0.2.2:4000/api/auth/refresh');
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
            await prefs.setString('token', newToken);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
            return;
          }
        }
      } catch (_) {
        // ignore
      }
    }

    await prefs.remove('token');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
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
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarBrightness: Brightness.light, // For iOS: (dark icons)
            statusBarIconBrightness: Brightness.dark, // For Android: (dark icons)
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxHeight < 600;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: constraints.maxWidth * 0.3,
                ),
                SizedBox(height: isSmall ? 12 : 20),
                const Text(
                  'VoyFy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    letterSpacing: 2,
                    fontSize: 34,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w900,
                    color: Color(0xff2572FE),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
