import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../ai/deepseek_client.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _server;
  final _deepSeekKey = TextEditingController();
  String _model = 'deepseek-v4-pro';
  bool _thinking = false;
  bool _loadingAi = true;
  bool _testing = false;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: widget.controller.serverUrl);
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
    _server.dispose();
    _deepSeekKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maintenance = widget.controller.settings['maintenanceMode'] == true;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('الإعدادات'), backgroundColor: Colors.transparent),
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
                  TextField(
                    controller: _server,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'عنوان API'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () async {
                      await widget.controller.setServerUrl(_server.text);
                      await widget.controller.refreshAll();
                    },
                    child: const Text('حفظ واختبار الاتصال'),
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
          Text('المظهر', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<ThemeMode>(
                initialValue: widget.controller.themeMode,
                decoration: const InputDecoration(labelText: 'وضع المظهر'),
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('حسب النظام')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('فاتح')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('داكن')),
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
                              onPressed: () => setState(() => _showKey = !_showKey),
                              icon: Icon(_showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _model,
                          decoration: const InputDecoration(labelText: 'النموذج'),
                          items: const [
                            DropdownMenuItem(value: 'deepseek-v4-pro', child: Text('V4 Pro')),
                            DropdownMenuItem(value: 'deepseek-v4-flash', child: Text('V4 Flash')),
                          ],
                          onChanged: (value) => setState(() => _model = value ?? _model),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Thinking mode'),
                          value: _thinking,
                          onChanged: (value) => setState(() => _thinking = value),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _testing ? null : _testDeepSeek,
                                icon: const Icon(Icons.science_rounded),
                                label: Text(_testing ? 'جاري الاختبار...' : 'اختبار الاتصال'),
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
                        const SizedBox(height: 8),
                        const Text(
                          'لا يوجد System Prompt داخلي. المحادثة ترسل رسائلك وسجل user/assistant فقط.',
                          style: TextStyle(fontSize: 12),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      client.close();
      if (mounted) setState(() => _testing = false);
    }
  }
}
