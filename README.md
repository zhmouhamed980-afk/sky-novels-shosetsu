# سماء الروايات — Shosetsu Extension

مستودع Shosetsu لتطبيق **سماء الروايات** يتيح لك قراءة الروايات مباشرة من التطبيق.

---

## إضافة المستودع إلى Shosetsu

1. افتح Shosetsu → **More (...)** → **Repositories**
2. اضغط زر **+**
3. أدخل الاسم: `سماء الروايات`
4. أدخل الرابط:
   ```
   https://raw.githubusercontent.com/zhmouhamed980-afk/sky-novels-shosetsu/main/
   ```
5. اضغط **OK** ثم حدّث القائمة
6. اذهب إلى **Browse** → ابحث عن `سماء الروايات` → ثبّته

---

## الميزات

| الميزة | الحالة |
|--------|--------|
| تصفح جميع الروايات (مع pagination) | ✅ |
| تصفية: مترجمة / مؤلفة | ✅ |
| تفاصيل الرواية (وصف، تاجز، حالة، فصول) | ✅ |
| قراءة الفصول | ✅ |
| البحث | ✅ |

---

## هيكل المستودع

```
sky-novels-shosetsu/
├── index.json          ← فهرس المستودع (يقرأه Shosetsu)
├── src/
│   └── ar/
│       └── SkyNovels.lua   ← الـ extension
├── icons/
│   └── SkyNovels.png   ← أيقونة المصدر
└── README.md
```
