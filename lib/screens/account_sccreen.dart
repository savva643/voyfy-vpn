import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vpni/screens/aboutsub_sccreen.dart';
import 'package:flutter_vpni/screens/login_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);
  @override
  State<AccountScreen> createState() => _AccountScreenState();




}

const kColorBg = Color(0xffE6E7F0);
class _AccountScreenState extends State<AccountScreen> {

  @override
  void initState()
  {
    super.initState();
    postRequest();
  }

  @override
  Widget build(BuildContext context) {
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
    /// header action icons
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    InkWell(
    onTap: () => Navigator.pop(context),
    child: const Icon(
    Icons.arrow_back_ios,
    size: 20,
    ),
    ),
    Text(
    'account'.tr().toString(),
    style: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 18
    ),
    ),
    ],
    ),
      CachedNetworkImage(
        imageUrl: imgurl,
        imageBuilder: (context, imageProvider) => Container(
          width: 80.0,
          height: 80.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
                image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        placeholder: (context, url) => CircularProgressIndicator(),
        errorWidget: (context, url, error) => Icon(Icons.error),
      ),
      Container(
        child: Text(
          nametxt,
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
        child: Text(
          emailtxt,
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 24,
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w700,
            color: Color(0xff444444),
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => AboutsubScreen()));
            },
            subtitle: new Text(""),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  child: Text(
                    'Keep Pixel',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w400,
                      color: Color(0xff000000),
                    ),
                  ),
                ),
                Container(
                  child: Text(
                    'Deluxe',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      color: Color(0xff438CEF),
                    ),
                  ),
                ),
          Container(
            margin: const EdgeInsets.only(left: 80),
            child:Text(
            'активна',
            style: TextStyle(
              letterSpacing: 2,
              fontSize: 20,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w700,
              color: Color(0xff000000),
            ),
            )
          ),

              ],
              ),
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.only(top: 22),
        height: 48,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen(),));
            },
            subtitle: new Text(""),
            title: Text(
              textAlign: TextAlign.center,
              'logout'.tr().toString(),
              style: const TextStyle(
                fontSize: 18,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    ]
    ),
    ),
    )
    );
  }

  String nametxt = "_";
  String emailtxt = "name@example.com";
  String imgurl = "https://keeppixel.ru/iconprof/standart.png";
  int delxitype = 0;
  Future<http.Response> postRequest () async {
    final prefs = await SharedPreferences.getInstance();
    final tk = prefs.getString('token') ?? "0";
    var urli = Uri.parse("https://kompot.fun/getabout?token="+tk);

    var response = await http.post(urli,
      headers: {"Content-Type": "application/json; charset=UTF-8"},
      body: jsonEncode(<String, String>{
        'login': "klkjh",
      }),
    );
    String dff = response.body.toString();
    print(dff);
    setState(() {
      nametxt = (jsonDecode(dff))["nick"];
      emailtxt = (jsonDecode(dff))["email"];
      imgurl = (jsonDecode(dff))["img"];
      delxitype = int.parse((jsonDecode(dff))["deluxetype"]);
    });
    return response;
  }
}