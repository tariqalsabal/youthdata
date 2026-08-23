# منظومة الاستبيانات — دليل التركيب

المنظومة كاملة: البناء والاعتماد في APEX، والتشغيل والتحليلات في Next.js.
واجهة المنصة **منشورة بالفعل** — يتبقّى تركيب الطرف الخلفي في APEX.

## ترتيب التشغيل في SQL Workshop

| # | الملف | الأداة | الغرض |
|---|---|---|---|
| 1 | `SURVEYS_SCHEMA.sql` | SQL Scripts | 6 جداول + استبيان تجريبي جاهز |
| 2 | `SURVEYS_ENDPOINTS.sql` | SQL Commands | قائمة/تعريف/إرسال (+تسجيل صامت) |
| 3 | `SURVEYS_ANALYTICS_ENDPOINT.sql` | SQL Commands | تجميع التحليلات المنشورة |

بعد الخطوات الثلاث: **الاستبيان التجريبي «أولويات الشباب» يظهر فوراً** في:
- الصفحة الرئيسية (قسم الاستبيانات) · `youthdata.sa/surveys` · `youthdata.sa/surveys/analytics`

## شاشة الإدارة في APEX (البناء والاعتماد)
أنشئ صفحة «إدارة الاستبيانات»:
1. **Region نوع Static Content** → الصق كامل `SURVEY_ADMIN_REGION.html` (Escape special characters = Off).
2. **Ajax Callback Process** باسم `SURVEY_ADMIN` → الصق كامل `SURVEY_ADMIN_PROCESS.sql`.

## دورة حياة الاستبيان
```
مسودة ──(المنشئ: إرسال للاعتماد)──▶ بانتظار الاعتماد
       ◀──(المدير: رفض + سبب)──┘
بانتظار الاعتماد ──(المدير: اعتماد)──▶ معتمد ──(نشر)──▶ منشور
منشور: يظهر في المنصة · يُفعّل «الرئيسية» و«التحليلات» بضغطة
```

## أنواع الأسئلة (13)
اختيار واحد/متعدد · قائمة منسدلة · نص قصير/طويل · رقم · تاريخ · تقييم نجوم ·
مقياس خطي · شبكة · نعم/لا · بريد · هاتف — مع **منطق شرطي** (أظهر سؤالاً بناءً على إجابة آخر).

## الملفات
| الطبقة | الملفات |
|---|---|
| قاعدة البيانات | `SURVEYS_SCHEMA.sql` |
| خدمات ORDS | `SURVEYS_ENDPOINTS.sql` · `SURVEYS_ANALYTICS_ENDPOINT.sql` |
| إدارة APEX | `SURVEY_ADMIN_PROCESS.sql` · `SURVEY_ADMIN_REGION.html` |
| واجهة المنصة (منشورة) | `src/lib/surveys.ts` · `src/app/api/surveys/*` · `src/components/uiApp/surveys/SurveyRunner.tsx` · `src/app/(with-layout)/surveys/*` · `SurveysSection.tsx` |
