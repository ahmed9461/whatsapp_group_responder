import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../messaging/content_composer.dart';
import '../messaging/group_selector.dart';

class ScheduledPage extends StatefulWidget {
  const ScheduledPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<ScheduledPage> createState() => _ScheduledPageState();
}

class _ScheduledPageState extends State<ScheduledPage> {
  @override
  Widget build(BuildContext context) {
    final items = widget.controller.scheduledCampaigns;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الرسائل المجدولة'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: widget.controller.refreshScheduled,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWizard(),
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('جدول جديد'),
      ),
      body: RefreshIndicator(
        onRefresh: widget.controller.refreshScheduled,
        child: items.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.schedule_send_rounded, size: 64),
                  SizedBox(height: 18),
                  Text('لا توجد رسائل مجدولة بعد.', textAlign: TextAlign.center),
                  SizedBox(height: 8),
                  Text(
                    'أنشئ جدولًا، اختر المجموعات، أضف مجموعة رسائل، ثم فعّل الجدولة.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final campaign = items[index];
                  return Card(
                    child: ListTile(
                      onTap: () => _openDetails(campaign),
                      leading: CircleAvatar(
                        child: Icon(
                          campaign.enabled
                              ? Icons.schedule_send_rounded
                              : Icons.pause_rounded,
                        ),
                      ),
                      title: Text(
                        campaign.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${intervalLabel(campaign.intervalSeconds)} • '
                        '${selectionLabel(campaign.selectionMode)}\n'
                        '${campaign.messages.length} رسالة • '
                        '${campaign.targetMode == 'all' ? 'كل المجموعات' : '${campaign.targets.length} مجموعة'}',
                      ),
                      trailing: Switch(
                        value: campaign.enabled,
                        onChanged: (value) async {
                          await widget.controller.api.updateScheduledCampaign(
                            campaign.id,
                            {'enabled': value},
                          );
                          await widget.controller.refreshScheduled();
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openWizard([ApiScheduledCampaign? campaign]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduledWizardPage(
          controller: widget.controller,
          campaign: campaign,
        ),
      ),
    );
    if (changed == true) await widget.controller.refreshScheduled();
  }

  Future<void> _openDetails(ApiScheduledCampaign campaign) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduledDetailsPage(
          controller: widget.controller,
          campaignId: campaign.id,
        ),
      ),
    );
    if (changed == true) await widget.controller.refreshScheduled();
  }
}

class ScheduledWizardPage extends StatefulWidget {
  const ScheduledWizardPage({
    super.key,
    required this.controller,
    this.campaign,
  });

  final AppController controller;
  final ApiScheduledCampaign? campaign;

  @override
  State<ScheduledWizardPage> createState() => _ScheduledWizardPageState();
}

class _ScheduledWizardPageState extends State<ScheduledWizardPage> {
  late final TextEditingController _name;
  late final TextEditingController _hours;
  late String _selectionMode;
  late String _targetMode;
  late Set<int> _groupIds;
  late bool _enabled;
  ApiMessageContent _initial = const ApiMessageContent(components: []);
  int _step = 0;
  bool _saving = false;

  bool get editing => widget.campaign != null;
  int get lastStep => editing ? 3 : 4;

