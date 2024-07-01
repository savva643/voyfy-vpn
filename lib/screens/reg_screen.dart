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
            statusBarBrightness: Brightness.light, // For iOS: (dark icons)
            statusBarIconBrightness: Brightness.dark, // For Android: (dark icons)
          ),
        ),
      ),
      backgroundColor: kColorBg,
      body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
            child: Column(
                children: [
                  Positioned(
                    child: Container(
                      margin: EdgeInsets.only(top: size.height * 0.01),
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              child: Image.asset('assets/images/logo.png', width: 50),
                            ),
                            Container(
                              child:
                              Text(
                                'VoyFy',
                                style: TextStyle(
                                  letterSpacing: 2,
                                  fontSize: 34,
                                  fontFamily: 'Gilroy',
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xff000000),
                                ),
                              ),
                              margin: EdgeInsets.only(left: 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 30,),
                    child: Text(
                      'registervoufy'.tr().toString(),
                      style: TextStyle(
                        letterSpacing: 2,
                        fontSize: 34,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w700,
                        color: Color(0xff000000),
                      ),
                    ),
                  ),
                  Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          child: Text(
                            'via'.tr().toString(),
                            style: TextStyle(
                              letterSpacing: 2,
                              fontSize: 20,
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w700,
                              color: Color(0xff000000),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 10,),
                          child: GradientText(
                            'Keep Pixel',
                            style: TextStyle(
                              letterSpacing: 2,
                              fontSize: 20,
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w700,
                            ),
                            colors: [Color(0xff0038FF), Color(0xff829CFB)],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20,),
                    padding: const EdgeInsets.only(left: 15, right: 15),
                    height: 44,
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
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Gilroy', fontWeight: FontWeight.w300,),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20,),
                    padding: const EdgeInsets.only(left: 15, right: 15),
                    height: 44,
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
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Gilroy', fontWeight: FontWeight.w300,),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20,),
                    padding: const EdgeInsets.only(left: 15, right: 15),
                    height: 44,
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
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Gilroy', fontWeight: FontWeight.w300,),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 16,),
                    padding: const EdgeInsets.only(left: 15, right: 15),
                    height: 44,
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
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Gilroy', fontWeight: FontWeight.w300,),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    height: 48,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        onTap: () async {
                          if(email == true && passw == true && logan == true && nicki == true) {
                            postRequest();
                          }else if(nicki == false){
                            ScaffoldMessenger.of(context).showSnackBar( SnackBar(
                              content: Text("enternick".tr().toString()),
                            ));
                          }else if(logan == false){
                            ScaffoldMessenger.of(context).showSnackBar( SnackBar(
                              content: Text("enterlog".tr().toString()),
                            ));
                          }else if(email == false){
                            ScaffoldMessenger.of(context).showSnackBar( SnackBar(
                              content: Text("enteremail".tr().toString()),
                            ));
                          }else if(passw == false){
                            ScaffoldMessenger.of(context).showSnackBar( SnackBar(
                              content: Text("enterpass".tr().toString()),
                            ));
                          }
                        },
                        subtitle: new Text(""),
                        title: Text(
                          textAlign: TextAlign.center,
                          'register'.tr().toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 22),
                    height: 48,
                    child: Material(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration:new BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: new LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                Color.fromARGB(255, 0,0,255),
                                Color.fromARGB(255, 255,0,0)
                              ],
                            )),
                        child: ListTile(
                          onTap: () async {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen(),));
                          },
                          subtitle: new Text(""),
                          title: Text(
                            textAlign: TextAlign.center,
                            'log_in'.tr().toString(),
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
                ]
            ),
          )
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

  Future<http.Response> postRequest () async {
    var urli = Uri.parse("https://kompot.fun/regvoyfy?login="+ _searchServerControllerlogin.text.toString()+"&password="+_searchServerControllerpass.text.toString()+"&name="+_searchServerControllernick.text.toString()+"&email="+_searchServerController.text.toString());


    var response = await http.post(urli,
      headers: {"Content-Type": "application/json; charset=UTF-8"},
      body: jsonEncode(<String, String>{
        'login': _searchServerController.text.toString(),
        'password': _searchServerControllerpass.text.toString(),
      }),
    );
    String dff = response.body.toString();
    if((jsonDecode(dff))["status"] =="true"){
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', (jsonDecode(dff))["token"]);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(),));
    }else{
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(
        content: Text("setlogin".tr().toString()),
      ));
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