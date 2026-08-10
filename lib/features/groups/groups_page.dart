import 'package:flutter/material.dart';
import '../../core/app_controller.dart';

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('المجموعات'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: controller.refreshGroups,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshGroups,
        child: controller.groups.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('لا توجد مجموعات')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: controller.groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final group = controller.groups[index];
                  final approved = group.status == 'approved';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          approved
                              ? Icons.groups_rounded
                              : Icons.lock_clock_rounded,
                        ),
                      ),
                      title: Text(
                        group.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${_status(group.status)}'
                        '${group.memberCount == null ? '' : ' • ${group.memberCount} عضو'}',
                      ),
                      trailing: approved
                          ? Switch(
                              value: group.responsesEnabled,
                              onChanged: (value) async {
                                await controller.api.setGroupResponses(
                                  group.id,
                                  value,
                                );
                                await controller.refreshGroups();
                              },
                            )
                          : null,
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _status(String value) => switch (value) {
        'approved' => 'مسموحة',
        'pending' => 'بانتظار الموافقة',
        'denied' => 'مرفوضة',
        'blocked' => 'محظورة',
        _ => value,
      };
}
