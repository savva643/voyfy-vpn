import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vpni/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_gradient_text/simple_gradient_text.dart';
import 'package:http/http.dart' as http;

import 'home_screen.dart';

class RegScreen extends StatefulWidget {
  const RegScreen({Key? key}) : super(key: key);
  @override
  State<RegScreen> createState() => _RegScreenState();
}

const kColorBg = Color(0xffE6E7F0);
class _RegScreenState extends State<RegScreen> {


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
                      'registervoufy'.tr().toString(),
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
                          style: const TextStyle(
                            letterSpacing: 2,
                            fontSize: 16,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w700,
                            color: Color(0xff000000),
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
                        controller: _searchServerControllernick,
                        onChanged: _checknick,
                        cursorColor: Colors.grey,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'nick'.tr().toString(),
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
                        controller: _searchServerControllerlogin,
                        onChanged: _checlogin,
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
                        controller: _searchServerController,
                        onChanged: _checkem,
                        cursorColor: Colors.grey,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'email'.tr().toString(),
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
                        cursorColor: Colors.grey,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'password'.tr().toString(),
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w300,
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
                            if (email == true &&
                                passw == true &&
                                logan == true &&
                                nicki == true) {
                              await postRequest();
                            } else if (nicki == false) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("enternick".tr().toString()),
                                ),
                              );
                            } else if (logan == false) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("enterlog".tr().toString()),
                                ),
                              );
                            } else if (email == false) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("enteremail".tr().toString()),
                                ),
                              );
                            } else if (passw == false) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("enterpass".tr().toString()),
                                ),
                              );
                            }
                          },
                          subtitle: const Text(""),
                          title: Text(
                            'register'.tr().toString(),
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
                                Color.fromARGB(255, 255, 0, 0)
                              ],
                            ),
                          ),
                          child: ListTile(
                            onTap: () async {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            subtitle: const Text(""),
                            title: Text(
                              'log_in'.tr().toString(),
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
    _searchServerControllernick.dispose();
    _searchServerControllerlogin.dispose();
    super.dispose();
  }
  final _searchServerController = TextEditingController();
  final _searchServerControllerpass = TextEditingController();
  final _searchServerControllernick = TextEditingController();
  final _searchServerControllerlogin = TextEditingController();
  bool email = false;
  bool passw = false;
  bool logan = false;
  bool nicki = false;
  _checkem(String? textVal) {
    if (textVal != null && textVal.isNotEmpty) {
      setState(() => email = true);
    }else{
      setState(() => email = false);
    }
  }
  _checpass(String? textVal) {
    if (textVal != null && textVal.isNotEmpty) {
      setState(() => passw = true);
    }else{
      setState(() => passw = false);
    }
  }
  _checknick(String? textVal) {
    if (textVal != null && textVal.isNotEmpty) {
      setState(() => nicki = true);
    }else{
      setState(() => nicki = false);
    }
  }

  Future<http.Response> postRequest() async {
    final uri = Uri.parse("http://10.0.2.2:4000/api/auth/register");

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
        "platform": Platform.isIOS ? "ios" : "android",
        "device-type": "mobile",
        "app-version": "1.0.0",
      },
      body: jsonEncode(<String, String>{
        'login': _searchServerControllerlogin.text.toString(),
        'email': _searchServerController.text.toString(),
        'password': _searchServerControllerpass.text.toString(),
        'gameNickname': _searchServerControllernick.text.toString(),
      }),
    );

    final body = response.body.toString();
    final decoded = jsonDecode(body);

    if (response.statusCode == 201 && decoded["token"] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', decoded["token"]);
      await prefs.setString('refreshToken', decoded["refreshToken"] ?? '');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("setlogin".tr().toString()),
        ),
      );
    }

    return response;
  }

  _checlogin(String? textVal) {
    if (textVal != null && textVal.isNotEmpty) {
      setState(() => logan = true);
    }else{
      setState(() => logan = false);
    }
  }

}