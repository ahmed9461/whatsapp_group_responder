import 'package:flutter/material.dart';
import '../../core/app_controller.dart';

class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('الموافقات'),
            if (controller.approvals.isNotEmpty) ...[
              const SizedBox(width: 8),
              Badge(label: Text('${controller.approvals.length}')),
            ],
          ],
        ),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: controller.refreshApprovals,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshApprovals,
        child: controller.approvals.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('لا توجد طلبات معلقة')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: controller.approvals.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = controller.approvals[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.groupName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (item.memberCount != null)
                            Text('الأعضاء: ${item.memberCount}'),
                          if (item.actorName != null)
                            Text('أضاف الرقم: ${item.actorName}'),
                          if (item.actorPhone != null)
                            Text(
                              'الرقم: ${item.actorPhone}',
                              textDirection: TextDirection.ltr,
                            ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _decide(item.id, true),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('سماح'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _decide(item.id, false),
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('رفض'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _decide(int id, bool approve) async {
    await controller.api.decideApproval(id, approve);
    await Future.wait([
      controller.refreshApprovals(),
      controller.refreshGroups(),
    ]);
  }
}
