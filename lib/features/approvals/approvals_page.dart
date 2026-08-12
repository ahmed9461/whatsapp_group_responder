import 'package:flutter/material.dart';

import '../../core/app_controller.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  final Set<int> _acting = <int>{};

  @override
  Widget build(BuildContext context) {
    final approvals = widget.controller.approvals;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('الموافقات'),
            if (approvals.isNotEmpty) ...[
              const SizedBox(width: 8),
              Badge(label: Text('${approvals.length}')),
            ],
          ],
        ),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: widget.controller.refreshApprovals,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.controller.refreshApprovals,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: approvals.isEmpty
              ? ListView(
                  key: const ValueKey('empty-approvals'),
                  children: const [
                    SizedBox(height: 160),
                    Center(child: Icon(Icons.task_alt_rounded, size: 54)),
                    SizedBox(height: 12),
                    Center(child: Text('لا توجد طلبات معلقة')),
                  ],
                )
              : ListView.separated(
                  key: const ValueKey('approval-list'),
                  padding: const EdgeInsets.all(16),
                  itemCount: approvals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = approvals[index];
                    final acting = _acting.contains(item.id);
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
                            if (acting)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.4),
                                    ),
                                    SizedBox(width: 10),
                                    Text('جاري تنفيذ القرار...'),
                                  ],
                                ),
                              )
                            else
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
      ),
    );
  }

  Future<void> _decide(int id, bool approve) async {
    if (_acting.contains(id)) return;
    setState(() => _acting.add(id));
    try {
      await widget.controller.decideApproval(id, approve);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'تم السماح للمجموعة بنجاح.' : 'تم رفض المجموعة بنجاح.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _acting.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تنفيذ القرار: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
