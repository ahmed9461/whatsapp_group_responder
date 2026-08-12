import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import 'usage_analytics_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final whatsapp = controller.whatsappStatus;
    final connected = whatsapp.connected;
    final stats = controller.statistics;

    final statusText = connected
        ? 'متصل ويعمل'
        : switch (whatsapp.state) {
            'connecting' => 'جاري الاتصال...',
            'disconnected' => 'يعيد الاتصال...',
            'pairing' => 'بانتظار الربط',
            'revoked' => 'الجلسة تحتاج إعادة ربط',
            'replaced' => 'تم استبدال الجلسة',
            'resetting' => 'جاري إعادة تجهيز الجلسة',
            'pairing_error' => 'تعذر إكمال الربط',
            'ready' => 'جاري التحقق من الاتصال',
            _ => whatsapp.registered ? 'غير متصل حاليًا' : 'غير مرتبط',
          };

    return RefreshIndicator(
      onRefresh: controller.refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'لوحة التحكم',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'تحديث الكل',
                onPressed: controller.busy ? null : controller.refreshAll,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: CircleAvatar(
                child: Icon(
                  connected
                      ? Icons.check_rounded
                      : whatsapp.requiresRelink
                          ? Icons.sync_problem_rounded
                          : Icons.sync_rounded,
                ),
              ),
              title: const Text('حالة واتساب'),
              subtitle: Text(statusText),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _Metric(
                title: 'الردود',
                value: '${controller.commands.length}',
                icon: Icons.quickreply_rounded,
              ),
              _Metric(
                title: 'المجموعات',
                value: '${controller.groups.length}',
                icon: Icons.groups_rounded,
              ),
              _Metric(
                title: 'طلبات معلقة',
                value: '${controller.approvals.length}',
                icon: Icons.hourglass_top_rounded,
              ),
              _Metric(
                title: 'استخدام ${stats.periodLabel}',
                value: '${stats.total}',
                icon: Icons.insights_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          UsageAnalyticsCard(
            statistics: stats,
            selectedPeriod: controller.statisticsPeriod,
            loading: controller.statsBusy,
            onPeriodChanged: controller.setStatisticsPeriod,
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('تعذر تحديث بعض البيانات'),
                subtitle: Text(controller.error!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
