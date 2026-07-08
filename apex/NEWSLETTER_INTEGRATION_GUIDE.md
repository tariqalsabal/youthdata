# دليل إضافة الاشتراك في النشرة إلى أي موقع

نقطة واحدة عامة تكفي — تعمل من أي موقع (المستخدم مسجّل أو زائر).

## نقطة الـ API
```
POST https://youthdata.maxapex.net/ords/data_center/account/v1/newsletter/subscribe
```
الحقول (أحدهما على الأقل: `email`):
| الحقل | إلزامي | الوصف |
|---|---|---|
| `email` | نعم | بريد المشترك |
| `name`  | لا  | الاسم (اختياري) |

الاستجابة:
```json
{ "success": true,  "message": "تم الاشتراك في النشرة بنجاح" }
{ "success": false, "error":   "البريد الإلكتروني غير صحيح" }
```

> النقطة تُرسل ترويسة CORS، وباستخدام `application/x-www-form-urlencoded` **لا يحدث طلب preflight** — فتعمل مباشرة من المتصفح على أي نطاق.

---

## 1) HTML + JavaScript خام (انسخ والصق)

```html
<form id="ydNews" style="display:flex;gap:8px;max-width:420px">
  <input id="ydEmail" type="email" placeholder="بريدك الإلكتروني" required
         style="flex:1;padding:10px;border:1px solid #cbd5e1;border-radius:10px">
  <button type="submit" style="background:#1e2a52;color:#fff;border:0;border-radius:10px;padding:10px 18px">اشترك</button>
</form>
<p id="ydMsg" style="font-size:13px;margin-top:8px"></p>

<script>
document.getElementById('ydNews').addEventListener('submit', function (e) {
  e.preventDefault();
  var email = document.getElementById('ydEmail').value;
  var msg = document.getElementById('ydMsg');
  msg.textContent = 'جارٍ الاشتراك…';
  fetch('https://youthdata.maxapex.net/ords/data_center/account/v1/newsletter/subscribe', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'email=' + encodeURIComponent(email)
  })
  .then(function (r) { return r.json(); })
  .then(function (d) {
    msg.style.color = d.success ? '#166534' : '#b91c1c';
    msg.textContent = d.message || d.error || '';
    if (d.success) document.getElementById('ydEmail').value = '';
  })
  .catch(function () { msg.style.color = '#b91c1c'; msg.textContent = 'تعذّر الاتصال، حاول لاحقاً.'; });
});
</script>
```

## 2) React / Next.js

```jsx
async function subscribe(email) {
  const res = await fetch(
    'https://youthdata.maxapex.net/ords/data_center/account/v1/newsletter/subscribe',
    { method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ email }) }
  );
  return res.json(); // { success, message }
}
```

## 3) مع الاسم أيضاً
```js
body: new URLSearchParams({ email, name })   // أو  'email=..&name=..'
```

---

## ملاحظات للمبرمج
- **لا مفاتيح ولا مصادقة** مطلوبة للاشتراك — النقطة عامة.
- إلغاء الاشتراك يتم تلقائياً عبر الرابط الموجود أسفل كل رسالة نشرة (لا حاجة لبنائه).
- التكرار آمن: إعادة إدخال بريد مشترك تُعيد تفعيله ولا تُنشئ تكراراً.
- لتقييد النطاقات المسموح لها بدل `*`، عدّل ترويسة `Access-Control-Allow-Origin`
  في معالج الاشتراك إلى نطاقك (في ملف `NEWSLETTER_ENDPOINTS.sql`).
- داخل منصة Next.js الرسمية نستخدم البروكسي الداخلي `/api/account/newsletter/subscribe`
  (مكوّن `NewsletterForm.tsx`) — لا حاجة لهذه القصاصة هناك.
