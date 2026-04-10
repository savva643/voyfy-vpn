import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../widgets/plan_card.dart';

class PremiumContent extends StatelessWidget {
  final bool isDesktop;

  const PremiumContent({Key? key, required this.isDesktop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildMobileLayout() {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Text(
                    'premium_plans'.tr(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Gilroy',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'choose_best_plan'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Gilroy',
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildMonthlyPlan(),
                  const SizedBox(height: 16),
                  _buildYearlyPlan(),
                  const SizedBox(height: 16),
                  _buildLifetimePlan(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'premium_plans'.tr(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Gilroy',
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'choose_best_plan'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Gilroy',
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildMonthlyPlan()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildYearlyPlan()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildLifetimePlan()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyPlan() {
    return PlanCard(
      title: 'monthly'.tr(),
      price: '\$9.99',
      period: '/month',
      features: ['all_servers'.tr(), 'unlimited_bandwidth'.tr(), 'priority_support'.tr()],
      isPopular: false,
    );
  }

  Widget _buildYearlyPlan() {
    return PlanCard(
      title: 'yearly'.tr(),
      price: '\$59.99',
      period: '/year',
      features: ['all_servers'.tr(), 'unlimited_bandwidth'.tr(), 'priority_support'.tr(), 'save_50'.tr()],
      isPopular: true,
    );
  }

  Widget _buildLifetimePlan() {
    return PlanCard(
      title: 'lifetime'.tr(),
      price: '\$149.99',
      period: 'one-time',
      features: ['all_servers'.tr(), 'unlimited_bandwidth'.tr(), 'lifetime_updates'.tr(), 'best_value'.tr()],
      isPopular: false,
    );
  }
}