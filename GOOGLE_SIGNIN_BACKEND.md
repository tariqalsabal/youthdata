# تعليمات تفعيل "تسجيل الدخول عبر Google" — الطرف الخلفي (Oracle APEX / ORDS)

مُحدّث بالأسماء الحقيقية لقاعدة `DATA_CENTER`:
- جدول المستخدمين: `USERS` (أعمدته بالعربية).
- جدول الجلسات: `USER_SESSIONS`.
- منطق التوكن مكتوب داخل معالجات ORDS مباشرة (لا توجد حزمة).

الهدف: إضافة نقطة نهاية واحدة `POST /account/v1/google` تعيد **نفس شكل استجابة `/login`**،
فيعمل زر Google في واجهة Next.js تلقائياً.

> لا حاجة لأي `ALTER TABLE` — نطابق بالبريد وننشئ الحساب في `USERS` مباشرة.

---

## الخطوة ١: معرّف Google (تم إنشاؤه ✅)

```
Client ID = 1004575570279-qbj6utfs4v83sh0u1fnoad2m8t8bh455.apps.googleusercontent.com
```
مضبوط في الواجهة (Vercel). ونستخدمه في الطرف الخلفي للتحقق من `aud`.
تأكّد أن ضمن **Authorized JavaScript origins**: `https://youth-data-platform.vercel.app`.

---

## الخطوة ٢: صلاحية الشبكة (ACL) للوصول إلى Google

الطرف الخلفي يتصل بـ `oauth2.googleapis.com` عبر HTTPS. امنح سكيمة التطبيق الصلاحية:

```sql
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'oauth2.googleapis.com',
    ace  => xs$ace_type(privilege_list => xs$name_list('http'),
                        principal_name => 'DATA_CENTER',        -- سكيمة التطبيق
                        principal_type => xs_acl.ptype_db));
END;
/
```
> على Autonomous Database يعمل HTTPS للنطاقات العامة دون محفظة. إن كانت الاستضافة تمنع الاتصال الخارجي، راجع القسم "بديل".
> اختياري لكن مُستحسن: عمود البريد `الايميل` حالياً `VARCHAR2(50)` — بعض بُرد Google أطول؛ يُفضّل توسيعه:
> `ALTER TABLE "USERS" MODIFY ("الايميل" VARCHAR2(320));`

---

## الخطوة ٣: نقطة النهاية الجديدة في ORDS

أنشئ Handler من نوع **PL/SQL**، الطريقة **POST**، على المسار: `account/v1/google`
(ضمن نفس الوحدة/القالب `account/v1`). Body المتوقّع: `{ "id_token": "..." }`.

الكود جاهز للّصق (بالأسماء الحقيقية):

