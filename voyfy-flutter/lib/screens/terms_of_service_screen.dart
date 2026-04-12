import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kGradientStart = Color(0xFF0038FF);
const kGradientEnd = Color(0xFF8220F9);

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E)],
                )
              : const LinearGradient(
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
              'terms_of_service'.tr(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            color: isDark ? const Color(0xFFB0B0B0) : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 24),
        _buildSection(
          context.locale.languageCode == 'ru' ? '1. Принятие условий' : '1. Acceptance of Terms',
          context.locale.languageCode == 'ru'
            ? 'Используя VoyFy VPN, вы соглашаетесь с этими Условиями обслуживания. Если вы не согласны с каким-либо положением, пожалуйста, не используйте наше приложение.'
            : 'By using VoyFy VPN, you agree to these Terms of Service. If you disagree with any provision, please do not use our application.',
        ),
        _buildSection(
          context.locale.languageCode == 'ru' ? '2. Описание услуг' : '2. Description of Services',
          context.locale.languageCode == 'ru'
            ? 'VoyFy VPN предоставляет услуги виртуальной частной сети (VPN) для защиты вашей конфиденциальности и безопасности в интернете. Мы предлагаем бесплатный и премиум уровни обслуживания.'
            : 'VoyFy VPN provides Virtual Private Network (VPN) services to protect your privacy and security online. We offer free and premium tiers of service.',
        ),
        _buildSection(
          context.locale.languageCode == 'ru' ? '3. Учетная запись пользователя' : '3. User Account',
          context.locale.languageCode == 'ru'
            ? 'Для использования наших услуг вам необходимо создать учетную запись. Вы несете ответственность за сохранение конфиденциальности ваших учетных данных и за все действия, происходящие под вашей учетной записью.'
            : 'To use our services, you need to create an account. You are responsible for maintaining the confidentiality of your credentials and for all activities occurring under your account.',
        ),
        _buildSection(
          context.locale.languageCode == 'ru' ? '4. Подписки и платежи' : '4. Subscriptions and Payments',
          context.locale.languageCode == 'ru'
            ? 'Премиум-подписка автоматически продлевается, если не отменена. Вы можете управлять своей подпиской в настройках приложения. Возврат средств предоставляется в соответствии с политикой возврата.'
            : 'Premium subscription automatically renews unless cancelled. You can manage your subscription in app settings. Refunds are provided according to our refund policy.',
        ),
        _buildSection(
          context.locale.languageCode == 'ru' ? '5. Запрещенные действия' : '5. Prohibited Activities',
          context.locale.languageCode == 'ru'
            ? 'При использовании VoyFy VPN запрещено: незаконная деятельность, распространение вредоносного ПО, спам, взлом, нарушение прав интеллектуальной собственности, любая незаконная деятельность.'
            : 'When using VoyFy VPN, the following is prohibited: illegal activity, malware distribution, spam, hacking, intellectual property rights violation, any illegal activity.',
        ),
        _buildSection(
          context.locale.languageCode == 'ru' ? '6. Ограничение ответственности' : '6. Limitation of Liability',
          context.locale.languageCode == 'ru'
            ? 'VoyFy VPN не несет ответственности за любой ущерб, возникший в результате использования или невозможности использования наших услуг. Мы стремимся обеспечить бесперебойную работу, но не гарантируем постоянную доступность.'
            : 'VoyFy VPN is not liable for any damages arising from the use of or inability to use our services. We strive to provide uninterrupted service but do not guarantee constant availability.',
        ),
        _buildSection(
          context.locale.languageCode == 'ru' ? '7. Изменения условий' : '7. Changes to Terms',
          context.locale.languageCode == 'ru'
            ? 'Мы оставляем за собой право изменять эти Условия обслуживания в любое время. Изменения вступают в силу с момента их публикации в приложении. Продолжение использования означает принятие новых условий.'
            : 'We reserve the right to modify these Terms of Service at any time. Changes take effect upon posting in the app. Continued use constitutes acceptance of the new terms.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'Gilroy',
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Gilroy',
              color: isDark ? const Color(0xFFB0B0B0) : Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
