import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../ai/ai_chat_page.dart';
import '../approvals/approvals_page.dart';
import '../groups/groups_page.dart';
import '../settings/settings_page.dart';
import '../statistics/statistics_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, String subtitle, Widget page})>[
      if (controller.can('groups.write'))
        (
          icon: Icons.groups_rounded,
          title: 'المجموعات',
          subtitle: 'المجموعات المعتمدة وحالة الردود',
          page: GroupsPage(controller: controller),
        ),
      if (controller.can('approvals.read'))
        (
          icon: Icons.approval_rounded,
          title: 'الموافقات',
          subtitle: 'طلبات اعتماد المجموعات الجديدة',
          page: ApprovalsPage(controller: controller),
        ),
      if (controller.can('statistics.read'))
        (
          icon: Icons.bar_chart_rounded,
          title: 'الإحصائيات',
          subtitle: 'الاستخدام والردود الأكثر نشاطًا',
          page: StatisticsPage(controller: controller),
        ),
      if (controller.can('commands.write'))
        (
          icon: Icons.auto_awesome_rounded,
          title: 'الذكاء الاصطناعي',
          subtitle: 'محادثة DeepSeek مع تنسيق Markdown',
          page: AiChatPage(controller: controller),
        ),
      if (controller.can('settings.read'))
        (
          icon: Icons.settings_rounded,
          title: 'الإعدادات',
          subtitle: 'المشروع والمظهر والجلسة',
          page: SettingsPage(controller: controller),
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('المزيد'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings_rounded)),
              title: Text(
                controller.deviceRoleLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                controller.deviceGroupScopeMode == 'all'
                    ? 'النطاق: كل المجموعات المسموحة'
                    : 'النطاق: ${controller.deviceGroupIds.length} مجموعة محددة',
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'لا توجد أقسام إضافية متاحة لصلاحية هذا الجهاز.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...items.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(entry.icon)),
                    title: Text(
                      entry.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(entry.subtitle),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => entry.page),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
