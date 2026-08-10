import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AiConversation {
  AiConversation({required this.id, required this.title, required this.updatedAt});
  final int id;
  final String title;
  final int updatedAt;
}

class AiMessage {
  AiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
  });
  final int id;
  final int conversationId;
  final String role;
  final String content;
  final int createdAt;
}

class AiRepository {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'whatsapp_responder_ai.sqlite3');
    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE conversations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id INTEGER NOT NULL,
            role TEXT NOT NULL CHECK(role IN ('user','assistant')),
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_conversation ON messages(conversation_id, id)',
        );
      },
    );
    return _db!;
  }

  Future<List<AiConversation>> listConversations() async {
    final db = await database;
    final rows = await db.query('conversations', orderBy: 'updated_at DESC');
    return rows
        .map((row) => AiConversation(
              id: row['id'] as int,
              title: row['title'] as String,
              updatedAt: row['updated_at'] as int,
            ))
        .toList();
  }

  Future<int> createConversation({String title = 'محادثة جديدة'}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('conversations', {
      'title': title,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> renameConversation(int id, String title) async {
    final db = await database;
    await db.update(
      'conversations',
      {'title': title.trim(), 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteConversation(int id) async {
    final db = await database;
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AiMessage>> messages(int conversationId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'id ASC',
    );
    return rows
        .map((row) => AiMessage(
              id: row['id'] as int,
              conversationId: row['conversation_id'] as int,
              role: row['role'] as String,
              content: row['content'] as String,
              createdAt: row['created_at'] as int,
            ))
        .toList();
  }

  Future<void> addMessage(int conversationId, String role, String content) async {
    if (role != 'user' && role != 'assistant') {
      throw ArgumentError.value(role, 'role');
    }
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('messages', {
        'conversation_id': conversationId,
        'role': role,
        'content': content,
        'created_at': now,
      });
      await txn.update(
        'conversations',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [conversationId],
      );
    });
  }
}
