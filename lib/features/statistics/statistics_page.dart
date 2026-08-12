import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../dashboard/usage_analytics_card.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الإحصائيات'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: controller.statsBusy ? null : controller.refreshStats,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            UsageAnalyticsCard(
              statistics: controller.statistics,
              selectedPeriod: controller.statisticsPeriod,
              loading: controller.statsBusy,
              onPeriodChanged: controller.setStatisticsPeriod,
            ),
          ],
        ),
      ),
    );
  }
}
