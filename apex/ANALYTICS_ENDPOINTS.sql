-- ============================================================
-- نقاط تسجيل الزيارات والبحث في ORDS (وحدة account_api)
--   POST /account/v1/track/visit
--   POST /account/v1/track/search
-- تُستدعى من الخادم (Next.js route) لا من المتصفح مباشرة → لا حاجة لـ CORS
-- شغّله مرة واحدة في SQL Workshop → SQL Scripts
-- ============================================================
BEGIN
  ------------------------------------------------------------------
  -- زيارة صفحة
  ------------------------------------------------------------------
  ORDS.DEFINE_TEMPLATE(p_module_name => 'account_api', p_pattern => 'track/visit');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'account_api',
    p_pattern     => 'track/visit',
    p_method      => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source      => q'~
DECLARE
  l_token   VARCHAR2(255)  := :token;
  l_user_id NUMBER;
  l_country VARCHAR2(2)    := UPPER(:country);
  l_rcode   VARCHAR2(10)   := :region;
  l_rname   VARCHAR2(100);
BEGIN
  -- استخرج المستخدم من توكن الجلسة (إن وُجد) — غير قابل للتزوير
  IF l_token IS NOT NULL THEN
    BEGIN
      SELECT USER_ID INTO l_user_id FROM "USER_SESSIONS"
      WHERE TOKEN = l_token AND IS_ACTIVE = 1 AND EXPIRES_AT > SYSTIMESTAMP;
    EXCEPTION WHEN OTHERS THEN l_user_id := NULL;
    END;
  END IF;

  -- اسم المنطقة العربي للسعودية
  IF l_country = 'SA' AND l_rcode IS NOT NULL THEN
    BEGIN
      SELECT "NAME_AR" INTO l_rname FROM "GEO_SA_REGIONS" WHERE "CODE" = l_rcode;
    EXCEPTION WHEN NO_DATA_FOUND THEN l_rname := NULL;
    END;
  END IF;

  INSERT INTO "VISITS"
    ("VISITOR_ID","USER_ID","IS_REGISTERED","PAGE_PATH","PAGE_PATTERN","PAGE_TITLE",
     "REFERRER","COUNTRY_CODE","REGION_CODE","REGION_NAME","CITY",
     "DEVICE_TYPE","BROWSER","OS","SESSION_KEY")
  VALUES
    (:visitor_id, l_user_id, CASE WHEN l_user_id IS NULL THEN 0 ELSE 1 END,
     SUBSTR(:path,1,500), SUBSTR(:pattern,1,200), SUBSTR(:title,1,300),
     SUBSTR(:referrer,1,500), l_country, l_rcode, l_rname, SUBSTR(:city,1,100),
     :device, :browser, :os, :session_key);
  COMMIT;

  OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');
  HTP.p('{"success":true}');
EXCEPTION WHEN OTHERS THEN
  -- التتبّع لا يجب أن يُفشل أي شيء
  OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');
  HTP.p('{"success":false}');
END;
~');

  ------------------------------------------------------------------
  -- عملية بحث
  ------------------------------------------------------------------
  ORDS.DEFINE_TEMPLATE(p_module_name => 'account_api', p_pattern => 'track/search');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'account_api',
    p_pattern     => 'track/search',
    p_method      => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source      => q'~
DECLARE
  l_token   VARCHAR2(255) := :token;
  l_user_id NUMBER;
  l_term    VARCHAR2(400) := SUBSTR(TRIM(:term),1,400);
  l_country VARCHAR2(2)   := UPPER(:country);
  l_rcode   VARCHAR2(10)  := :region;
  l_rname   VARCHAR2(100);
BEGIN
  IF l_term IS NULL THEN
    OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');
    HTP.p('{"success":false}'); RETURN;
  END IF;

  IF l_token IS NOT NULL THEN
    BEGIN
      SELECT USER_ID INTO l_user_id FROM "USER_SESSIONS"
      WHERE TOKEN = l_token AND IS_ACTIVE = 1 AND EXPIRES_AT > SYSTIMESTAMP;
    EXCEPTION WHEN OTHERS THEN l_user_id := NULL;
    END;
  END IF;

  IF l_country = 'SA' AND l_rcode IS NOT NULL THEN
    BEGIN
      SELECT "NAME_AR" INTO l_rname FROM "GEO_SA_REGIONS" WHERE "CODE" = l_rcode;
    EXCEPTION WHEN NO_DATA_FOUND THEN l_rname := NULL;
    END;
  END IF;

  INSERT INTO "SEARCH_LOG"
    ("VISITOR_ID","USER_ID","TERM","TERM_NORM","RESULTS_CNT","PAGE_PATH","COUNTRY_CODE","REGION_NAME")
  VALUES
    (:visitor_id, l_user_id, l_term, LOWER(l_term), :results, SUBSTR(:path,1,500), l_country, l_rname);
  COMMIT;

  OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');
  HTP.p('{"success":true}');
EXCEPTION WHEN OTHERS THEN
  OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');
  HTP.p('{"success":false}');
END;
~');

  COMMIT;
END;
/