```plsql
DECLARE
  l_id_token   VARCHAR2(4000) := :id_token;
  l_resp       CLOB;
  l_aud        VARCHAR2(4000);
  l_iss        VARCHAR2(200);
  l_email      VARCHAR2(320);
  l_email_ver  VARCHAR2(10);
  l_sub        VARCHAR2(64);
  l_name       VARCHAR2(400);
  l_picture    VARCHAR2(1000);
  l_user_id    NUMBER;
  l_username   VARCHAR2(255);
  l_utype      VARCHAR2(50);
  l_token      VARCHAR2(255);
  l_refresh    VARCHAR2(255);

  c_client_id  CONSTANT VARCHAR2(200) :=
    '1004575570279-qbj6utfs4v83sh0u1fnoad2m8t8bh455.apps.googleusercontent.com';
BEGIN
  -- (1) تحقّق من التوكن لدى Google
  l_resp := APEX_WEB_SERVICE.make_rest_request(
              p_url         => 'https://oauth2.googleapis.com/tokeninfo?id_token=' || l_id_token,
              p_http_method => 'GET');

  IF APEX_WEB_SERVICE.g_status_code <> 200 THEN
    OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');
    HTP.p('{"success":false,"error":"رمز Google غير صالح"}');
    RETURN;
  END IF;

  -- (2) استخرج الحقول
  APEX_JSON.parse(l_resp);
  l_aud       := APEX_JSON.get_varchar2(p_path => 'aud');
  l_iss       := APEX_JSON.get_varchar2(p_path => 'iss');
  l_email     := LOWER(APEX_JSON.get_varchar2(p_path => 'email'));
  l_email_ver := APEX_JSON.get_varchar2(p_path => 'email_verified');
  l_sub       := APEX_JSON.get_varchar2(p_path => 'sub');
  l_name      := APEX_JSON.get_varchar2(p_path => 'name');
  l_picture   := APEX_JSON.get_varchar2(p_path => 'picture');

  -- (3) تحقّقات الأمان (إلزامية)
  IF l_aud <> c_client_id
     OR l_iss NOT IN ('accounts.google.com','https://accounts.google.com')
     OR NVL(l_email_ver,'false') <> 'true'
     OR l_email IS NULL THEN
    OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');
    HTP.p('{"success":false,"error":"رمز Google غير موثوق"}');
    RETURN;
  END IF;

  -- (4) ابحث عن المستخدم بالبريد
  BEGIN
    SELECT "ID", "نوع_المستخدم"
    INTO   l_user_id, l_utype
    FROM   "USERS"
    WHERE  LOWER("الايميل") = l_email;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    l_user_id := NULL;
  END;

  -- (5) أنشئ الحساب إن لم يوجد
  IF l_user_id IS NULL THEN
    l_username := SUBSTR(l_email, 1, INSTR(l_email, '@') - 1);
    INSERT INTO "USERS"
      ("الايميل", "الاسم_الكامل", "صورة_الملف_الشخصي", "نوع_المستخدم",
       "اسم_المستخدم", "حالة_الحساب", "تاريخ_التسجيل")
    VALUES
      (l_email, l_name, l_picture, 'user_normal',
       l_username, 'نشط', SYSTIMESTAMP)
    RETURNING "ID" INTO l_user_id;
    l_utype := 'user_normal';
  ELSE
    UPDATE "USERS"
       SET "صورة_الملف_الشخصي" = NVL("صورة_الملف_الشخصي", l_picture),
           "آخر_تسجيل_دخول"    = SYSTIMESTAMP
     WHERE "ID" = l_user_id;
  END IF;

  -- (6) أنشئ الجلسة (نفس أسلوب /login: توكنات SYS_GUID في USER_SESSIONS)
  --     ★ إن كانت مدة الصلاحية في /login مختلفة، طابِقها هنا.
  l_token   := RAWTOHEX(SYS_GUID()) || RAWTOHEX(SYS_GUID());
  l_refresh := RAWTOHEX(SYS_GUID()) || RAWTOHEX(SYS_GUID());

  INSERT INTO "USER_SESSIONS"
    (USER_ID, TOKEN, REFRESH_TOKEN, EXPIRES_AT, REFRESH_EXPIRES_AT,
     IS_ACTIVE, CREATED_AT, LAST_USED_AT)
  VALUES
    (l_user_id, l_token, l_refresh,
     SYSTIMESTAMP + INTERVAL '30' DAY,
     SYSTIMESTAMP + INTERVAL '60' DAY,
     1, SYSTIMESTAMP, SYSTIMESTAMP);

  COMMIT;

  -- (7) استجابة بنفس شكل /login تماماً
  OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');
  APEX_JSON.initialize_clob_output;
  APEX_JSON.open_object;
    APEX_JSON.write('success', TRUE);
    APEX_JSON.open_object('session');
      APEX_JSON.write('token', l_token);
      APEX_JSON.write('refreshToken', l_refresh);
    APEX_JSON.close_object;
    APEX_JSON.open_object('user');
      APEX_JSON.write('id', l_user_id);
      APEX_JSON.write('email', l_email);
      APEX_JSON.write('fullName', l_name);
      APEX_JSON.write('userType', l_utype);
      APEX_JSON.write('avatar', l_picture);
    APEX_JSON.close_object;
  APEX_JSON.close_object;
  HTP.p(APEX_JSON.get_clob_output);
  APEX_JSON.free_output;
END;
```

> **مهم:** إن كان معالج `/login` عندكم يُخرج الاستجابة بطريقة مختلفة (مثلاً `:status_code` أو `OUT`
> parameters بدل `HTP.p`)، اتبع نفس أسلوبه في الإخراج. الأهم أن يكون **شكل JSON** مطابقاً لـ `/login`.

---

## الخطوة ٤: الاختبار

```bash
curl -X POST https://youthdata.maxapex.net/ords/data_center/account/v1/google \
  -H "Content-Type: application/json" \
  -d '{"id_token":"<GOOGLE_ID_TOKEN>"}'
```
المتوقّع: `{"success":true,"session":{...},"user":{...}}`.

---

## بديل (إن مُنع الاتصال الخارجي من قاعدة البيانات)

إن تعذّر `APEX_WEB_SERVICE` (استضافة تمنع outbound):
- الخيار أ: فكّ ترميز الـ JWT محلياً والتحقق من توقيعه (RS256) مقابل مفاتيح Google العامة — أعقد.
- الخيار ب: نقل خطوة التحقق إلى طبقة Next.js (نتحقق هناك ونمرّر البريد الموثوق) — أخبرني لأطبّقه.

الأبسط والمفضّل هو `tokeninfo` أعلاه متى توفّر ACL.

---

## قائمة تسليم المبرمج
- [ ] (اختياري) توسيع عمود `الايميل` إلى 320.
- [ ] صلاحية ACL لـ `oauth2.googleapis.com` (الخطوة ٢).
- [ ] نقطة `POST /account/v1/google` تعمل وتعيد شكل `/login` (الخطوة ٣).
- [ ] اختبار بـ curl (الخطوة ٤).
