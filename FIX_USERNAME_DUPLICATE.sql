-- ============================================================
-- إصلاح تكرار اسم المستخدم (ORA-01422 عند دخول التطبيق)
--   • ID 1  : tariqalsabal (بكلمة مرور، بلا بريد) = حساب الأدمن الأصلي  ← نُبقيه
--   • ID 181: tariqalsabal (Google, tariqalsabal@gmail.com) = مكرّر     ← ندمجه ونحذفه
--   ثم نحدّث معالج /google ليولّد اسم مستخدم فريد فلا يتكرّر مستقبلاً.
-- شغّله في SQL Workshop → SQL Scripts (أو نفّذ الأوامر بالترتيب في SQL Commands)
-- ============================================================

------------------------------------------------------------------
-- 1) دمج حساب Google (181) في حساب الأدمن (1)
------------------------------------------------------------------
-- انقل جلسات 181 إلى 1
UPDATE "USER_SESSIONS" SET USER_ID = 1 WHERE USER_ID = 181;

-- احذف الصف المكرّر
DELETE FROM "USERS" WHERE "ID" = 181;

-- اربط بريد Google بحساب الأدمن (حتى يدخل Google على نفس الحساب)
UPDATE "USERS" SET "الايميل" = 'tariqalsabal@gmail.com' WHERE "ID" = 1;

COMMIT;

------------------------------------------------------------------
-- 2) تحديث معالج /google — يبحث بالبريد (آمن ضد التكرار) + يولّد اسم مستخدم فريد
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
  l_ucnt       NUMBER;
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

  -- البحث بالبريد (يأخذ الأقدم إن وُجد تكرار) — لا ينشئ جديداً إن وُجد الحساب
  BEGIN
    SELECT "ID", "نوع_المستخدم" INTO l_user_id, l_utype
    FROM ( SELECT "ID", "نوع_المستخدم" FROM "USERS"
           WHERE LOWER("الايميل") = l_email ORDER BY "ID" )
    WHERE ROWNUM = 1;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    l_user_id := NULL;
  END;

  IF l_user_id IS NULL THEN
    -- اسم مستخدم من بادئة البريد + اجعله فريداً إن كان مستخدماً
    l_username := SUBSTR(l_email, 1, INSTR(l_email,'@') - 1);
    SELECT COUNT(*) INTO l_ucnt FROM "USERS" WHERE LOWER("اسم_المستخدم") = LOWER(l_username);
    IF l_ucnt > 0 THEN
      l_username := l_username || SUBSTR(RAWTOHEX(SYS_GUID()), 1, 5);
    END IF;

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
