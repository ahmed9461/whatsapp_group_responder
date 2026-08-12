import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../messaging/content_composer.dart';
import '../messaging/group_selector.dart';

class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  @override
  Widget build(BuildContext context) {
    final items = widget.controller.broadcasts
        .where((broadcast) => broadcast.kind == 'manual')
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('إرسال للمجموعات'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: widget.controller.refreshBroadcasts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('إرسال جديد'),
      ),
      body: RefreshIndicator(
        onRefresh: widget.controller.refreshBroadcasts,
        child: items.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 110),
                  Icon(Icons.campaign_outlined, size: 64),
                  SizedBox(height: 18),
                  Text(
                    'لا يوجد سجل إرسال جماعي بعد.',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'أنشئ رسالة، اختر جميع المجموعات أو مجموعات محددة، راجعها ثم أرسل.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final broadcast = items[index];
                  return Card(
                    child: ListTile(
                      onTap: () => _openReport(broadcast.id),
                      leading: CircleAvatar(
                        child: Icon(_statusIcon(broadcast.status)),
                      ),
                      title: Text(
                        'إرسال #${broadcast.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${_statusLabel(broadcast.status)} • '
                        '${broadcast.sentCount}/${broadcast.targetCount} نجح'
                        '${broadcast.failedCount > 0 ? ' • ${broadcast.failedCount} فشل' : ''}\n'
                        '${broadcast.content.summary}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'حذف سجل الإرسال',
                        onPressed: () => _deleteBroadcast(broadcast),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _compose() async {
    final broadcast = await Navigator.push<ApiBroadcast>(
      context,
      MaterialPageRoute(
        builder: (_) => BroadcastWizardPage(controller: widget.controller),
      ),
    );
    if (broadcast == null) return;

    await widget.controller.refreshBroadcasts();
    if (mounted) await _openReport(broadcast.id);
  }

  Future<void> _openReport(int id) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BroadcastReportPage(
          controller: widget.controller,
          broadcastId: id,
        ),
      ),
    );
    await widget.controller.refreshBroadcasts();
  }

  Future<void> _deleteBroadcast(ApiBroadcast broadcast) async {
    final active =
        broadcast.status == 'queued' || broadcast.status == 'running';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(active ? 'إلغاء وحذف الإرسال؟' : 'حذف سجل الإرسال؟'),
        content: Text(
          active
              ? 'الإرسال #${broadcast.id} ما زال نشطًا. سيتم إلغاء ما لم يُرسل بعد، ثم حذف السجل والتقرير. الرسائل التي وصلت مسبقًا إلى واتساب لن تُحذف.'
              : 'سيتم حذف سجل الإرسال #${broadcast.id} والتقرير من التطبيق. الرسائل التي وصلت إلى مجموعات واتساب لن تُحذف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(active ? 'إلغاء الإرسال وحذفه' : 'حذف السجل'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (active) {
        await widget.controller.api.cancelBroadcast(broadcast.id);
      }
      await widget.controller.api.postMap(
        '/broadcasts/${broadcast.id}/delete-history',
        const {},
      );
      await widget.controller.refreshBroadcasts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف سجل الإرسال.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف سجل الإرسال: $error')),
        );
      }
    }
  }
}

class BroadcastWizardPage extends StatefulWidget {
  const BroadcastWizardPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<BroadcastWizardPage> createState() => _BroadcastWizardPageState();
}

