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
  final _deviceName = TextEditingController(text: 'Android Device');
  EnrollmentResult? _request;
  Timer? _poller;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _poller?.cancel();
    _deviceName.dispose();
    super.dispose();
  }

  Future<void> _requestLink() async {
    _poller?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _request = null;
    });

    try {
      await widget.controller.api.health();
      final instance = await widget.controller.ensureDeviceInstanceId();
      final request = await widget.controller.api.createEnrollment(
        deviceName: _deviceName.text.trim().isEmpty
            ? 'Android Device'
            : _deviceName.text.trim(),
        deviceInstanceId: instance,
      );
      if (!mounted) return;
      setState(() => _request = request);
      _startPolling(request);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = switch (e.code) {
          'ENROLLMENT_WINDOW_CLOSED' =>
            'استقبال طلبات الربط مغلق. اطلب من المالك فتح الربط من Telegram ثم أعد المحاولة.',
          _ => e.message,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'تعذر الوصول إلى خدمة الربط حاليًا. تحقق من الإنترنت ثم أعد المحاولة.';
      });
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
    unawaited(_poll(request));
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
          _request = null;
          if (status == 'rejected') {
            _error = 'تم رفض طلب ربط هذا الجهاز من Telegram.';
            _notice = null;
          } else {
            _error = null;
            _notice =
                'انتهت مهلة طلب الربط. افتح الربط من Telegram ثم أرسل طلبًا جديدًا.';
          }
        });
      }
    } catch (_) {
      // A temporary mobile-network failure must not cancel a valid enrollment.
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
                              'اربط هذا الجهاز بالمشروع بموافقة المالك عبر Telegram. لا تحتاج لإدخال عنوان خادم أو تثبيت Tailscale.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            TextField(
                              controller: _deviceName,
                              decoration: const InputDecoration(
                                labelText: 'اسم الجهاز',
                                prefixIcon: Icon(Icons.phone_android_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.security_rounded, size: 21),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'بعد إرسال الطلب يختار المالك من Telegram صلاحية الجهاز والمجموعات المسموحة له. لا يتم تخزين Bot Token داخل التطبيق.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_notice != null) ...[
                              const SizedBox(height: 12),
                              _messageBox(
                                _notice!,
                                scheme.secondaryContainer,
                                scheme.onSecondaryContainer,
                                Icons.info_outline_rounded,
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              _messageBox(
                                _error!,
                                scheme.errorContainer,
                                scheme.onErrorContainer,
                                Icons.error_outline_rounded,
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
                                  : const Icon(Icons.telegram_rounded),
                              label: const Text('طلب الربط عبر Telegram'),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 58,
                              color: scheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'بانتظار موافقة المالك',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'وصل طلب الربط إلى Telegram. قارن رمز التحقق قبل الموافقة.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
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
                            const SizedBox(height: 12),
                            const Text(
                              'بعد الموافقة سيكمل التطبيق الربط تلقائيًا حسب الصلاحيات التي اختارها المالك.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () {
                                _poller?.cancel();
                                setState(() {
                                  _request = null;
                                  _error = null;
                                  _notice = null;
                                });
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

  Widget _messageBox(
    String text,
    Color background,
    Color foreground,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: foreground))),
        ],
      ),
    );
  }
}
