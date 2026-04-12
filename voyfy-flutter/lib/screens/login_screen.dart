import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vpni/screens/home_screen.dart';
import 'package:flutter_vpni/screens/reg_screen.dart';
import 'package:flutter_vpni/screens/twofa_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_gradient_text/simple_gradient_text.dart';

import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();

}

const kColorBg = Color(0xffE6E7F0);
const kColorBgDark = Color(0xFF0B1220);
const kColorCardDark = Color(0xFF1A1A2E);
const kColorTextDark = Colors.white;
const kColorTextMutedDark = Color(0xFF94A3B8);
class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = true;

  bool get isDesktop => MediaQuery.of(context).size.width > 900;
  bool get isTablet => MediaQuery.of(context).size.width > 600 && MediaQuery.of(context).size.width <= 900;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktopView = isDesktop;
    final isTabletView = isTablet;
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? kColorBgDark : kColorBg,
      body: SafeArea(
        child: isDesktopView || isTabletView
            ? _buildDesktopLayout(size, isDarkMode)
            : _buildMobileLayout(size, isDarkMode),
      ),
    );
  }

  Widget _buildMobileLayout(Size size, bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: size.height - 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogoSection(size, isMobile: true, isDarkMode: isDarkMode),
            const SizedBox(height: 32),
            _buildLoginForm(size, isMobile: true, isDarkMode: isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(Size size, bool isDarkMode) {
    return Row(
      children: [
        // Left side - Branding
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                        const Color(0xFF1A1A2E),
                        const Color(0xFF0B1220),
                      ]
                    : [
                        const Color(0xFF0038FF),
                        const Color(0xFF8220F9),
                      ],
              ),
            ),
            child: Center(
              child: _buildLogoSection(size, isMobile: false, isDarkMode: isDarkMode),
            ),
          ),
        ),
        // Right side - Login form
        Expanded(
          flex: 1,
          child: Container(
            color: isDarkMode ? kColorBgDark : kColorBg,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: _buildLoginForm(size, isMobile: false, isDarkMode: isDarkMode),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoSection(Size size, {required bool isMobile, required bool isDarkMode}) {
    if (isMobile) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0038FF).withOpacity(isDarkMode ? 0.4 : 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
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
          const SizedBox(height: 16),
          Text(
            'VoyFy',
            style: TextStyle(
              letterSpacing: 2,
              fontSize: 32,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w900,
              color: isDarkMode ? Colors.white : const Color(0xff000000),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Secure VPN Connection',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w400,
              color: isDarkMode ? kColorTextMutedDark : Colors.grey.shade600,
            ),
          ),
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'VoyFy',
            style: TextStyle(
              letterSpacing: 3,
              fontSize: 48,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w900,
              color: isDarkMode ? Colors.white : Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Secure VPN Connection',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w400,
              color: isDarkMode ? kColorTextMutedDark : Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildLoginForm(Size size, {required bool isMobile, required bool isDarkMode}) {
    final maxWidth = isMobile ? double.infinity : 400.0;
    
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontFamily: 'Gilroy',
              fontSize: 16,
            ),
            cursorColor: isDarkMode ? kColorTextMutedDark : Colors.grey,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDarkMode ? kColorCardDark : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xff0038FF), width: 1.5),
              ),
              hintText: 'Email',
              hintStyle: TextStyle(
                color: isDarkMode ? kColorTextMutedDark : Colors.grey.shade500,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _passwordVisible,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontFamily: 'Gilroy',
              fontSize: 16,
            ),
            cursorColor: isDarkMode ? kColorTextMutedDark : Colors.grey,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDarkMode ? kColorCardDark : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xff0038FF), width: 1.5),
              ),
              hintText: 'Password',
              hintStyle: TextStyle(
                color: isDarkMode ? kColorTextMutedDark : Colors.grey.shade500,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: isDarkMode ? kColorTextMutedDark : Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0038FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'or'.tr().toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              letterSpacing: 2,
              fontSize: 16,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w300,
              color: isDarkMode ? kColorTextMutedDark : const Color(0xff000000),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: Material(
              color: isDarkMode ? kColorCardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () async {
                  // TODO: social login
                },
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Text(
                    Platform.isIOS
                        ? 'loginapple'.tr().toString()
                        : 'logingoogle'.tr().toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: Material(
              color: isDarkMode ? kColorCardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () async {
                  // TODO: login via other service if needed
                },
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Text(
                    'loginservice'.tr().toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Color.fromARGB(255, 0, 0, 255),
                    Color.fromARGB(255, 255, 0, 0),
                  ],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () async {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const Center(
                    child: Text(
                      'Create account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse("http://localhost:4000/api/auth/login");

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json; charset=UTF-8",
          "platform": Platform.isIOS ? "ios" : "android",
          "device-type": "mobile",
          "app-version": "1.0.0",
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final decoded = jsonDecode(response.body);
      print('LOGIN RESPONSE: status=${response.statusCode}, body=$decoded');

      final data = decoded['data'];
      final tokens = data?['tokens'];
      if ((response.statusCode == 200 || response.statusCode == 201) && tokens != null && tokens['accessToken'] != null) {
        print('LOGIN SUCCESS: token=${tokens['accessToken']}');
        await ApiService.setTokens(tokens['accessToken'], tokens['refreshToken'] ?? '');
        await SharedPreferences.getInstance().then((prefs) {
          prefs.setString('email', email);
          prefs.setString('subscription_type', data?['subscription'] ?? 'Free');
        });
        print('TOKENS SAVED: access_token, refresh_token, email, subscription_type saved to prefs');

        if (mounted) {
          print('NAVIGATING TO HOMESCREEN...');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
          // Small delay to show toast before navigation
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      } else if (response.statusCode == 202 &&
          decoded["requires2FA"] == true &&
          decoded["globalId"] != null) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TwoFAScreen(
                globalId: decoded["globalId"].toString(),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(decoded['message'] ?? 'Login failed'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}