class _BroadcastWizardPageState extends State<BroadcastWizardPage> {
  ApiMessageContent _content = const ApiMessageContent(components: []);
  String _targetMode = 'all';
  Set<int> _groupIds = {};
  int _step = 0;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إرسال جديد للمجموعات')),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (value) => setState(() => _step = value),
        onStepContinue: _sending ? null : _continue,
        onStepCancel: _sending || _step == 0
            ? null
            : () => setState(() => _step--),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: details.onStepContinue,
                icon: Icon(
                  _step == 2 ? Icons.send_rounded : Icons.arrow_forward_rounded,
                ),
                label: Text(_step == 2 ? 'إرسال الآن' : 'التالي'),
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
            title: const Text('1. المحتوى'),
            isActive: _step >= 0,
            content: ContentComposer(
              controller: widget.controller,
              value: _content,
              onChanged: (value) => setState(() => _content = value),
              title: 'الرسالة التي ستصل للمجموعات',
            ),
          ),
          Step(
            title: const Text('2. المستهدفون'),
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
            title: const Text('3. المراجعة والإرسال'),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('المستهدفون'),
                  trailing: Text(
                    _targetMode == 'all'
                        ? 'جميع المجموعات المعتمدة'
                        : '${_groupIds.length} مجموعة',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'المحتوى',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(_content.summary),
                  ),
                ),
                const SizedBox(height: 10),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'سيتم الإرسال للمجموعات بشكل متسلسل عبر طابور الإرسال، وستظهر نتيجة كل مجموعة في التقرير.',
                    ),
                  ),
                ),
                if (_sending)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _continue() async {
    if (_step == 0 && _content.isEmpty) {
      _message('أضف محتوى الرسالة أولًا.');
      return;
    }
    if (_step == 1 && _targetMode == 'selected' && _groupIds.isEmpty) {
      _message('اختر مجموعة واحدة على الأقل.');
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
      return;
    }

    setState(() => _sending = true);
    try {
      final broadcast = await widget.controller.api.createBroadcast(
        content: _content,
        targetMode: _targetMode,
        groupIds: _groupIds.toList(),
      );
      if (mounted) Navigator.pop(context, broadcast);
    } catch (error) {
      _message('تعذر بدء الإرسال: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class BroadcastReportPage extends StatefulWidget {
  const BroadcastReportPage({
    super.key,
    required this.controller,
    required this.broadcastId,
  });

  final AppController controller;
  final int broadcastId;

  @override
  State<BroadcastReportPage> createState() => _BroadcastReportPageState();
}

class _BroadcastReportPageState extends State<BroadcastReportPage> {
  ApiBroadcast? _item;
  Timer? _timer;
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final status = _item?.status;
      if (status == 'queued' || status == 'running') {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      _item = await widget.controller.api.getBroadcast(widget.broadcastId);
    } catch (error) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل التقرير: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final broadcast = _item;
    return Scaffold(
      appBar: AppBar(
        title: Text('تقرير الإرسال #${widget.broadcastId}'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _deleting ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'حذف سجل الإرسال',
            onPressed: _deleting || broadcast == null ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: _loading && broadcast == null
          ? const Center(child: CircularProgressIndicator())
          : broadcast == null
              ? const Center(child: Text('تعذر العثور على الإرسال.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Icon(_statusIcon(broadcast.status), size: 48),
                            const SizedBox(height: 8),
                            Text(
                              _statusLabel(broadcast.status),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _metric(
                                    'المستهدفون',
                                    broadcast.targetCount,
                                  ),
                                ),
                                Expanded(
                                  child: _metric('تم', broadcast.sentCount),
                                ),
                                Expanded(
                                  child: _metric('فشل', broadcast.failedCount),
                                ),
                              ],
                            ),
                            if (broadcast.status == 'queued' ||
                                broadcast.status == 'running') ...[
                              const SizedBox(height: 14),
                              LinearProgressIndicator(
                                value: broadcast.targetCount == 0
                                    ? null
                                    : (broadcast.sentCount +
                                            broadcast.failedCount) /
                                        broadcast.targetCount,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'الرسالة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(broadcast.content.summary),
                      ),
                    ),
                    if (broadcast.targets.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'نتائج المجموعات',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...broadcast.targets.map(
                        (target) => Card(
                          child: ListTile(
                            leading: Icon(_statusIcon(target.status)),
                            title: Text(target.groupName),
                            subtitle: Text(
                              '${_statusLabel(target.status)} • '
                              'المحاولات: ${target.attemptCount}'
                              '${target.lastError == null ? '' : '\n${target.lastError}'}',
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_deleting) const LinearProgressIndicator(),
                    if (broadcast.retryable && !_deleting)
                      FilledButton.tonalIcon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة محاولة الفاشل فقط'),
                      ),
                    if (broadcast.cancellable && !_deleting) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _cancel,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('إلغاء ما لم يُرسل بعد'),
                      ),
                    ],
                    if (!_deleting) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('حذف سجل الإرسال'),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _metric(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    );
  }

  Future<void> _retry() async {
    await widget.controller.api.retryBroadcast(widget.broadcastId);
    await _load();
  }

  Future<void> _cancel() async {
    await widget.controller.api.cancelBroadcast(widget.broadcastId);
    await _load();
  }

  Future<void> _delete() async {
    final broadcast = _item;
    if (broadcast == null) return;

    final active =
        broadcast.status == 'queued' || broadcast.status == 'running';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(active ? 'إلغاء وحذف الإرسال؟' : 'حذف سجل الإرسال؟'),
        content: Text(
          active
              ? 'الإرسال ما زال نشطًا. سيتم إلغاء المجموعات التي لم تُرسل لها الرسالة بعد، ثم حذف السجل. الرسائل التي وصلت مسبقًا إلى واتساب لن تُحذف.'
              : 'سيتم حذف هذا السجل والتقرير من التطبيق فقط. الرسائل التي وصلت إلى مجموعات واتساب لن تُحذف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(active ? 'إلغاء الإرسال وحذفه' : 'حذف السجل'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      if (active) {
        await widget.controller.api.cancelBroadcast(widget.broadcastId);
      }
      await widget.controller.api.postMap(
        '/broadcasts/${widget.broadcastId}/delete-history',
        const {},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف سجل الإرسال: $error')),
        );
      }
    }
  }
}

IconData _statusIcon(String status) => switch (status) {
      'completed' || 'sent' => Icons.check_circle_rounded,
      'failed' => Icons.error_rounded,
      'cancelled' => Icons.cancel_rounded,
      'running' || 'sending' => Icons.sync_rounded,
      'queued' || 'pending' => Icons.schedule_rounded,
      _ => Icons.info_outline_rounded,
    };

String _statusLabel(String status) => switch (status) {
      'completed' => 'مكتمل',
      'sent' => 'تم الإرسال',
      'failed' => 'فشل',
      'cancelled' => 'ملغي',
      'running' || 'sending' => 'جاري الإرسال',
      'queued' => 'في الطابور',
      'pending' => 'بانتظار الإرسال',
      _ => status,
    };
