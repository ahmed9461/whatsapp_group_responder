import 'package:flutter/material.dart';
import '../../core/app_controller.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final stats = controller.statistics;
    final top = (stats['top'] as List?) ?? const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الإحصائيات'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: controller.refreshStats,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.insights_rounded),
                ),
                title: const Text('إجمالي استخدام آخر 24 ساعة'),
                trailing: Text(
                  '${stats['total'] ?? stats['totalUsage'] ?? 0}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'الأكثر استخدامًا',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (top.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('لا توجد بيانات بعد'),
                ),
              )
            else
              ...top.whereType<Map>().map((raw) {
                final item = Map<String, dynamic>.from(raw);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        '${item['title'] ?? item['trigger'] ?? item['command'] ?? 'رد'}',
                      ),
                      trailing: Text(
                        '${item['count'] ?? item['usageCount'] ?? 0}',
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
