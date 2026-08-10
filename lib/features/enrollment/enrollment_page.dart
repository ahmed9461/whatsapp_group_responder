import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api/api_exception.dart';
import '../../core/app_controller.dart';
import '../../core/models.dart';

class EnrollmentPage extends StatefulWidget {
  const EnrollmentPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  late final TextEditingController _server;
  final _deviceName = TextEditingController(text: 'Android Device');
  EnrollmentResult? _request;
  Timer? _poller;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: widget.controller.serverUrl);
  }

  @override
  void dispose() {
    _poller?.cancel();
    _server.dispose();
    _deviceName.dispose();
    super.dispose();
  }

  Future<void> _requestLink() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.setServerUrl(_server.text);
      await widget.controller.api.health();
      final instance = await widget.controller.ensureDeviceInstanceId();
      final request = await widget.controller.api.createEnrollment(
        deviceName: _deviceName.text.trim().isEmpty
            ? 'Android Device'
            : _deviceName.text.trim(),
        deviceInstanceId: instance,
      );
      setState(() => _request = request);
      _startPolling(request);
    } on ApiException catch (e) {
      setState(() => _error = e.code == 'ENROLLMENT_WINDOW_CLOSED'
          ? 'الربط مغلق. افتحه من Telegram ثم حاول مرة أخرى.'
          : e.message);
    } catch (e) {
      setState(() => _error = 'تعذر الاتصال بالخادم: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startPolling(EnrollmentResult request) {
    _poller?.cancel();
    _poller = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _poll(request),
    );
    _poll(request);
  }

  Future<void> _poll(EnrollmentResult request) async {
    try {
      final data = await widget.controller.api.enrollmentStatus(
        request.id,
        request.enrollmentToken,
      );
      if (!mounted) return;
      final status = '${data['status']}';
      if (status == 'approved') {
        _poller?.cancel();
        final tokens = await widget.controller.api.claimEnrollment(
          request.id,
          request.enrollmentToken,
        );
        await widget.controller.completeLink(tokens);
      } else if (status == 'rejected' || status == 'expired') {
        _poller?.cancel();
        setState(() {
          _error = status == 'rejected'
              ? 'تم رفض طلب الربط من Telegram.'
              : 'انتهت مهلة طلب الربط.';
          _request = null;
        });
      }
    } catch (_) {
      // Transient polling errors are tolerated until the request expires.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _request == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.forum_rounded,
                              size: 64,
                              color: scheme.primary,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'إدارة ردود واتساب',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'اربط هذا الجهاز بالمشروع. سيصل طلب الموافقة إلى Telegram.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            TextField(
                              controller: _server,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'عنوان API',
                                hintText: 'http://127.0.0.1:8787/api/v1',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _deviceName,
                              decoration: const InputDecoration(
                                labelText: 'اسم الجهاز',
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: TextStyle(color: scheme.error),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _busy ? null : _requestLink,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.link_rounded),
                              label: const Text('طلب ربط التطبيق'),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            const Icon(Icons.hourglass_top_rounded, size: 56),
                            const SizedBox(height: 16),
                            Text(
                              'بانتظار موافقة Telegram',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'تأكد أن رمز التحقق نفسه ظاهر في Telegram.',
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              _request!.verificationCode,
                              textDirection: TextDirection.ltr,
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            const LinearProgressIndicator(),
                            const SizedBox(height: 18),
                            TextButton(
                              onPressed: () {
                                _poller?.cancel();
                                setState(() => _request = null);
                              },
                              child: const Text('إلغاء'),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
