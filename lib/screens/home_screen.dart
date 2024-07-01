import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vpni/screens/abotapp_screen.dart';
import 'package:flutter_vpni/screens/account_sccreen.dart';
import 'package:flutter_vpni/screens/change_language.dart';
import 'package:flutter_vpni/screens/server_location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;


const kBgColor = Color(0xFF1604E2);

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();




}

class _HomeScreenState extends State<HomeScreen> {
  AssetImage am = AssetImage('assets/images/usa.jpeg');
  String nameserver = "usa".tr().toString();
  int idserv = 1;
  bool isfree = false;
  String loca = "xz";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isConnected = false;

  Duration _duration = const Duration();
  Timer? _timer;

  startTimer() {
    _pingHost('google.com');
    startchping();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      const addSeconds = 1;

      setState(() {
        final seconds = _duration.inSeconds + addSeconds;
        _duration = Duration(seconds: seconds);
      });
    });
  }

  String _parsePingOutput(String output) {
    final pattern = RegExp(r'time=(\d+\.\d+)');
    final match = pattern.firstMatch(output);
    if (match != null) {
      final rtt = match.group(1);
      return '$rtt';
    } else {
      return '0';
    }
  }

  Future<void> _pingHost(String host) async {
    try {
      final result = await Process.run('ping', ['-c', '1', host]); // -c 1 means only send one ping
      setState(() {
        double rek = double.parse(_parsePingOutput(result.stdout.toString()));
        print(rek);
        _pingResult = rek.toStringAsFixed(0);
      });
    } catch (e) {
      setState(() {
        _pingResult = '0';
      });
    }
  }
  String _pingResult = '0';

  int cb = 2;
  Future<void> getlatloc() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
    final counter = prefs.getInt('idserv') ?? 1;
    print(counter.toString());
    cb = counter;
    });
  }
  Timer? fssd;
  void startchping() {
    fssd = Timer.periodic(Duration(seconds: 5), (Timer timer) {
      _pingHost('google.com'); // Replace 'example.com' with your desired host
    });
  }



  @override
  void initState()
  {
    super.initState();
    getlatloc().then((_) {
      chacngeserveri(cb);
    });
  }

  stopTimer() {
    setState(() {
      fssd?.cancel();
      _timer?.cancel();
      _duration = const Duration();
      _pingResult = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Image(image: AssetImage('assets/images/logo.png'),width: 26),
                  SizedBox(width: 10,),
                  Text('VoyFy', style: TextStyle(fontSize: 26, fontFamily: 'Gilroy', fontWeight: FontWeight.bold, color: kBgColor,),),
                ],
              ),
            ),
         ListTile(
         onTap: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AccountScreen()));
        },
        leading: const Icon(Icons.account_circle, size: 18,),
        title:  Text('account'.tr().toString(), style: TextStyle(fontSize: 14),),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16,),
      ),
            ListTile(
              onTap: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ChangeLanguage()));
              },
              leading: const Icon(Icons.translate, size: 18,),
              title:  Text('changelang'.tr().toString(), style: TextStyle(fontSize: 14),),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16,),
            ),
            ListTile(
              onTap: ()  {
                Navigator.push(context, MaterialPageRoute(builder: (context) => AboutappScreen()));
              },
              leading: Icon(Icons.info, size: 18,),
              title: Text('aboutapp'.tr().toString(), style: TextStyle(fontSize: 14),),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16,),
            ),
          ],
        ),
      ),
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          elevation: 0,
          backgroundColor: kBgColor,

          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: kBgColor,
            statusBarBrightness: Brightness.dark, // For iOS: (dark icons)
            statusBarIconBrightness: Brightness.light, // For Android: (dark icons)
          ),
        ),
      ),

      body: SafeArea(
        child:
        Container(
          decoration: new BoxDecoration(
              gradient: new LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 0,0,255),
                  Color.fromARGB(255, 255,0,0)
                ],
              )),
          child:
        ListView(
          children: [

            SizedBox(
              height: size.height * 0.4,
              child: Column(
                children: [
                  /// header action icons
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
                          child: InkWell(
                            onTap: () {
                              _scaffoldKey.currentState?.openDrawer();
                            },
                            child: const Icon(
                              Icons.segment,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        Row(
                          children: const [
                            Image(image: AssetImage('assets/images/logo.png'),width: 22),
                            SizedBox(width: 10,),
                            Text(
                              'VoyFy',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Gilroy'
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Color.fromARGB(0, 0,0,0),
                      child: Column(
                        children: [
                          SizedBox(height: size.height * 0.02,),
                          InkWell(
                            borderRadius: BorderRadius.circular(size.height),
                            onTap: () {
                              _isConnected ? stopTimer() : startTimer();
                              setState(() => _isConnected = !_isConnected);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  width: size.height * 0.12,
                                  height: size.height * 0.12,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.power_settings_new,
                                          size: size.height * 0.035,
                                          color: kBgColor,
                                        ),
                                        Text(
                                          _isConnected ? 'disconnect'.tr().toString() : 'connect'.tr().toString(),
                                          style: TextStyle(
                                            fontSize: size.height * 0.013,
                                            fontWeight: FontWeight.w500,
                                            color: kBgColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.01,),
                          Column(
                            children: [
                              Container(
                                alignment: Alignment.center,
                                width: _isConnected ? size.height * 0.14 : size.height * 0.14,
                                height: size.height * 0.030,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  _isConnected ? 'connected'.tr().toString() : 'disconnected'.tr().toString(),
                                  style: TextStyle(
                                    fontSize: size.height * 0.015,
                                    color: kBgColor,
                                  ),
                                ),
                              ),
                              SizedBox(height: size.height * 0.012,),
                              _countDownWidget(size),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: Platform.isIOS ? size.height * 0.51 : size.height * 0.565,
              decoration:  const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              ),
              child: Column(
                children: [
                  /// horizontal line
                  Container(
                    margin: const EdgeInsets.only(top: 15),
                    decoration: BoxDecoration(
                        color: const Color(0xffB4B4C7),
                        borderRadius: BorderRadius.circular(3)
                    ),
                    height: size.height * 0.005,
                    width: 35,
                  ),
                  /// Connection Information
                  Expanded(
                    child: Padding(
                      // padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
                      padding: const EdgeInsets.fromLTRB(50, 30, 30, 0),
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: size.height * 0.07,
                                        height: size.height * 0.07,
                                        child: CircleAvatar(
                                          backgroundImage: am,
                                        ),
                                      ),
                                      const SizedBox(height: 5,),
                                      Row(
                                        children: [
                                          Text(
                                            nameserver,
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500
                                            ),
                                          ),
                                          Container(
                                            alignment: Alignment.center,
                                            height: 20,
                                            width: 90,
                                            decoration: BoxDecoration(
                                              color: isfree ? Colors.orange.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child:  Text(
                                              isfree ? 'free'.tr().toString() : 'deluxe'.tr().toString(),
                                              style: TextStyle(
                                                  color: isfree ? Colors.orange : Colors.blueAccent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5,),
                                      Text(
                                        '',
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: size.height * 0.07,
                                        height: size.height * 0.07,
                                        decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.equalizer_rounded,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                      const SizedBox(height: 5,),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _pingResult,
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500
                                            ),
                                          ),
                                          Text(
                                            'mspl'.tr().toString(),
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5,),
                                      Text(
                                        'ping'.tr().toString(),
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 30),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        InkWell(
                                        onTap: () {
                                          checkspeed();
                                        },
                                        child:
                                        Container(
                                          width: size.height * 0.07,
                                          height: size.height * 0.07,
                                          decoration: const BoxDecoration(
                                            color: Color(0xff20C4F8),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_downward,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ),
                                        ),
                                        const SizedBox(height: 5,),
                                        Row(
                                          children: [
                                            Text(
                                              downloadSpeed.toString(),
                                              style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w500
                                              ),
                                            ),
                                            Text(
                                              'mbpersecpl'.tr().toString(),
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5,),
                                        Text(
                                          'download'.tr().toString(),
                                          style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            checkspeed();
                                          },
                                          child: Container(
                                          width: size.height * 0.07,
                                          height: size.height * 0.07,
                                          decoration: const BoxDecoration(
                                            color: Color(0xff8220F9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_upward,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ),
                                        ),
                                        const SizedBox(height: 5,),
                                        Row(
                                          children: [
                                            Text(
                                              uploadSpeed.toString(),
                                              style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w500
                                              ),
                                            ),
                                            Text(
                                              'mbpersecpl'.tr().toString(),
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5,),
                                        Text(
                                          'upload'.tr().toString(),
                                          style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Material(
                    color: kBgColor,

                    child: InkWell(
                      onTap: () async {
                        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ServerLocation()));

                        setState(() {
                          chacngeserveri(result);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        child: Row(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_pin,
                                  color: Colors.white,
                                ),
                                Text(
                                  'changeloc'.tr().toString(),
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              width: 25,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.keyboard_arrow_right_outlined, size: 25, color: kBgColor,),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),

      ),
    );
  }

  Future<void> chacngeserveri(int serverId) async {
    final String response = await rootBundle.loadString('server/server.json');
    var tagsJson = jsonDecode(response)[serverId-1];
    print(tagsJson.toString());
    idserv = serverId;
    am = AssetImage(tagsJson["src"]);
    nameserver = (tagsJson["name"].toString()).tr().toString();
    isfree = tagsJson["isFree"];
  }
  double downloadSpeed = 0;
  double uploadSpeed = 0;
  Future<void> checkspeed() async {
    final String url = 'https://speed.hetzner.de/100MB.bin'; // A sample URL for testing download speed
    final int fileSize = 100 * 1024 * 1024; // 100MB in bytes
    final Stopwatch downloadWatch = Stopwatch();
    final Stopwatch uploadWatch = Stopwatch();

    downloadWatch.start();
    await http.get(Uri.parse(url));
    downloadWatch.stop();
    setState(() {
      downloadSpeed = double.parse(((fileSize / downloadWatch.elapsedMilliseconds) * 1000 / (1024 * 1024)).toStringAsFixed(1)); // Speed in MB/s
    });

    final String testUploadUrl = 'https://example.com/upload_test'; // A sample URL for testing upload speed
    final List<int> testData = List.generate(10 * 1024 * 1024, (index) => index % 256); // 10MB of random data
    final HttpClient httpClient = HttpClient();
    final HttpClientRequest request = await httpClient.postUrl(Uri.parse(testUploadUrl));
    uploadWatch.start();
    request.add(testData);
    final HttpClientResponse response = await request.close();
    uploadWatch.stop();
    httpClient.close();
    setState(() {
      uploadSpeed = double.parse(((testData.length / uploadWatch.elapsedMilliseconds) * 1000 / (1024 * 1024)).toStringAsFixed(1)); // Speed in MB/s
    });
  }




  Widget _countDownWidget(Size size) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(_duration.inMinutes.remainder(60));
    final seconds = twoDigits(_duration.inSeconds.remainder(60));
    final hours = twoDigits(_duration.inHours.remainder(60));

    return Text(
      '$hours : $minutes : $seconds',
      style: TextStyle(
          color: Colors.white,
          fontSize: size.height * 0.03
      ),
    );
  }
}