  @override
  void initState() {
    super.initState();
    final campaign = widget.campaign;
    _name = TextEditingController(text: campaign?.name ?? '');
    _hours = TextEditingController(
      text: campaign == null ? '12' : hoursText(campaign.intervalSeconds),
    );
    _selectionMode = campaign?.selectionMode ?? 'shuffle';
    _targetMode = campaign?.targetMode ?? 'all';
    _groupIds = {...?campaign?.groupIds};
    _enabled = campaign?.enabled ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _hours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'تعديل الجدول' : 'إنشاء جدول رسائل')),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (value) => setState(() => _step = value),
        onStepContinue: _saving ? null : _continue,
        onStepCancel: _saving || _step == 0
            ? null
            : () => setState(() => _step--),
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: details.onStepContinue,
                  icon: Icon(
                    _step == lastStep
                        ? Icons.save_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(
                    _step == lastStep
                        ? (editing ? 'حفظ الجدول' : 'إنشاء الجدول')
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
          );
        },
        steps: [
          Step(
            title: const Text('1. الاسم والتكرار'),
            isActive: _step >= 0,
            content: Column(
              children: [
                TextField(
                  controller: _name,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'اسم الجدول',
                    hintText: 'مثال: تذكيرات عامة',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _hours,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'التكرار بالساعات',
                    helperText:
                        'مثال: 12 = كل 12 ساعة. الحد الأدنى 5 دقائق (0.083 ساعة).',
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('2. المجموعات'),
            isActive: _step >= 1,
            content: GroupSelector(
              groups: widget.controller.groups,
              mode: _targetMode,
              selectedIds: _groupIds,
              onModeChanged: (value) {
                setState(() {
                  _targetMode = value;
                  if (value == 'all') _groupIds.clear();
                });
              },
              onSelectionChanged: (value) => setState(() => _groupIds = value),
            ),
          ),
          Step(
            title: const Text('3. طريقة الاختيار والتفعيل'),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('طريقة اختيار الرسالة'),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _selectionMode,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'shuffle',
                      child: Text('عشوائي بدون تكرار'),
                    ),
                    DropdownMenuItem(
                      value: 'random',
                      child: Text('عشوائي بالكامل'),
                    ),
                    DropdownMenuItem(
                      value: 'ordered',
                      child: Text('بالترتيب'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectionMode = value);
                  },
                ),
                if (_selectionMode == 'shuffle')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'سيتم إرسال كل الرسائل مرة قبل بدء دورة عشوائية جديدة.',
                    ),
                  ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  title: const Text('تفعيل الجدول بعد الحفظ'),
                  subtitle: const Text(
                    'يمكنك تركه متوقفًا حتى تنتهي من إضافة الرسائل.',
                  ),
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              ],
            ),
          ),
          if (!editing)
            Step(
              title: const Text('4. أول رسالة'),
              isActive: _step >= 3,
              content: ContentComposer(
                controller: widget.controller,
                value: _initial,
                onChanged: (value) => _initial = value,
                title: 'أول رسالة في مجموعة الجدول',
              ),
            ),
          Step(
            title: Text('${editing ? 4 : 5}. المراجعة والحفظ'),
            isActive: _step >= lastStep,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _review('الاسم', _name.text.trim()),
                _review('التكرار', intervalLabel(_seconds() ?? 0)),
                _review('الاختيار', selectionLabel(_selectionMode)),
                _review(
                  'المجموعات',
                  _targetMode == 'all'
                      ? 'جميع المجموعات المعتمدة'
                      : '${_groupIds.length} مجموعة محددة',
                ),
                _review('الحالة', _enabled ? 'مفعّل' : 'متوقف'),
                if (!editing) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'أول رسالة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_initial.summary),
                    ),
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
    if (_step == 0) {
      if (_name.text.trim().isEmpty) {
        _message('اكتب اسم الجدول.');
        return;
      }
      final seconds = _seconds();
      if (seconds == null || seconds < 300 || seconds > 31536000) {
        _message('أدخل تكرارًا صحيحًا من 5 دقائق حتى سنة.');
        return;
      }
    }
    if (_step == 1 && _targetMode == 'selected' && _groupIds.isEmpty) {
      _message('اختر مجموعة واحدة على الأقل.');
      return;
    }
    if (!editing && _step == 3 && _initial.isEmpty) {
      _message('أضف أول رسالة للجدول.');
      return;
    }
    if (_step < lastStep) {
      setState(() => _step++);
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final seconds = _seconds()!;
      if (editing) {
        await widget.controller.api.updateScheduledCampaign(
          widget.campaign!.id,
          {
            'name': _name.text.trim(),
            'intervalSeconds': seconds,
            'selectionMode': _selectionMode,
            'targetMode': _targetMode,
            'groupIds': _targetMode == 'all' ? <int>[] : _groupIds.toList(),
            'enabled': _enabled,
          },
        );
      } else {
        final campaign = await widget.controller.api.createScheduledCampaign(
          name: _name.text.trim(),
          intervalSeconds: seconds,
          selectionMode: _selectionMode,
          targetMode: _targetMode,
          groupIds: _groupIds.toList(),
          enabled: _enabled,
        );
        await widget.controller.api.addScheduledMessage(campaign.id, _initial);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _message('تعذر حفظ الجدول: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int? _seconds() {
    final hours = double.tryParse(_hours.text.trim().replaceAll(',', '.'));
    if (hours == null || hours <= 0) return null;
    return (hours * 3600).round();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class ScheduledDetailsPage extends StatefulWidget {
  const ScheduledDetailsPage({
    super.key,
    required this.controller,
    required this.campaignId,
  });

  final AppController controller;
  final int campaignId;

  @override
  State<ScheduledDetailsPage> createState() => _ScheduledDetailsPageState();
}

class _ScheduledDetailsPageState extends State<ScheduledDetailsPage> {
  ApiScheduledCampaign? _campaign;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _busy = true);
    try {
      _campaign = ApiScheduledCampaign.fromJson(
        await widget.controller.api
            .getMap('/scheduled-campaigns/${widget.campaignId}'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = _campaign;
    return Scaffold(
      appBar: AppBar(
        title: Text(campaign?.name ?? 'الجدول'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _busy || campaign == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: campaign.enabled,
                          title: const Text('التشغيل'),
                          subtitle: Text(
                            campaign.enabled ? 'الجدول يعمل' : 'الجدول متوقف',
                          ),
                          onChanged: (value) async {
                            await widget.controller.api.updateScheduledCampaign(
                              campaign.id,
                              {'enabled': value},
                            );
                            await _load();
                          },
                        ),
                        const Divider(),
                        _info('التكرار', intervalLabel(campaign.intervalSeconds)),
                        _info(
                          'طريقة الاختيار',
                          selectionLabel(campaign.selectionMode),
                        ),
                        _info(
                          'النطاق',
                          campaign.targetMode == 'all'
                              ? 'جميع المجموعات المعتمدة'
                              : '${campaign.targets.length} مجموعة',
                        ),
                        _info('الإرسال القادم', formatDate(campaign.nextRunAt)),
                        _info('آخر إرسال', formatDate(campaign.lastSentAt)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: campaign.messages.isEmpty ? null : _runNow,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('إرسال الآن'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _edit,
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('الإعدادات'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'مجموعة الرسائل',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: _addMessage,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (campaign.messages.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'لا توجد رسائل. أضف رسالة قبل تشغيل الجدول.',
                      ),
                    ),
                  )
                else
                  ...campaign.messages.map(
                    (message) => Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${message.sortOrder + 1}')),
                        title: Text(
                          message.content.summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('أُرسلت ${message.timesSent} مرة'),
                        trailing: IconButton(
                          onPressed: () => _deleteMessage(message.id),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    ),
                  ),
                if (campaign.targetMode == 'selected') ...[
                  const SizedBox(height: 18),
                  Text(
                    'المجموعات المحددة',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  ...campaign.targets.map(
                    (target) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.groups_rounded),
                      title: Text(target.groupName),
                      subtitle: Text(target.status),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _deleteCampaign,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف الجدول'),
                ),
              ],
            ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _runNow() async {
    try {
      final dispatch =
          await widget.controller.api.runScheduledNow(widget.campaignId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم وضع الإرسال #${dispatch.id} في الطابور.'),
          ),
        );
      }
      await _load();
    } catch (error) {
      _message('تعذر الإرسال: $error');
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduledWizardPage(
          controller: widget.controller,
          campaign: _campaign,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _addMessage() async {
    final content = await Navigator.push<ApiMessageContent>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduledContentPage(controller: widget.controller),
      ),
    );
    if (content == null || content.isEmpty) return;
    await widget.controller.api.addScheduledMessage(widget.campaignId, content);
    await _load();
  }

  Future<void> _deleteMessage(int id) async {
    await widget.controller.api.deleteScheduledMessage(widget.campaignId, id);
    await _load();
  }

  Future<void> _deleteCampaign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الجدول؟'),
        content: const Text('سيتم حذف الجدول ورسائله المحفوظة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.api.deleteScheduledCampaign(widget.campaignId);
    if (mounted) Navigator.pop(context, true);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class ScheduledContentPage extends StatefulWidget {
  const ScheduledContentPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<ScheduledContentPage> createState() => _ScheduledContentPageState();
}

class _ScheduledContentPageState extends State<ScheduledContentPage> {
  ApiMessageContent _content = const ApiMessageContent(components: []);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة رسالة للجدول')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ContentComposer(
            controller: widget.controller,
            value: _content,
            onChanged: (value) => setState(() => _content = value),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _content.isEmpty
                ? null
                : () => Navigator.pop(context, _content),
            icon: const Icon(Icons.check_rounded),
            label: const Text('اعتماد المحتوى'),
          ),
        ],
      ),
    );
  }
}

String hoursText(int seconds) {
  final hours = seconds / 3600;
  return hours == hours.roundToDouble()
      ? hours.toInt().toString()
      : hours.toStringAsFixed(2);
}

String intervalLabel(int seconds) {
  if (seconds <= 0) return '—';
  if (seconds % 86400 == 0) return 'كل ${seconds ~/ 86400} يوم';
  if (seconds % 3600 == 0) return 'كل ${seconds ~/ 3600} ساعة';
  if (seconds % 60 == 0) return 'كل ${seconds ~/ 60} دقيقة';
  return 'كل $seconds ثانية';
}

String selectionLabel(String mode) => switch (mode) {
      'shuffle' => 'عشوائي بدون تكرار',
      'random' => 'عشوائي بالكامل',
      'ordered' => 'بالترتيب',
      _ => mode,
    };

String formatDate(int? milliseconds) {
  if (milliseconds == null || milliseconds <= 0) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}
