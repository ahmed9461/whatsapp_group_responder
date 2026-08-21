import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/approval_timeout.dart';
import '../ai/deepseek_client.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _deepSeekKey = TextEditingController();
  String _model = 'deepseek-v4-pro';
  bool _thinking = false;
  bool _loadingAi = true;
  bool _testing = false;
  bool _showKey = false;
  bool _savingApprovalTimeout = false;

  @override
  void initState() {
    super.initState();
    _loadAi();
  }

  Future<void> _loadAi() async {
    _deepSeekKey.text = await widget.controller.secureStore.deepSeekApiKey ?? '';
    _model = await widget.controller.preferences.getDeepSeekModel();
    _thinking = await widget.controller.preferences.getDeepSeekThinking();
    if (mounted) setState(() => _loadingAi = false);
  }

  @override
  void dispose() {
    _deepSeekKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maintenance = widget.controller.settings['maintenanceMode'] == true;
    final approvalTimeout =
        int.tryParse('${widget.controller.settings['approvalTimeoutSeconds'] ?? 30}') ??
            30;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الإعدادات'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('المشروع', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.cloud_done_rounded),
                    ),
                    title: const Text('الاتصال بالخدمة'),
                    subtitle: const Text(
                      'تلقائي وآمن. لا يحتاج المستخدم لإدخال عنوان API أو إعداد Tailscale.',
                    ),
                    trailing: const Icon(Icons.lock_rounded),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('وضع الصيانة'),
                    subtitle: const Text('يبقي الاتصال قائمًا ويوقف ردود المجموعات'),
                    value: maintenance,
                    onChanged: (value) async {
                      await widget.controller.api.setMaintenance(value);
                      await widget.controller.refreshAll();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('الموافقات', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.timer_outlined),
                    ),
                    title: const Text('مدة انتظار قرار الموافقة'),
                    subtitle: const Text(
                      'تطبق على طلبات الانضمام الجديدة. الطلبات المفتوحة تحتفظ بمدتها الحالية.',
                    ),
                    trailing: _savingApprovalTimeout
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.3),
                          )
                        : Text(
                            formatApprovalTimeout(approvalTimeout),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _timeoutChip(30, '30 ثانية', approvalTimeout),
                      _timeoutChip(60, 'دقيقة', approvalTimeout),
                      _timeoutChip(300, '5 دقائق', approvalTimeout),
                      _timeoutChip(600, '10 دقائق', approvalTimeout),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        _savingApprovalTimeout ? null : _showCustomApprovalTimeout,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('إدخال مدة مخصصة'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'القيمة المسموحة من 5 ثوانٍ إلى 24 ساعة. أمثلة: 45، 2m، 10 دقائق، 1h.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('المظهر', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<ThemeMode>(
                initialValue: widget.controller.themeMode,
                decoration: const InputDecoration(labelText: 'وضع المظهر'),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('حسب النظام'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('فاتح'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('داكن'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) widget.controller.setThemeMode(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('DeepSeek', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loadingAi
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        TextField(
                          controller: _deepSeekKey,
                          obscureText: !_showKey,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'DeepSeek API Key',
                            hintText: 'sk-...',
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _showKey = !_showKey),
                              icon: Icon(
                                _showKey
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _model,
                          decoration: const InputDecoration(labelText: 'النموذج'),
                          items: const [
                            DropdownMenuItem(
                              value: 'deepseek-v4-pro',
                              child: Text('V4 Pro'),
                            ),
                            DropdownMenuItem(
                              value: 'deepseek-v4-flash',
                              child: Text('V4 Flash'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _model = value ?? _model),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Thinking mode'),
                          value: _thinking,
                          onChanged: (value) =>
                              setState(() => _thinking = value),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _testing ? null : _testDeepSeek,
                                icon: const Icon(Icons.science_rounded),
                                label: Text(
                                  _testing ? 'جاري الاختبار...' : 'اختبار الاتصال',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _saveAi,
                                icon: const Icon(Icons.save_rounded),
                                label: const Text('حفظ'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: widget.controller.unlinkLocal,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('إلغاء ربط التطبيق محليًا'),
          ),
        ],
      ),
    );
  }

  Widget _timeoutChip(int seconds, String label, int current) {
    return ChoiceChip(
      label: Text(label),
      selected: current == seconds,
      onSelected: _savingApprovalTimeout
          ? null
          : (_) => _setApprovalTimeout(seconds),
    );
  }

  Future<void> _showCustomApprovalTimeout() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مدة موافقة مخصصة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: const InputDecoration(
            labelText: 'المدة',
            hintText: 'مثال: 45 أو 2m أو 10 دقائق أو 1h',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;

    final seconds = parseApprovalTimeoutInput(value);
    if (seconds == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('المدة غير صحيحة. استخدم قيمة بين 5 ثوانٍ و24 ساعة.'),
          ),
        );
      }
      return;
    }
    await _setApprovalTimeout(seconds);
  }

  Future<void> _setApprovalTimeout(int seconds) async {
    if (_savingApprovalTimeout) return;
    setState(() => _savingApprovalTimeout = true);
    try {
      await widget.controller.api.setApprovalTimeoutSeconds(seconds);
      await widget.controller.refreshAll(silent: true);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم ضبط مدة الموافقة على ${formatApprovalTimeout(seconds)}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث مدة الموافقة: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingApprovalTimeout = false);
    }
  }

  Future<void> _saveAi() async {
    await widget.controller.secureStore.saveDeepSeekApiKey(_deepSeekKey.text);
    await widget.controller.preferences.setDeepSeekModel(_model);
    await widget.controller.preferences.setDeepSeekThinking(_thinking);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات DeepSeek')),
      );
    }
  }

  Future<void> _testDeepSeek() async {
    final key = _deepSeekKey.text.trim();
    if (key.isEmpty) return;
    setState(() => _testing = true);
    final client = DeepSeekClient();
    try {
      await client.testKey(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اتصال DeepSeek ناجح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      client.close();
      if (mounted) setState(() => _testing = false);
    }
  }
}
