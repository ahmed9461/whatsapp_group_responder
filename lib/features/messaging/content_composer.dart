import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';

class ContentComposer extends StatefulWidget {
  const ContentComposer({
    super.key,
    required this.controller,
    required this.value,
    required this.onChanged,
    this.title = 'المحتوى',
  });

  final AppController controller;
  final ApiMessageContent value;
  final ValueChanged<ApiMessageContent> onChanged;
  final String title;

  @override
  State<ContentComposer> createState() => _ContentComposerState();
}

class _ContentComposerState extends State<ContentComposer> {
  late List<ApiContentComponent> _items;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _items = [...widget.value.components];
  }

  void _emit() {
    widget.onChanged(ApiMessageContent(components: List.unmodifiable(_items)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Text('${_items.length}/20'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'أضف النصوص والوسائط بالترتيب الذي تريد أن تصل به. يمكن إضافة أكثر من صورة أو مقطع.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _addButton(Icons.text_fields_rounded, 'نص', _addText),
            _addButton(
              Icons.image_rounded,
              'صورة',
              () => _addMedia('image'),
            ),
            _addButton(
              Icons.videocam_rounded,
              'فيديو',
              () => _addMedia('video'),
            ),
            _addButton(
              Icons.audio_file_rounded,
              'صوت',
              () => _addMedia('audio'),
            ),
            _addButton(
              Icons.mic_rounded,
              'رسالة صوتية',
              () => _addMedia('voice'),
            ),
          ],
        ),
        if (_uploading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          const Text('جاري رفع الوسائط إلى السيرفر…'),
        ],
        const SizedBox(height: 12),
        if (_items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'لم تتم إضافة محتوى بعد.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...List.generate(_items.length, _componentCard),
      ],
    );
  }

  Widget _addButton(IconData icon, String label, VoidCallback action) {
    return FilledButton.tonalIcon(
      onPressed: _uploading || _items.length >= 20 ? null : action,
      icon: Icon(icon, size: 19),
      label: Text(label),
    );
  }

  Widget _componentCard(int index) {
    final item = _items[index];
    final title = switch (item.type) {
      'text' => 'نص',
      'image' => 'صورة',
      'video' => 'فيديو',
      'audio' => 'ملف صوتي',
      'voice' => 'رسالة صوتية',
      _ => item.type,
    };
    final icon = switch (item.type) {
      'text' => Icons.text_fields_rounded,
      'image' => Icons.image_rounded,
      'video' => Icons.videocam_rounded,
      'audio' => Icons.audio_file_rounded,
      'voice' => Icons.mic_rounded,
      _ => Icons.attachment_rounded,
    };
    final subtitle = item.type == 'text'
        ? item.text ?? ''
        : [
            item.asset?.originalName ?? 'ملف محفوظ #${item.assetId}',
            if (item.caption?.trim().isNotEmpty == true) item.caption!,
          ].join('\n');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title • ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'للأعلى',
                      onPressed: index == 0 ? null : () => _move(index, -1),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      tooltip: 'للأسفل',
                      onPressed: index == _items.length - 1
                          ? null
                          : () => _move(index, 1),
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'تعديل',
                      onPressed: () => _edit(index),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => _remove(index),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _move(int index, int delta) {
    final item = _items.removeAt(index);
    _items.insert(index + delta, item);
    _emit();
  }

  Future<void> _addText() async {
    final controller = TextEditingController();
    final text = await _textDialog(
      title: 'إضافة نص',
      controller: controller,
      label: 'النص',
      maxLength: 3500,
    );
    if (text == null || text.trim().isEmpty) return;
    _items.add(ApiContentComponent(type: 'text', text: text));
    _emit();
  }

  Future<void> _edit(int index) async {
    final item = _items[index];
    if (item.type == 'text') {
      final controller = TextEditingController(text: item.text);
      final text = await _textDialog(
        title: 'تعديل النص',
        controller: controller,
        label: 'النص',
        maxLength: 3500,
      );
      if (text == null || text.trim().isEmpty) return;
      _items[index] = ApiContentComponent(type: 'text', text: text);
      _emit();
      return;
    }

    final controller = TextEditingController(text: item.caption ?? '');
    final isAudio = item.type == 'audio' || item.type == 'voice';
    final caption = await _textDialog(
      title: isAudio ? 'وصف بعد الصوت' : 'الوصف',
      controller: controller,
      label: isAudio
          ? 'وصف اختياري يرسل بعد الصوت'
          : 'وصف اختياري',
      maxLength: item.type == 'image' || item.type == 'video' ? 1024 : 3500,
      allowEmpty: true,
    );
    if (caption == null) return;
    _items[index] = item.copyWith(caption: caption);
    _emit();
  }

  Future<void> _remove(int index) async {
    final item = _items.removeAt(index);
    _emit();
    if (item.assetId == null) return;
    try {
      await widget.controller.api.deleteMedia(item.assetId!);
    } catch (_) {
      // Existing assets can still be referenced by the saved server object.
    }
  }

  Future<void> _addMedia(String componentType) async {
    final kind = componentType == 'voice' ? 'audio' : componentType;
    final extensions = switch (kind) {
      'image' => const ['jpg', 'jpeg', 'png', 'webp'],
      'video' => const ['mp4', 'mov'],
      _ => const ['ogg', 'mp3', 'm4a', 'aac', 'wav'],
    };
    final mimeTypes = switch (kind) {
      'image' => const ['image/jpeg', 'image/png', 'image/webp'],
      'video' => const ['video/mp4', 'video/quicktime'],
      _ => const [
          'audio/ogg',
          'audio/mpeg',
          'audio/mp4',
          'audio/aac',
          'audio/wav',
        ],
    };

    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: componentType == 'voice' ? 'voice' : kind,
          extensions: extensions,
          mimeTypes: mimeTypes,
        ),
      ],
    );
    if (file == null) return;

    try {
      setState(() => _uploading = true);
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('الملف المحدد فارغ');
      }
      final asset = await widget.controller.api.uploadMedia(
        bytes: bytes,
        kind: kind,
        mimeType: _mimeFor(file.name),
        fileName: _safeHeaderFileName(file.name),
      );
      if (!mounted) return;

      final controller = TextEditingController();
      final isAudio = componentType == 'audio' || componentType == 'voice';
      final caption = await _textDialog(
        title: isAudio ? 'وصف اختياري للصوت' : 'وصف اختياري',
        controller: controller,
        label: isAudio
            ? 'يرسل الوصف كنص بعد الصوت'
            : 'الوصف',
        maxLength: componentType == 'image' || componentType == 'video'
            ? 1024
            : 3500,
        allowEmpty: true,
      );
      if (caption == null) {
        try {
          await widget.controller.api.deleteMedia(asset.id);
        } catch (_) {
          // The unused media cleanup job remains a safe fallback.
        }
        return;
      }

      _items.add(
        ApiContentComponent(
          type: componentType,
          assetId: asset.id,
          caption: caption,
          asset: asset,
        ),
      );
      _emit();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر رفع الوسائط: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _mimeFor(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'ogg' => 'audio/ogg',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      _ => 'application/octet-stream',
    };
  }

  String _safeHeaderFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (sanitized.isEmpty) return 'media';
    if (sanitized.length <= 120) return sanitized;
    return sanitized.substring(sanitized.length - 120);
  }

  Future<String?> _textDialog({
    required String title,
    required TextEditingController controller,
    required String label,
    required int maxLength,
    bool allowEmpty = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 8,
          maxLength: maxLength,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (!allowEmpty && controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text);
            },
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );
  }
}
