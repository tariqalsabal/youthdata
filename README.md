# منصة بيانات الشباب — Youth Data Platform (Frontend)

موقع **Next.js 15 (App Router + TypeScript + Tailwind CSS v4)** للتسجيل وإنشاء الحساب وتسجيل الدخول،
يتصل بـ **Oracle ORDS API** الموثّق في `Youth-Data-API-Documentation.pdf`.

## المزايا

- ✅ إنشاء حساب (`POST /register`) مع تحقّق فوري من توفّر البريد/اسم المستخدم (`GET /check/...` مع debounce ٥٠٠ms).
- ✅ تسجيل الدخول (`POST /login`) بالبريد أو اسم المستخدم أو الجوال.
- ✅ لوحة محمية تعرض بيانات المستخدم (`GET /me`) + تسجيل خروج (`POST /logout`).
- ✅ استعادة كلمة المرور (`POST /forgot-password` ثم `POST /reset-password`).
- ✅ تجديد التوكن تلقائياً عند انتهاء الصلاحية (`POST /refresh`) عبر interceptor للحالة 401.
- ✅ حماية المسارات `/dashboard` `/profile` `/settings` عبر `middleware.ts`.
- ✅ واجهة عربية RTL بخط Cairo.

## الإعداد المحلي

> يتطلب تثبيت **Node.js 18.18+** (غير مثبّت حالياً على الجهاز). نزّله من https://nodejs.org

```bash
# 1) انسخ متغيرات البيئة
cp .env.example .env

# 2) ثبّت الاعتماديات
npm install

# 3) شغّل خادم التطوير
npm run dev
# افتح http://localhost:3000
```

## متغيرات البيئة

| المتغير | الوصف | الافتراضي |
|---|---|---|
| `NEXT_PUBLIC_AUTH_API` | رابط API الحسابات | `https://youthdata.maxapex.net/ords/data_center/account/v1` |
| `NEXT_PUBLIC_CMS_API` | رابط CMS (اختياري) | `https://youthdata.maxapex.net/ords/data_center/auth/cms` |

## النشر على Vercel

1. ارفع المجلد إلى مستودع GitHub:
   ```bash
   git init && git add . && git commit -m "Youth Data Platform frontend"
   git branch -M main
   git remote add origin <your-repo-url>
   git push -u origin main
   ```
2. على https://vercel.com → **Add New Project** → اختر المستودع.
3. Vercel سيكتشف Next.js تلقائياً (Build: `next build`).
4. أضف متغيرات البيئة من جدول الأعلى في **Settings → Environment Variables** (اختياري — توجد قيم افتراضية).
5. **Deploy**.

## هيكل المشروع

```
app/
  layout.tsx            # التخطيط الجذري (RTL + خط Cairo)
  page.tsx              # الصفحة الرئيسية
  register/page.tsx     # إنشاء حساب
  login/page.tsx        # تسجيل الدخول
  forgot-password/page.tsx
  dashboard/page.tsx    # لوحة محمية (GET /me)
lib/
  auth.ts               # عميل المصادقة (كل endpoints)
components/
  ui.tsx                # عناصر واجهة مشتركة
middleware.ts           # حماية المسارات
```

## ملاحظة أمنية

التوثيق يوصي باستخدام **httpOnly cookies** بدل `localStorage` للتوكن في الإنتاج.
هذا المشروع يخزّن التوكن في `localStorage` (ليقرأه عميل الـ API في المتصفح) وينسخه أيضاً إلى cookie
عادية كي يعمل الـ middleware. للأمان الأعلى، انقل تخزين التوكن إلى httpOnly cookie عبر Route Handler خادمي.
