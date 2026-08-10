# WhatsApp Group Responder — Android App

تطبيق Android شخصي مبني بـ Flutter لإدارة مشروع **WhatsApp Group Responder** عبر REST API v1.

## المرحلة الأولى

- ربط الجهاز عبر API ثم الموافقة من Telegram.
- حفظ Access/Refresh tokens في Secure Storage.
- تجديد جلسة API تلقائيًا.
- لوحة رئيسية.
- إدارة الردود والمجموعات والموافقات والإحصائيات.
- حالة WhatsApp والإعدادات.
- قسم محادثة DeepSeek مستقل بدون System Prompt داخلي.
- Streaming لإجابات DeepSeek.
- نسخ سريع واستخدام إجابة AI كنص رد بعد اختيار الرد والتأكيد.
- تخزين محادثات AI محليًا في SQLite.
- SSE للأحداث الحية.
- RTL عربي وMaterial 3.

## اتصال Termux المحلي

القيمة الافتراضية:

```text
http://127.0.0.1:8787/api/v1
```

## التشغيل محليًا

```bash
flutter pub get
bash tool/bootstrap_android.sh
flutter run
```

`bootstrap_android.sh` ينشئ منصة Android باستخدام Flutter Stable المثبت محليًا بدل تثبيت ملفات Gradle قديمة داخل المستودع.

## GitHub Actions

Workflow في `.github/workflows/android.yml` يشغّل التحليل والاختبارات ويبني Debug APK ويرفعه كـ artifact.

## DeepSeek

لا يوجد System Prompt مخفي. التطبيق يرسل فقط رسائل `user` و`assistant` الموجودة في المحادثة.

النماذج:
- `deepseek-v4-pro`
- `deepseek-v4-flash`
