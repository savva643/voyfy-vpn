import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vpni/screens/home_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TwoFAScreen extends StatefulWidget {
  final String globalId;

  const TwoFAScreen({Key? key, required this.globalId}) : super(key: key);

  @override
  State<TwoFAScreen> createState() => _TwoFAScreenState();
}

class _TwoFAScreenState extends State<TwoFAScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _backupController = TextEditingController();
  bool _loading = false;
  bool _useBackup = false;

  @override
  void dispose() {
    _codeController.dispose();
    _backupController.dispose();
    super.dispose();
  }

  Future<void> _submitTotp() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('enter_code'.tr().toString())),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final uri = Uri.parse('http://10.0.2.2:4000/api/auth/login/2fa');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'platform': Platform.isIOS ? 'ios' : 'android',
          'device-type': 'mobile',
          'app-version': '1.0.0',
        },
        body: jsonEncode(<String, String>{
          'globalId': widget.globalId,
          'code': code,
        }),
      );

      final decoded = jsonDecode(response.body.toString());

      if (response.statusCode == 200 && decoded['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', decoded['token']);
        await prefs.setString('refreshToken', decoded['refreshToken'] ?? '');
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['message']?.toString() ??
                'wrong_code'.tr().toString()),
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('server_error'.tr().toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _submitBackup() async {
    final backup = _backupController.text.trim();
    if (backup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter backup code')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final uri = Uri.parse('http://10.0.2.2:4000/api/auth/login/backup-code');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'platform': Platform.isIOS ? 'ios' : 'android',
          'device-type': 'mobile',
          'app-version': '1.0.0',
        },
        body: jsonEncode(<String, String>{
          'globalId': widget.globalId,
          'backupCode': backup,
        }),
      );

      final decoded = jsonDecode(response.body.toString());

      if (response.statusCode == 200 && decoded['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', decoded['token']);
        await prefs.setString('refreshToken', decoded['refreshToken'] ?? '');
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['message']?.toString() ??
                'Invalid backup code'),
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('server_error'.tr().toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('2FA'.tr().toString()),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('2FA code'),
                  selected: !_useBackup,
                  onSelected: (v) {
                    setState(() {
                      _useBackup = false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Backup code'),
                  selected: _useBackup,
                  onSelected: (v) {
                    setState(() {
                      _useBackup = true;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!_useBackup) ...[
              Text(
                'enter_2fa_code'.tr().toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: '000000',
                ),
              ),
            ] else ...[
              const Text(
                'Enter one of your backup codes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _backupController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: 'backup-code',
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        if (_useBackup) {
                          _submitBackup();
                        } else {
                          _submitTotp();
                        }
                      },
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('confirm'.tr().toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


