import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vpni/screens/home_screen.dart';

class AboutappScreen extends StatefulWidget {
  const AboutappScreen({Key? key}) : super(key: key);

  @override
  State<AboutappScreen> createState() => _AboutappScreenState();
}
const kColorBg = Color(0xffE6E7F0);
class _AboutappScreenState extends State<AboutappScreen> {

  @override
  void initState() {
    super.initState();
  }

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
                'aboutapp'.tr().toString(),
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 18
                ),
              ),
            ],
          ),
      Container(
        margin: const EdgeInsets.only(top: 20,),
            child: Image.asset('assets/images/logo.png',),
          ),
          Positioned(
            child: Container(
              margin: EdgeInsets.only(top: size.height * 0.01),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(left: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'VoyFy',
                      style: TextStyle(
                        letterSpacing: 2,
                        fontSize: 38,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w900,
                        color: Color(0xff2572FE),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      Container(
        margin: const EdgeInsets.only(top: 20,),
        child: Text(
          '1.0',
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 20,
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w900,
            color: Color(0xff000000),
          ),
        ),
      ),
        ],
      ),
    ),
      ),
    );
  }
}
