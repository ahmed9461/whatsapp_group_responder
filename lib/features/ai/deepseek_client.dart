import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_repository.dart';

class DeepSeekClient {
  DeepSeekClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Stream<String> streamChat({
    required String apiKey,
    required String model,
    required bool thinking,
    required List<AiMessage> messages,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('https://api.deepseek.com/chat/completions'),
    )
      ..headers.addAll({
        'authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
        'accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'model': model,
        'messages': messages
            .where((m) => m.role == 'user' || m.role == 'assistant')
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
        'stream': true,
        'thinking': {'type': thinking ? 'enabled' : 'disabled'},
      });

    final response = await _client.send(request).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      final raw = await response.stream.bytesToString();
      throw Exception('DeepSeek HTTP ${response.statusCode}: $raw');
    }

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      final decoded = jsonDecode(payload);
      if (decoded is! Map) continue;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) continue;
      final delta = (choices.first as Map)['delta'];
      if (delta is! Map) continue;
      final content = delta['content'];
      if (content is String && content.isNotEmpty) yield content;
    }
  }

  Future<void> testKey(String apiKey) async {
    final response = await _client.get(
      Uri.parse('https://api.deepseek.com/user/balance'),
      headers: {'authorization': 'Bearer $apiKey'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('فشل الاتصال بـ DeepSeek (${response.statusCode})');
    }
  }

  void close() => _client.close();
}
