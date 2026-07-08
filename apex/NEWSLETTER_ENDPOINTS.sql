-- ============================================================
-- نقاط الاشتراك العامة في ORDS (وحدة account_api)
--   POST /account/v1/newsletter/subscribe        { "email": "...", "name": "..." }
--   GET  /account/v1/newsletter/unsubscribe/:token
-- ملاحظة: نقطة الاشتراك تُرسل ترويسة CORS ( * ) لتعمل من أي موقع.
-- يُعاد تشغيله بأمان (ORDS.DEFINE_* تحدّث الموجود).
-- ============================================================
BEGIN
  ------------------------------------------------------------------
  -- الاشتراك (عام — للمسجّل وغير المسجّل، ومن أي موقع)
  ------------------------------------------------------------------
  ORDS.DEFINE_TEMPLATE(p_module_name => 'account_api', p_pattern => 'newsletter/subscribe');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'account_api',
    p_pattern     => 'newsletter/subscribe',
    p_method      => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source      => q'~
DECLARE
  l_email  VARCHAR2(320) := LOWER(TRIM(:email));
  l_name   VARCHAR2(255) := :name;
  l_id     NUMBER;
  l_status VARCHAR2(20);
  l_uid    NUMBER;
  l_token  VARCHAR2(64);
BEGIN
  -- ترويسات الاستجابة مع CORS
  OWA_UTIL.mime_header('application/json', FALSE, 'UTF-8');
  HTP.p('Access-Control-Allow-Origin: *');
  OWA_UTIL.http_header_close;

  IF l_email IS NULL OR INSTR(l_email,'@') = 0 THEN
    HTP.p('{"success":false,"error":"البريد الإلكتروني غير صحيح"}'); RETURN;
  END IF;

  BEGIN
    SELECT ID, STATUS INTO l_id, l_status
    FROM "NEWSLETTER_SUBSCRIBERS" WHERE LOWER(EMAIL) = l_email;

    IF l_status = 'unsubscribed' THEN
      UPDATE "NEWSLETTER_SUBSCRIBERS"
         SET STATUS='active', UNSUBSCRIBED_AT=NULL,
             FULL_NAME=NVL(l_name,FULL_NAME), SUBSCRIBED_AT=SYSTIMESTAMP
       WHERE ID=l_id;
      COMMIT;
      HTP.p('{"success":true,"message":"تمت إعادة تفعيل اشتراكك"}');
    ELSE
      HTP.p('{"success":true,"message":"أنت مشترك بالفعل"}');
    END IF;
    RETURN;
  EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
  END;

  BEGIN
    SELECT "ID" INTO l_uid FROM "USERS" WHERE LOWER("الايميل") = l_email;
  EXCEPTION WHEN NO_DATA_FOUND THEN l_uid := NULL;
  END;

  l_token := RAWTOHEX(SYS_GUID());
  INSERT INTO "NEWSLETTER_SUBSCRIBERS" (EMAIL, FULL_NAME, USER_ID, STATUS, CONFIRM_TOKEN, SOURCE)
  VALUES (l_email, l_name, l_uid, 'active', l_token, 'website');
  COMMIT;
  HTP.p('{"success":true,"message":"تم الاشتراك في النشرة بنجاح"}');
END;
~');

  ------------------------------------------------------------------
  -- إلغاء الاشتراك عبر رابط بريدي (يُعيد صفحة HTML)
  ------------------------------------------------------------------
  ORDS.DEFINE_TEMPLATE(p_module_name => 'account_api', p_pattern => 'newsletter/unsubscribe/:token');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'account_api',
    p_pattern     => 'newsletter/unsubscribe/:token',
    p_method      => 'GET',
    p_source_type => ORDS.source_type_plsql,
    p_source      => q'~
DECLARE
  l_n NUMBER;
BEGIN
  UPDATE "NEWSLETTER_SUBSCRIBERS"
     SET STATUS='unsubscribed', UNSUBSCRIBED_AT=SYSTIMESTAMP
   WHERE CONFIRM_TOKEN = :token AND STATUS='active';
  l_n := SQL%ROWCOUNT;
  COMMIT;
  OWA_UTIL.mime_header('text/html', TRUE, 'UTF-8');
  HTP.p('<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8">'
     || '<meta name="viewport" content="width=device-width,initial-scale=1">'
     || '<title>إلغاء الاشتراك</title></head>'
     || '<body style="font-family:''Segoe UI'',Tahoma,sans-serif;background:#eef1f8;color:#1e2a52;'
     || 'display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0">'
     || '<div style="background:#fff;border-radius:16px;padding:40px 48px;text-align:center;'
     || 'box-shadow:0 8px 30px rgba(30,42,82,.12);max-width:440px">');
  IF l_n > 0 THEN
    HTP.p('<h2 style="margin:0 0 8px">تم إلغاء اشتراكك</h2>'
       || '<p style="color:#64748b">لن تصلك رسائل النشرة البريدية بعد الآن.</p>');
  ELSE
    HTP.p('<h2 style="margin:0 0 8px">الرابط غير صالح</h2>'
       || '<p style="color:#64748b">قد يكون الاشتراك مُلغى مسبقاً أو الرابط منتهياً.</p>');
  END IF;
  HTP.p('</div></body></html>');
END;
~');

  COMMIT;
END;
/
