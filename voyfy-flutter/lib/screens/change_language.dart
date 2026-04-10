import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vpni/screens/home_screen.dart';

const kGradientStart = Color(0xFF0038FF);
const kGradientEnd = Color(0xFF8220F9);

class ChangeLanguage extends StatefulWidget {
  const ChangeLanguage({Key? key}) : super(key: key);

  @override
  State<ChangeLanguage> createState() => _ChangeLanguageState();
}

class _ChangeLanguageState extends State<ChangeLanguage> {
  final List _langData = [
    {
      'src': 'assets/images/usa.jpeg',
      'lang': 'English',
      'min': 'en',
      'max': 'US'
    },
    {
      'src': 'assets/images/russia.png',
      'lang': 'Русский',
      'min': 'ru',
      'max': 'RU'
    },
  ];

  List _searchedLangData = [];
  final _searchLanguageController = TextEditingController();
  String _selectedLang = '';
  bool _isInitialized = false;

  bool get isWideView => MediaQuery.of(context).size.width > 600;

  @override
  void initState() {
    super.initState();
    _searchedLangData = _langData;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _selectedLang = context.locale.languageCode;
      _isInitialized = true;
    }
  }

  _loadSearchedLanguages(String? textVal) {
    if(textVal != null && textVal.isNotEmpty) {
      final data = _langData.where((lang) {
        return lang['lang'].toLowerCase().contains(textVal.toLowerCase());
      }).toList();
      setState(() => _searchedLangData = data);
    } else {
      setState(() => _searchedLangData = _langData);
    }
  }

  _clearSearch() {
    _searchLanguageController.clear();
    setState(() => _searchedLangData = _langData);
  }

  _selectLanguage(Map lang) async {
    setState(() => _selectedLang = lang['min']);
    context.locale = Locale(lang['min'], lang['max']);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _searchLanguageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isWideView) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kGradientStart, kGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildMobileHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(),
                        const SizedBox(height: 24),
                        Text(
                          'alllanguages'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Gilroy',
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._searchedLangData.map((lang) => _buildLanguageCard(lang)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kGradientStart, kGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar on top with gradient background
              _buildDesktopTopHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDesktopSearchBar(),
                                const SizedBox(height: 32),
                                Text(
                                  'alllanguages'.tr(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Gilroy',
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ..._searchedLangData.map((lang) => _buildDesktopLanguageCard(lang)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              'languages'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 28,
                fontFamily: 'Gilroy',
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 64),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'languages'.tr(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Gilroy',
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Text(
            'languages'.tr(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'Gilroy',
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchLanguageController,
      onChanged: _loadSearchedLanguages,
      style: const TextStyle(
        color: Colors.black87,
        fontFamily: 'Gilroy',
        fontSize: 16,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kGradientStart, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 22),
        hintText: 'search'.tr(),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontFamily: 'Gilroy',
          fontSize: 16,
        ),
        suffixIcon: _searchLanguageController.text.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20),
              onPressed: _clearSearch,
            )
          : null,
      ),
    );
  }

  Widget _buildDesktopSearchBar() {
    return TextField(
      controller: _searchLanguageController,
      onChanged: _loadSearchedLanguages,
      style: const TextStyle(
        color: Colors.black87,
        fontFamily: 'Gilroy',
        fontSize: 16,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kGradientStart, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 24),
        hintText: 'search'.tr(),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontFamily: 'Gilroy',
          fontSize: 16,
        ),
        suffixIcon: _searchLanguageController.text.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 22),
              onPressed: _clearSearch,
            )
          : null,
      ),
    );
  }

  Widget _buildLanguageCard(Map lang) {
    final isSelected = _selectedLang == lang['min'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? kGradientStart.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? kGradientStart : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (!isSelected)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _selectLanguage(lang),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      lang['src'],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    lang['lang'],
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Gilroy',
                      color: isSelected ? kGradientStart : Colors.black87,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kGradientStart.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: kGradientStart,
                      size: 20,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade400,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLanguageCard(Map lang) {
    final isSelected = _selectedLang == lang['min'];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isSelected ? kGradientStart.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? kGradientStart : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _selectLanguage(lang),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      lang['src'],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang['lang'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Gilroy',
                          color: isSelected ? kGradientStart : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang['min'].toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontFamily: 'Gilroy',
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kGradientStart.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: kGradientStart,
                      size: 24,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
