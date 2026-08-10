import 'package:flutter/material.dart';
import '../../core/app_controller.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final whatsapp = controller.whatsappStatus;
    final connected =
        whatsapp['connected'] == true || whatsapp['status'] == 'connected';
    final usage =
        controller.statistics['total'] ??
        controller.statistics['totalUsage'] ??
        0;

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
                      : Icons.link_off_rounded,
                ),
              ),
              title: const Text('حالة واتساب'),
              subtitle: Text(
                connected ? 'متصل ويعمل' : 'غير متصل أو يحتاج مراجعة',
              ),
              trailing: Text(
                connected ? 'متصل' : 'غير متصل',
                style: TextStyle(
                  color: connected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount:
                MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
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
                title: 'استخدام 24س',
                value: '$usage',
                icon: Icons.insights_rounded,
              ),
            ],
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
            Text(title),
          ],
        ),
      ),
    );
  }
}
