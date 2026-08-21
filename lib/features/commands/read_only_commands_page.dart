import 'package:flutter/material.dart';

import '../../core/app_controller.dart';

class ReadOnlyCommandsPage extends StatelessWidget {
  const ReadOnlyCommandsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الردود'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: controller.refreshCommands,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshCommands,
        child: controller.commands.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 130),
                  Icon(Icons.visibility_outlined, size: 48),
                  SizedBox(height: 12),
                  Center(child: Text('لا توجد ردود متاحة لهذا الجهاز')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: controller.commands.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final command = controller.commands[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          command.enabled
                              ? Icons.bolt_rounded
                              : Icons.pause_rounded,
                        ),
                      ),
                      title: Text(
                        command.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${command.scopeMode == 'all' ? 'كل المجموعات' : '${command.groupIds.length} مجموعة'}\n${command.responseContent.summary}',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.visibility_rounded),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
