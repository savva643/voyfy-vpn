import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kGradientStart = Color(0xFF0038FF);
const kGradientEnd = Color(0xFF8220F9);

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  @override
  Widget build(BuildContext context) {
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
              _buildHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
          Expanded(
            child: Text(
              'privacy_policy'.tr(),
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

  Widget _buildMobileLayout() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.locale.languageCode == 'ru' 
            ? 'Последнее обновление: 9 апреля 2026 г.'
            : 'Last updated: April 9, 2026',
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Gilroy',
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 24),
        _buildSection(
          context.locale.languageCode == 'ru' ? '1. Введение' : '1. Introduction',
          context.locale.languageCode == 'ru'
            ? 'VoyFy VPN обязуется защищать вашу конфиденциальность. Эта политика конфиденциальности объясняет, какие данные мы собираем и как мы их используем.'
            : 'VoyFy VPN is committed to protecting your privacy. This Privacy Policy explains what data we collect and how we use it.',
        ),
        _buildSection(
          context.locale.languageCode == 'ru' ? '2. Данные, которые мы собираем' : '2. Data We Collect',
          context.locale.languageCode == 'ru'
            ? 'Мы собираем минимальное количество данных, необходимых для предоставления наших услуг: адрес электронной почты (для создания учетной записи), данные о подписке и статистику использования серверов (без логов активности).'
            : 'We collect minimal data necessary to provide our services: email address (for account creation), subscription data, and server usage statistics (without activity logs).',
        ),
        _buildSection(
          context.locale.languageCode == 'ru' ? '3. Политика отсутствия логов' : '3. No-Logs Policy',
          context.locale.languageCode == 'ru'
            ? 'Мы не собираем и не храним никаких логов вашей онлайн-активности. Мы не отслеживаем посещаемые вами веб-сайты, трафик или IP-адреса, которые вы посещаете.'
            : 'We do not collect or store any logs of your online activity. We do not track the websites you visit, traffic, or IP addresses you access.',
        ),
        _buildSection(
          context.locale.languageCode == 'ru' ? '4. Безопасность данных' : '4. Data Security',
          context.locale.languageCode == 'ru'
            ? 'Мы используем современные технологии шифрования и меры безопасности для защиты ваших данных. Все соединения защищены с помощью шифрования AES-256.'
            : 'We use modern encryption technologies and security measures to protect your data. All connections are secured using AES-256 encryption.',
        ),
        _buildSection(
          context.locale.languageCode == 'ru' ? '5. Ваши права' : '5. Your Rights',
          context.locale.languageCode == 'ru'
            ? 'Вы имеете право: получить доступ к своим данным, исправить неточности, удалить свою учетную запись, отказаться от маркетинговых коммуникаций.'
            : 'You have the right to: access your data, correct inaccuracies, delete your account, and opt out of marketing communications.',
        ),
        _buildSection(
          context.locale.languageCode == 'ru' ? '6. Контакты' : '6. Contact Us',
          context.locale.languageCode == 'ru'
            ? 'Если у вас есть вопросы о этой политике конфиденциальности, пожалуйста, свяжитесь с нами через настройки приложения.'
            : 'If you have any questions about this Privacy Policy, please contact us through the app settings.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'Gilroy',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Gilroy',
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
