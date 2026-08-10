import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_controller.dart';
import '../../core/models.dart';
import 'ai_repository.dart';
import 'deepseek_client.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _repo = AiRepository();
  final _deepSeek = DeepSeekClient();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<AiConversation> _conversations = [];
  List<AiMessage> _messages = [];
  int? _conversationId;
  bool _sending = false;
  String _streaming = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _deepSeek.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final list = await _repo.listConversations();
    if (!mounted) return;
    setState(() => _conversations = list);
    if (_conversationId == null && list.isNotEmpty) {
      await _openConversation(list.first.id);
    }
  }

  Future<void> _newConversation() async {
    final id = await _repo.createConversation();
    await _loadConversations();
    await _openConversation(id);
  }

  Future<void> _openConversation(int id) async {
    final messages = await _repo.messages(id);
    if (!mounted) return;
    setState(() {
      _conversationId = id;
      _messages = messages;
      _streaming = '';
      _error = null;
    });
    _jumpBottom();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    final key = await widget.controller.secureStore.deepSeekApiKey;
    if (key == null || key.isEmpty) {
      if (mounted) {
        setState(
          () => _error = 'أضف DeepSeek API Key من الإعدادات أولًا.',
        );
      }
      return;
    }

    var id = _conversationId;
    if (id == null) {
      id = await _repo.createConversation(title: _titleFrom(text));
      _conversationId = id;
    }
    final firstMessage = _messages.isEmpty;
    await _repo.addMessage(id, 'user', text);
    if (firstMessage) await _repo.renameConversation(id, _titleFrom(text));
    _input.clear();
    _messages = await _repo.messages(id);

    final model = await widget.controller.preferences.getDeepSeekModel();
    final thinking =
        await widget.controller.preferences.getDeepSeekThinking();
    if (!mounted) return;
    setState(() {
      _sending = true;
      _streaming = '';
      _error = null;
    });
    _jumpBottom();

    try {
      await for (final chunk in _deepSeek.streamChat(
        apiKey: key,
        model: model,
        thinking: thinking,
        messages: _messages,
      )) {
        if (!mounted) return;
        setState(() => _streaming += chunk);
        _jumpBottom();
      }
      final answer = _streaming.trim();
      if (answer.isNotEmpty) {
        await _repo.addMessage(id, 'assistant', answer);
      }
      _messages = await _repo.messages(id);
      await _loadConversations();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _streaming = '';
        });
        _jumpBottom();
      }
    }
  }

  String _titleFrom(String text) =>
      text.length > 35 ? '${text.substring(0, 35)}…' : text;

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showConversations() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Column(
        children: [
          ListTile(
            title: const Text(
              'المحادثات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _newConversation();
              },
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (_, index) {
                final item = _conversations[index];
                return ListTile(
                  selected: item.id == _conversationId,
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openConversation(item.id);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await _repo.deleteConversation(item.id);
                      if (_conversationId == item.id) {
                        _conversationId = null;
                        _messages = [];
                      }
                      await _loadConversations();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _useAsReply(String text) async {
    if (widget.controller.commands.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد ردود لاختيارها.')),
        );
      }
      return;
    }

    final selected = await showDialog<ApiCommand>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('استخدام النص كرد'),
        children: widget.controller.commands
            .map(
              (command) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, command),
                child: Text(command.title),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('استخدام النص في "${selected.title}"؟'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.controller.api.updateCommand(
      selected.id,
      {'responseText': text},
    );
    await widget.controller.refreshCommands();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الرد بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = <AiMessage>[
      ..._messages,
      if (_streaming.isNotEmpty)
        AiMessage(
          id: -1,
          conversationId: _conversationId ?? 0,
          role: 'assistant',
          content: _streaming,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الذكاء الاصطناعي'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _newConversation,
            icon: const Icon(Icons.add_comment_rounded),
          ),
          IconButton(
            onPressed: _showConversations,
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 42,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'ابدأ محادثة جديدة',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'اكتب رسالتك أو اطلب إعادة صياغة أي نص.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final message = visible[index];
                      final assistant = message.role == 'assistant';
                      return Align(
                        alignment: assistant
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 680),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          decoration: BoxDecoration(
                            color: assistant
                                ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh
                                : Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SelectableText(message.content),
                              if (assistant && message.content.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      tooltip: 'نسخ',
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: message.content),
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('تم النسخ'),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 19,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'استخدام كرد',
                                      onPressed: _sending
                                          ? null
                                          : () => _useAsReply(message.content),
                                      icon: const Icon(
                                        Icons.quickreply_rounded,
                                        size: 19,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
