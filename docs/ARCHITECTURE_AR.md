# معمارية التطبيق

```text
Flutter App
│
├── Project API
│   ├── Device Enrollment
│   ├── Access / Refresh tokens
│   ├── Commands
│   ├── Groups
│   ├── Approvals
│   ├── Statistics
│   ├── Settings
│   ├── WhatsApp status
│   └── SSE events
│
└── DeepSeek (مستقل)
    ├── API Key محلي آمن
    ├── Chat Completions
    ├── Streaming
    └── SQLite محلي للمحادثات
```

## فصل المسؤوليات

التطبيق لا يفتح قاعدة بيانات مشروع WhatsApp، ولا يملك Telegram Bot Token أو Baileys credentials. كل تغييرات الإدارة تمر عبر REST API ثم Project Core.

قسم DeepSeek منفصل عن Project API ولا يستطيع نشر رد من تلقاء نفسه. «استخدام كرد» يطلب اختيار الرد ثم تأكيد المستخدم قبل إرسال PATCH للمشروع.

## لا يوجد System Prompt

عميل DeepSeek يبني `messages` من رسائل `user` و`assistant` المحفوظة فقط.

## التخزين

- Access/Refresh tokens: Secure Storage.
- DeepSeek API Key: Secure Storage.
- Server URL + Theme + model preference: SharedPreferencesAsync.
- AI conversations: SQLite محلي.

## localhost

الافتراضي حاليًا `http://127.0.0.1:8787/api/v1` لأن Termux والتطبيق على نفس هاتف Android. عند النقل إلى VPS يتغير عنوان API فقط، ولا يتغير Core التطبيق.
