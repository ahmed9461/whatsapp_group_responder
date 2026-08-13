import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../messaging/content_composer.dart';
import '../messaging/group_selector.dart';

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
            tooltip: 'تحديث',
            onPressed: widget.controller.refreshCommands,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
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
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final command = items[index];
                        return Card(
                          child: ListTile(
                            onTap: () => _open(command),
                            leading: CircleAvatar(
                              child: Icon(
                                command.enabled
                                    ? Icons.bolt_rounded
                                    : Icons.pause_rounded,
                              ),
                            ),
                            title: Text(
                              command.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${command.scopeMode == 'all' ? 'كل المجموعات' : '${command.groupIds.length} مجموعة'}\n'
                              '${command.responseContent.summary}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: command.enabled,
                                  onChanged: (value) async {
                                    await widget.controller.api.updateCommand(
                                      command.id,
                                      {'enabled': value},
                                    );
                                    await widget.controller.refreshCommands();
                                  },
                                ),
                                IconButton(
                                  tooltip: 'حذف الرد',
                                  onPressed: () => _deleteFromList(command),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                ),
                              ],
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

  Future<void> _open([ApiCommand? command]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommandEditorPage(
          controller: widget.controller,
          command: command,
        ),
      ),
    );
    if (changed == true) await widget.controller.refreshCommands();
  }

  Future<void> _deleteFromList(ApiCommand command) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الرد؟'),
        content: Text(
          'سيتم حذف الرد «${command.title}» نهائيًا ولن يستجيب له البوت بعد ذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.controller.api.deleteCommand(command.id);
      await widget.controller.refreshCommands();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الرد.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف الرد: $error')),
        );
      }
    }
  }
}

class CommandEditorPage extends StatefulWidget {
  const CommandEditorPage({
    super.key,
    required this.controller,
    this.command,
  });

  final AppController controller;
  final ApiCommand? command;

  @override
  State<CommandEditorPage> createState() => _CommandEditorPageState();
}

class _CommandEditorPageState extends State<CommandEditorPage> {
  late final TextEditingController _trigger;
  final _aliasesKey = GlobalKey<_AliasesEditorState>();
  late int _cooldown;
  late bool _enabled;
  late String _scopeMode;
  late Set<int> _groupIds;
  late ApiMessageContent _content;
  int _step = 0;
  bool _saving = false;

  bool get editing => widget.command != null;

  @override
  void initState() {
    super.initState();
    final command = widget.command;
    _trigger = TextEditingController(text: command?.title ?? '');
    _cooldown = command?.cooldownSeconds ?? 3;
    _enabled = command?.enabled ?? true;
    _scopeMode = command?.scopeMode ?? 'all';
    _groupIds = {...?command?.groupIds};
    _content = command?.responseContent ??
        const ApiMessageContent(components: []);
  }

