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

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();




}

const kColorBg = Color(0xffE6E7F0);
class _LoginScreenState extends State<LoginScreen> {


  bool passwvisible = true;
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: kColorBg,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: kColorBg,
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
      ),
      backgroundColor: kColorBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxHeight < 600;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Column(
                  mainAxisAlignment:
                      isSmall ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    // Лого + название по центру, друг под другом на маленьких экранах
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: size.width * 0.18,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'VoyFy',
                          style: TextStyle(
                            letterSpacing: 2,
                            fontSize: isSmall ? 26 : 34,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w900,
                            color: const Color(0xff000000),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'loginvoufy'.tr().toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        letterSpacing: 2,
                        fontSize: isSmall ? 24 : 30,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff000000),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'via'.tr().toString(),
                          style: TextStyle(
                            letterSpacing: 2,
                            fontSize: 16,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w700,
                            color: const Color(0xff000000),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GradientText(
                          'Keep Pixel',
                          style: const TextStyle(
                            letterSpacing: 2,
                            fontSize: 18,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w700,
                          ),
                          colors: const [Color(0xff0038FF), Color(0xff829CFB)],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      height: 48,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextFormField(
                        controller: _searchServerController,
                        onChanged: _checkem,
                        cursorColor: Colors.grey,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'login'.tr().toString(),
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      height: 48,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextFormField(
                        controller: _searchServerControllerpass,
                        onChanged: _checpass,
                        obscureText: passwvisible,
                        textInputAction: TextInputAction.done,
                        cursorColor: Colors.grey,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'password'.tr().toString(),
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w300,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              passwvisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Theme.of(context).primaryColorDark,
                            ),
                            onPressed: () {
                              setState(() {
                                passwvisible = !passwvisible;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          onTap: () async {
                            if (email == true && passw == true) {
                              await postRequest();
                            } else if (email == false) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text("enterlog".tr().toString()),
                              ));
                            } else if (passw == false) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text("enterpass".tr().toString()),
                              ));
                            }
                          },
                          subtitle: const Text(""),
                          title: Text(
                            'log_in'.tr().toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'or'.tr().toString(),
                      style: const TextStyle(
                        letterSpacing: 2,
                        fontSize: 16,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w300,
                        color: Color(0xff000000),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          onTap: () async {
                            // TODO: social login
                          },
                          subtitle: const Text(""),
                          title: Text(
                            Platform.isIOS
                                ? 'loginapple'.tr().toString()
                                : 'logingoogle'.tr().toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w600,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          onTap: () async {
                            // TODO: login via other service if needed
                          },
                          subtitle: const Text(""),
                          title: Text(
                            'loginservice'.tr().toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: Material(
                        borderRadius: BorderRadius.circular(12),
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
                          child: ListTile(
                            onTap: () async {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegScreen(),
                                ),
                              );
                            },
                            subtitle: const Text(""),
                            title: Text(
                              'register'.tr().toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
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
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  @override
  void dispose() {
    _searchServerController.dispose();
    _searchServerControllerpass.dispose();
    super.dispose();
  }
  final _searchServerController = TextEditingController();
  final _searchServerControllerpass = TextEditingController();
  bool email = false;
  bool passw = false;
  _checkem(String? textVal) {
    if (textVal != null && textVal.isNotEmpty) {
      setState(() => email = true);
    }else{
      setState(() => email = false);
    }
  }
  Future<http.Response> postRequest() async {
    final uri = Uri.parse("http://10.0.2.2:4000/api/auth/login");

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
        // Можно добавить дополнительные хедеры устройства, если нужно
        "platform": Platform.isIOS ? "ios" : "android",
        "device-type": "mobile",
        "app-version": "1.0.0",
      },
      body: jsonEncode(<String, String>{
        'login': _searchServerController.text.toString(),
        'password': _searchServerControllerpass.text.toString(),
      }),
    );

    final body = response.body.toString();
    final decoded = jsonDecode(body);

    if (response.statusCode == 200 && decoded["token"] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', decoded["token"]);
      await prefs.setString('refreshToken', decoded["refreshToken"] ?? '');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (response.statusCode == 202 &&
        decoded["requires2FA"] == true &&
        decoded["globalId"] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TwoFAScreen(
            globalId: decoded["globalId"].toString(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("wrongpass".tr().toString()),
        ),
      );
    }

    return response;
  }

  _checpass(String? textVal) {
    if (textVal != null && textVal.isNotEmpty) {
      setState(() => passw = true);
    }else{
      setState(() => passw = false);
    }
  }
}