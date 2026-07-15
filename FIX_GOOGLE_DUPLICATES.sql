-- ============================================================
-- حل جذري لمشكلة تكرار حسابات البريد + خطأ ORA-01422 عند دخول Google
--   1) نقل جلسات المكرّرات إلى الحساب الأقدم
--   2) حذف الحسابات المكرّرة (نُبقي أقدم ID لكل بريد)
--   3) قيد فريد يمنع أي تكرار مستقبلاً
--   4) تحديث معالج /google ليأخذ حساباً واحداً دائماً (لا ينشئ جديداً إن وُجد)
-- شغّله مرة واحدة في SQL Workshop على قاعدة youthdata.maxapex.net
-- ============================================================

-- (اختياري) اعرض البريد المكرّر قبل التنظيف:
-- SELECT LOWER("الايميل") em, COUNT(*) c FROM "USERS"
-- WHERE "الايميل" IS NOT NULL GROUP BY LOWER("الايميل") HAVING COUNT(*) > 1 ORDER BY c DESC;

------------------------------------------------------------------
-- 1) انقل الجلسات من الحسابات المكرّرة إلى الحساب الأقدم (min ID)
------------------------------------------------------------------
UPDATE "USER_SESSIONS" s
SET USER_ID = (
      SELECT MIN(u2."ID")
      FROM "USERS" u1
      JOIN "USERS" u2 ON LOWER(u2."الايميل") = LOWER(u1."الايميل")
      WHERE u1."ID" = s.USER_ID
    )
WHERE EXISTS (
      SELECT 1 FROM "USERS" u1
      WHERE u1."ID" = s.USER_ID AND u1."الايميل" IS NOT NULL
    );

------------------------------------------------------------------
-- 2) احذف الحسابات المكرّرة (نُبقي أقدم ID لكل بريد)
------------------------------------------------------------------
DELETE FROM "USERS" u
WHERE u."الايميل" IS NOT NULL
  AND u."ID" > (
      SELECT MIN(u2."ID") FROM "USERS" u2
      WHERE LOWER(u2."الايميل") = LOWER(u."الايميل")
    );

COMMIT;

------------------------------------------------------------------
-- 3) قيد فريد يمنع أي تكرار مستقبلاً (غير حسّاس لحالة الأحرف)
------------------------------------------------------------------
-- إن كان موجوداً مسبقاً تجاهل الخطأ.
CREATE UNIQUE INDEX "USERS_EMAIL_UK" ON "USERS" (LOWER("الايميل"));

------------------------------------------------------------------
-- 4) تحديث معالج /google — يأخذ صفاً واحداً دائماً (آمن ضد التكرار)
------------------------------------------------------------------
BEGIN
  ORDS.DEFINE_TEMPLATE(p_module_name => 'account_api', p_pattern => 'google');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'account_api',
    p_pattern     => 'google',
    p_method      => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source      => q'~
DECLARE
  l_id_token   VARCHAR2(4000) := :id_token;
  l_resp       CLOB;
  l_aud        VARCHAR2(4000);
  l_iss        VARCHAR2(200);
  l_email      VARCHAR2(320);
  l_email_ver  VARCHAR2(10);
  l_name       VARCHAR2(400);
  l_picture    VARCHAR2(1000);
  l_user_id    NUMBER;
  l_username   VARCHAR2(255);
  l_utype      VARCHAR2(50);
  l_token      VARCHAR2(255);
  l_refresh    VARCHAR2(255);
  c_client_mini CONSTANT VARCHAR2(200) := '1004575570279-qbj6utfs4v83sh0u1fnoad2m8t8bh455.apps.googleusercontent.com';
  c_client_main CONSTANT VARCHAR2(200) := '205688719038-kbskaupidmfulcra4h0hr8fkoeggko94.apps.googleusercontent.com';
BEGIN
  l_resp := APEX_WEB_SERVICE.make_rest_request(
              p_url         => 'https://oauth2.googleapis.com/tokeninfo?id_token=' || l_id_token,
              p_http_method => 'GET');
  IF APEX_WEB_SERVICE.g_status_code <> 200 THEN
    OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');
    HTP.p('{"success":false,"error":"رمز Google غير صالح"}'); RETURN;
  END IF;

  APEX_JSON.parse(l_resp);
  l_aud       := APEX_JSON.get_varchar2(p_path => 'aud');
  l_iss       := APEX_JSON.get_varchar2(p_path => 'iss');
  l_email     := LOWER(APEX_JSON.get_varchar2(p_path => 'email'));
  l_email_ver := APEX_JSON.get_varchar2(p_path => 'email_verified');
  l_name      := APEX_JSON.get_varchar2(p_path => 'name');
  l_picture   := APEX_JSON.get_varchar2(p_path => 'picture');

  IF l_aud NOT IN (c_client_mini, c_client_main)
     OR l_iss NOT IN ('accounts.google.com','https://accounts.google.com')
     OR NVL(l_email_ver,'false') <> 'true'
     OR l_email IS NULL THEN
    OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');
    HTP.p('{"success":false,"error":"رمز Google غير موثوق"}'); RETURN;
  END IF;

  -- ★ يأخذ الحساب الأقدم إن وُجد (آمن حتى لو بقي تكرار) — لا NO_DATA خطأ فقط
  BEGIN
    SELECT "ID", "نوع_المستخدم" INTO l_user_id, l_utype
    FROM (
      SELECT "ID", "نوع_المستخدم"
      FROM "USERS"
      WHERE LOWER("الايميل") = l_email
      ORDER BY "ID"
    ) WHERE ROWNUM = 1;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    l_user_id := NULL;
  END;

  -- ينشئ حساباً فقط إن لم يوجد أي حساب بهذا البريد
  IF l_user_id IS NULL THEN
    l_username := SUBSTR(l_email, 1, INSTR(l_email,'@') - 1);
    INSERT INTO "USERS"
      ("الايميل","الاسم_الكامل","صورة_الملف_الشخصي","نوع_المستخدم","اسم_المستخدم","حالة_الحساب","تاريخ_التسجيل")
    VALUES (l_email, l_name, l_picture, 'user_normal', l_username, 'نشط', SYSTIMESTAMP)
    RETURNING "ID" INTO l_user_id;
    l_utype := 'user_normal';
  ELSE
    UPDATE "USERS"
       SET "صورة_الملف_الشخصي" = NVL("صورة_الملف_الشخصي", l_picture),
           "آخر_تسجيل_دخول" = SYSTIMESTAMP
     WHERE "ID" = l_user_id;
  END IF;

  l_token   := RAWTOHEX(SYS_GUID()) || RAWTOHEX(SYS_GUID());
  l_refresh := RAWTOHEX(SYS_GUID()) || RAWTOHEX(SYS_GUID());
  INSERT INTO "USER_SESSIONS"
    (USER_ID, TOKEN, REFRESH_TOKEN, EXPIRES_AT, REFRESH_EXPIRES_AT, IS_ACTIVE, CREATED_AT, LAST_USED_AT)
  VALUES (l_user_id, l_token, l_refresh,
          SYSTIMESTAMP + INTERVAL '30' DAY, SYSTIMESTAMP + INTERVAL '60' DAY,
          1, SYSTIMESTAMP, SYSTIMESTAMP);
  COMMIT;

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
~');
  COMMIT;
END;
/