  @override
  void dispose() {
    _trigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل الرد' : 'إضافة رد جديد'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'حذف الرد',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (value) => setState(() => _step = value),
        onStepContinue: _saving ? null : _continue,
        onStepCancel: _saving
            ? null
            : () {
                if (_step > 0) setState(() => _step--);
              },
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: details.onStepContinue,
                icon: Icon(
                  _step == 3
                      ? Icons.save_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _step == 3
                      ? (editing ? 'حفظ التعديلات' : 'إنشاء الرد')
                      : 'التالي',
                ),
              ),
              if (_step > 0) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('السابق'),
                ),
              ],
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('1. الأمر والإعدادات'),
            isActive: _step >= 0,
            content: Column(
              children: [
                TextField(
                  controller: _trigger,
                  enabled: !editing,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: 'الكلمة/الأمر الدقيق',
                    helperText: editing
                        ? 'الأمر الأساسي لا يتغير؛ استخدم الأسماء البديلة لإضافة صيغة أخرى.'
                        : 'الرد يعمل عند تطابق الرسالة مع هذا الأمر.',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text('فترة الانتظار: $_cooldown ثانية')),
                    SizedBox(
                      width: 180,
                      child: Slider(
                        value: _cooldown.toDouble(),
                        min: 0,
                        max: 60,
                        divisions: 60,
                        onChanged: (value) =>
                            setState(() => _cooldown = value.round()),
                      ),
                    ),
                  ],
                ),
                if (editing)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _enabled,
                    title: const Text('الرد مفعّل'),
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
              ],
            ),
          ),
          Step(
            title: const Text('2. المجموعات'),
            isActive: _step >= 1,
            content: GroupSelector(
              groups: widget.controller.groups,
              mode: _scopeMode,
              selectedIds: _groupIds,
              onModeChanged: (value) {
                setState(() {
                  _scopeMode = value;
                  if (value == 'all') _groupIds.clear();
                });
              },
              onSelectionChanged: (value) => setState(() => _groupIds = value),
              allLabel: 'كل المجموعات',
            ),
          ),
          Step(
            title: const Text('3. محتوى الرد'),
            isActive: _step >= 2,
            content: ContentComposer(
              controller: widget.controller,
              value: _content,
              onChanged: (value) => _content = value,
              title: 'محتوى الرد بالترتيب',
            ),
          ),
          Step(
            title: const Text('4. المراجعة والحفظ'),
            isActive: _step >= 3,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _review('الأمر', _trigger.text.trim()),
                _review(
                  'النطاق',
                  _scopeMode == 'all'
                      ? 'جميع المجموعات المعتمدة'
                      : '${_groupIds.length} مجموعة محددة',
                ),
                _review('Cooldown', '$_cooldown ثانية'),
                const SizedBox(height: 12),
                Text(
                  'المحتوى',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(_content.summary),
                  ),
                ),
                if (editing) ...[
                  const SizedBox(height: 16),
                  _AliasesEditor(
                    key: _aliasesKey,
                    controller: widget.controller,
                    command: widget.command!,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('حذف الرد نهائيًا'),
                  ),
                ],
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _review(String title, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: SizedBox(
        width: 190,
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _continue() async {
    if (_step == 0 && _trigger.text.trim().isEmpty) {
      _message('اكتب الأمر أولًا.');
      return;
    }
    if (_step == 1 && _scopeMode == 'selected' && _groupIds.isEmpty) {
      _message('اختر مجموعة واحدة على الأقل.');
      return;
    }
    if (_step == 2 && _content.isEmpty) {
      _message('أضف نصًا أو وسائط للرد.');
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (editing) {
        await widget.controller.api.updateCommand(
          widget.command!.id,
          {
            'responseContent': _content.toJson(),
            'scopeMode': _scopeMode,
            'groupIds': _scopeMode == 'all' ? <int>[] : _groupIds.toList(),
            'cooldownSeconds': _cooldown,
            'enabled': _enabled,
          },
        );
        // If the owner typed a new alias and pressed the main Save button
        // without tapping the small + button first, commit it as part of the
        // same save action instead of silently discarding it.
        await _aliasesKey.currentState?.savePendingAlias();
      } else {
        await widget.controller.api.createCommand(
          trigger: _trigger.text.trim(),
          responseContent: _content,
          scopeMode: _scopeMode,
          groupIds: _groupIds.toList(),
          cooldownSeconds: _cooldown,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _message('تعذر الحفظ: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final command = widget.command;
    if (command == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الرد؟'),
        content: Text(
          'سيتم حذف الرد «${command.title}» نهائيًا ولن يستجيب له البوت بعد ذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await widget.controller.api.deleteCommand(command.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _message('تعذر حذف الرد: $error');
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _AliasesEditor extends StatefulWidget {
  const _AliasesEditor({
    super.key,
    required this.controller,
    required this.command,
  });

  final AppController controller;
  final ApiCommand command;

  @override
  State<_AliasesEditor> createState() => _AliasesEditorState();
}

class _AliasesEditorState extends State<_AliasesEditor> {
  final _alias = TextEditingController();
  late ApiCommand _command;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _command = widget.command;
  }

  @override
  void dispose() {
    _alias.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aliases = _command.triggers.where((trigger) => !trigger.primary).toList();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('الأسماء البديلة'),
      subtitle: Text('${aliases.length} اسم بديل'),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _command.triggers
              .map(
                (trigger) => InputChip(
                  label: Text(trigger.text),
                  onDeleted: trigger.primary || _busy ? null : () => _remove(trigger),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _alias,
                enabled: !_busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) async => _add(),
                decoration: const InputDecoration(
                  labelText: 'اسم بديل جديد',
                  helperText: 'اضغط + أو «حفظ التعديلات» وسيتم حفظ الاسم.',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _busy ? null : _add,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> savePendingAlias() async {
    if (_alias.text.trim().isEmpty) return;
    await _add(showSuccess: false);
  }

  Future<void> _add({bool showSuccess = true}) async {
    final value = _alias.text.trim();
    if (value.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      _command = await widget.controller.api.addAlias(_command.id, value);
      _alias.clear();
      await widget.controller.refreshCommands();
      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الاسم البديل.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الاسم البديل: $error')),
        );
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(ApiTrigger trigger) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _command = await widget.controller.api.removeAlias(
        _command.id,
        trigger.id,
      );
      await widget.controller.refreshCommands();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف الاسم البديل: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
