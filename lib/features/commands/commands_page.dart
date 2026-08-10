import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../../core/models.dart';

class CommandsPage extends StatefulWidget {
  const CommandsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<CommandsPage> createState() => _CommandsPageState();
}

class _CommandsPageState extends State<CommandsPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = widget.controller.commands.where((command) {
      return query.isEmpty ||
          command.title.toLowerCase().contains(query) ||
          command.triggers.any(
            (trigger) => trigger.text.toLowerCase().contains(query),
          );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الردود'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: widget.controller.refreshCommands,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة رد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'بحث في الردود...',
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.controller.refreshCommands,
              child: items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 140),
                        Center(child: Text('لا توجد ردود مطابقة')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final command = items[index];
                        return Card(
                          child: ListTile(
                            onTap: () => _edit(command),
                            leading: CircleAvatar(
                              child: Icon(
                                command.enabled
                                    ? Icons.bolt_rounded
                                    : Icons.pause_rounded,
                              ),
                            ),
                            title: Text(
                              command.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              command.responseText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Switch(
                              value: command.enabled,
                              onChanged: (value) async {
                                await widget.controller.api.updateCommand(
                                  command.id,
                                  {'enabled': value},
                                );
                                await widget.controller.refreshCommands();
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final trigger = TextEditingController();
    final response = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة رد'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: trigger,
                decoration: const InputDecoration(labelText: 'الأمر'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: response,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'نص الرد'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true &&
        trigger.text.trim().isNotEmpty &&
        response.text.trim().isNotEmpty) {
      await widget.controller.api.createCommand(
        trigger: trigger.text.trim(),
        responseText: response.text,
      );
      await widget.controller.refreshCommands();
    }
  }

  Future<void> _edit(ApiCommand command) async {
    final response = TextEditingController(text: command.responseText);
    final alias = TextEditingController();
    var cooldown = command.cooldownSeconds.toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  command.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: response,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'نص الرد'),
                ),
                const SizedBox(height: 16),
                Text('Cooldown: ${cooldown.round()} ثانية'),
                Slider(
                  value: cooldown,
                  min: 0,
                  max: 60,
                  divisions: 60,
                  onChanged: (value) {
                    setSheetState(() => cooldown = value);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'الأسماء البديلة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: command.triggers.map((trigger) {
                    return InputChip(
                      label: Text(trigger.text),
                      onDeleted: trigger.primary
                          ? null
                          : () async {
                              await widget.controller.api.removeAlias(
                                command.id,
                                trigger.id,
                              );
                              await widget.controller.refreshCommands();
                              if (context.mounted) Navigator.pop(context);
                            },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: alias,
                        decoration: const InputDecoration(
                          labelText: 'إضافة Alias',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () async {
                        if (alias.text.trim().isEmpty) return;
                        await widget.controller.api.addAlias(
                          command.id,
                          alias.text.trim(),
                        );
                        await widget.controller.refreshCommands();
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    await widget.controller.api.updateCommand(
                      command.id,
                      {
                        'responseText': response.text,
                        'cooldownSeconds': cooldown.round(),
                      },
                    );
                    await widget.controller.refreshCommands();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('حفظ التعديلات'),
                ),
                TextButton.icon(
                  onPressed: () => _delete(command, context),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف الرد'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _delete(ApiCommand command, BuildContext sheetContext) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الرد؟'),
        content: Text('سيتم حذف "${command.title}" نهائيًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.api.deleteCommand(command.id);
      await widget.controller.refreshCommands();
      if (sheetContext.mounted) Navigator.pop(sheetContext);
    }
  }
}
