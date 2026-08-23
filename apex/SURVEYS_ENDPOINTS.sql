-- ============================================================
-- منظومة الاستبيانات — نقاط ORDS العامة (م1)
--   GET  /auth/cms/surveys            قائمة الاستبيانات المنشورة (?home=1 لقسم الرئيسية)
--   GET  /auth/cms/survey/:slug       تعريف استبيان كامل (أسئلة/خيارات/شروط)
--   POST /account/v1/survey/submit    استقبال رد + تسجيل صامت للزائر
-- يُعاد تشغيله بأمان.
-- ============================================================
BEGIN
  ------------------------------------------------------------------
  -- 1) قائمة الاستبيانات المنشورة
  ------------------------------------------------------------------
  ORDS.DEFINE_TEMPLATE(p_module_name => 'AUTH_API', p_pattern => 'cms/surveys');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'AUTH_API', p_pattern => 'cms/surveys', p_method => 'GET',
    p_source_type => ORDS.source_type_plsql,
    p_source => q'~
DECLARE
  l_home VARCHAR2(4) := :home;
BEGIN
  OWA_UTIL.mime_header('application/json', FALSE, 'UTF-8');
  HTP.p('Access-Control-Allow-Origin: *'); OWA_UTIL.http_header_close;
  APEX_JSON.initialize_clob_output;
  APEX_JSON.open_object;
  APEX_JSON.open_array('items');
  FOR r IN (
    SELECT "ID","SLUG","TITLE","DESCRIPTION","COVER_COLOR","COVER_ICON",
           "RESPONSE_COUNT","SHOW_ANALYTICS",
           TO_CHAR("CLOSES_AT",'YYYY-MM-DD"T"HH24:MI:SS') closes
    FROM "SURVEYS"
    WHERE "STATUS"='published'
      AND ("CLOSES_AT" IS NULL OR "CLOSES_AT" > SYSTIMESTAMP)
      AND (l_home IS NULL OR l_home='0' OR "SHOW_ON_HOME"=1)
    ORDER BY "PUBLISHED_AT" DESC
  ) LOOP
    APEX_JSON.open_object;
      APEX_JSON.write('id', r."ID");
      APEX_JSON.write('slug', r."SLUG");
      APEX_JSON.write('title', r."TITLE");
      APEX_JSON.write('description', r."DESCRIPTION");
      APEX_JSON.write('color', r."COVER_COLOR");
      APEX_JSON.write('icon', r."COVER_ICON");
      APEX_JSON.write('responseCount', r."RESPONSE_COUNT");
      APEX_JSON.write('hasAnalytics', CASE WHEN r."SHOW_ANALYTICS"=1 THEN TRUE ELSE FALSE END);
      APEX_JSON.write('closesAt', r.closes);
    APEX_JSON.close_object;
  END LOOP;
  APEX_JSON.close_array;
  APEX_JSON.close_object;
  HTP.p(APEX_JSON.get_clob_output); APEX_JSON.free_output;
END;
~');

  ------------------------------------------------------------------
  -- 2) تعريف استبيان كامل
  ------------------------------------------------------------------
  ORDS.DEFINE_TEMPLATE(p_module_name => 'AUTH_API', p_pattern => 'cms/survey/:slug');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'AUTH_API', p_pattern => 'cms/survey/:slug', p_method => 'GET',
    p_source_type => ORDS.source_type_plsql,
    p_source => q'~
DECLARE
  l_id NUMBER; l_title VARCHAR2(300); l_desc VARCHAR2(4000);
  l_intro VARCHAR2(2000); l_thanks VARCHAR2(2000); l_status VARCHAR2(20);
  l_reqlogin NUMBER; l_multi NUMBER; l_email NUMBER; l_color VARCHAR2(20); l_icon VARCHAR2(60);
BEGIN
  OWA_UTIL.mime_header('application/json', FALSE, 'UTF-8');
  HTP.p('Access-Control-Allow-Origin: *'); OWA_UTIL.http_header_close;
  BEGIN
    SELECT "ID","TITLE","DESCRIPTION","INTRO_TEXT","THANKS_TEXT","STATUS",
           "REQUIRE_LOGIN","ALLOW_MULTIPLE","COLLECT_EMAIL","COVER_COLOR","COVER_ICON"
    INTO l_id,l_title,l_desc,l_intro,l_thanks,l_status,l_reqlogin,l_multi,l_email,l_color,l_icon
    FROM "SURVEYS" WHERE "SLUG"=:slug AND "STATUS"='published';
  EXCEPTION WHEN NO_DATA_FOUND THEN
    HTP.p('{"success":false,"error":"الاستبيان غير متاح"}'); RETURN;
  END;

  APEX_JSON.initialize_clob_output;
  APEX_JSON.open_object;
    APEX_JSON.write('success', TRUE);
    APEX_JSON.write('id', l_id);
    APEX_JSON.write('title', l_title);
    APEX_JSON.write('description', l_desc);
    APEX_JSON.write('introText', l_intro);
    APEX_JSON.write('thanksText', l_thanks);
    APEX_JSON.write('requireLogin', CASE WHEN l_reqlogin=1 THEN TRUE ELSE FALSE END);
    APEX_JSON.write('allowMultiple', CASE WHEN l_multi=1 THEN TRUE ELSE FALSE END);
    APEX_JSON.write('collectEmail', CASE WHEN l_email=1 THEN TRUE ELSE FALSE END);
    APEX_JSON.write('color', l_color);
    APEX_JSON.write('icon', l_icon);

    APEX_JSON.open_array('questions');
    FOR q IN (SELECT "ID","QTYPE","QTEXT","QDESC","IS_REQUIRED","SETTINGS"
              FROM "SURVEY_QUESTIONS" WHERE "SURVEY_ID"=l_id ORDER BY "DISPLAY_ORDER","ID") LOOP
      APEX_JSON.open_object;
        APEX_JSON.write('id', q."ID");
        APEX_JSON.write('type', q."QTYPE");
        APEX_JSON.write('text', q."QTEXT");
        APEX_JSON.write('desc', q."QDESC");
        APEX_JSON.write('required', CASE WHEN q."IS_REQUIRED"=1 THEN TRUE ELSE FALSE END);
        APEX_JSON.write('settings', NVL(q."SETTINGS",'{}'));  -- نص JSON يُحلّل في الواجهة
        APEX_JSON.open_array('options');
        FOR o IN (SELECT "ID","OPT_TEXT" FROM "SURVEY_OPTIONS"
                  WHERE "QUESTION_ID"=q."ID" ORDER BY "DISPLAY_ORDER","ID") LOOP
          APEX_JSON.open_object;
            APEX_JSON.write('id', o."ID"); APEX_JSON.write('text', o."OPT_TEXT");
          APEX_JSON.close_object;
        END LOOP;
        APEX_JSON.close_array;
      APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array;

    APEX_JSON.open_array('conditions');
    FOR c IN (SELECT "TARGET_Q","SOURCE_Q","OPERATOR","MATCH_VALUE","ACTION"
              FROM "SURVEY_CONDITIONS" WHERE "SURVEY_ID"=l_id) LOOP
      APEX_JSON.open_object;
        APEX_JSON.write('target', c."TARGET_Q");
        APEX_JSON.write('source', c."SOURCE_Q");
        APEX_JSON.write('operator', c."OPERATOR");
        APEX_JSON.write('value', c."MATCH_VALUE");
        APEX_JSON.write('action', c."ACTION");
      APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array;
  APEX_JSON.close_object;
  HTP.p(APEX_JSON.get_clob_output); APEX_JSON.free_output;
END;
~');

  ------------------------------------------------------------------
  -- 3) استقبال رد + تسجيل صامت (تحت account_api)
  --    Body: { survey_id, email, name?, token?, country?, region?, city?,
  --            answers_json: '{"list":[{"q":10,"opts":[100],"text":"..","num":5}]}' }
  ------------------------------------------------------------------
  ORDS.DEFINE_TEMPLATE(p_module_name => 'account_api', p_pattern => 'survey/submit');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'account_api', p_pattern => 'survey/submit', p_method => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source => q'~
DECLARE
  l_sid    NUMBER := :survey_id;
  l_email  VARCHAR2(320) := LOWER(TRIM(:email));
  l_name   VARCHAR2(255) := :name;
  l_token  VARCHAR2(255) := :token;
  l_ans    CLOB := :answers_json;
  l_status VARCHAR2(20); l_multi NUMBER; l_collect NUMBER;
  l_uid NUMBER; l_rid NUMBER; l_username VARCHAR2(255); l_ucnt NUMBER;
  l_exist NUMBER; n NUMBER; oc NUMBER;
  l_q NUMBER; l_txt VARCHAR2(4000); l_num NUMBER; l_opt NUMBER; l_thanks VARCHAR2(2000);
BEGIN
  OWA_UTIL.mime_header('application/json', FALSE, 'UTF-8');
  HTP.p('Access-Control-Allow-Origin: *'); OWA_UTIL.http_header_close;

  -- تحقّق الاستبيان
  BEGIN
    SELECT "STATUS","ALLOW_MULTIPLE","COLLECT_EMAIL","THANKS_TEXT"
    INTO l_status,l_multi,l_collect,l_thanks FROM "SURVEYS" WHERE "ID"=l_sid;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    HTP.p('{"success":false,"error":"الاستبيان غير موجود"}'); RETURN;
  END;
  IF l_status <> 'published' THEN
    HTP.p('{"success":false,"error":"الاستبيان غير متاح للتعبئة"}'); RETURN;
  END IF;
  IF l_collect=1 AND (l_email IS NULL OR INSTR(l_email,'@')=0) THEN
    HTP.p('{"success":false,"error":"البريد الإلكتروني مطلوب"}'); RETURN;
  END IF;

  -- المستخدم: من التوكن، وإلا من البريد (بحث أو تسجيل صامت)
  IF l_token IS NOT NULL THEN
    BEGIN SELECT USER_ID INTO l_uid FROM "USER_SESSIONS"
          WHERE TOKEN=l_token AND EXPIRES_AT>SYSTIMESTAMP;
    EXCEPTION WHEN NO_DATA_FOUND THEN l_uid := NULL; END;
  END IF;
  IF l_uid IS NULL AND l_email IS NOT NULL THEN
    BEGIN
      SELECT "ID" INTO l_uid FROM (SELECT "ID" FROM "USERS"
             WHERE LOWER("الايميل")=l_email ORDER BY "ID") WHERE ROWNUM=1;
    EXCEPTION WHEN NO_DATA_FOUND THEN
      -- تسجيل صامت
      l_username := SUBSTR(l_email,1,INSTR(l_email,'@')-1);
      SELECT COUNT(*) INTO l_ucnt FROM "USERS" WHERE LOWER("اسم_المستخدم")=LOWER(l_username);
      IF l_ucnt>0 THEN l_username := l_username||SUBSTR(RAWTOHEX(SYS_GUID()),1,5); END IF;
      INSERT INTO "USERS" ("الايميل","الاسم_الكامل","نوع_المستخدم","اسم_المستخدم","حالة_الحساب","تاريخ_التسجيل")
      VALUES (l_email, l_name, 'user_normal', l_username, 'نشط', SYSTIMESTAMP)
      RETURNING "ID" INTO l_uid;
    END;
  END IF;

  -- منع التكرار إن كان رد واحد لكل بريد
  IF l_multi=0 AND l_email IS NOT NULL THEN
    SELECT COUNT(*) INTO l_exist FROM "SURVEY_RESPONSES"
    WHERE "SURVEY_ID"=l_sid AND (LOWER("EMAIL")=l_email OR ("USER_ID" IS NOT NULL AND "USER_ID"=l_uid));
    IF l_exist>0 THEN
      HTP.p('{"success":false,"error":"سبق أن شاركت في هذا الاستبيان","duplicate":true}'); RETURN;
    END IF;
  END IF;

  -- جلسة الرد
  INSERT INTO "SURVEY_RESPONSES" ("SURVEY_ID","USER_ID","EMAIL","RESPONDENT","COUNTRY","REGION","CITY")
  VALUES (l_sid, l_uid, l_email, l_name, :country, :region, :city)
  RETURNING "ID" INTO l_rid;

  -- الإجابات
  IF l_ans IS NOT NULL THEN
    APEX_JSON.parse(l_ans);
    n := NVL(APEX_JSON.get_count(p_path=>'list'),0);
    FOR i IN 1..n LOOP
      l_q   := APEX_JSON.get_number (p_path=>'list[%d].q',    p0=>i);
      l_txt := APEX_JSON.get_varchar2(p_path=>'list[%d].text', p0=>i);
      l_num := APEX_JSON.get_number (p_path=>'list[%d].num',  p0=>i);
      oc    := NVL(APEX_JSON.get_count(p_path=>'list[%d].opts', p0=>i),0);
      IF oc>0 THEN
        FOR j IN 1..oc LOOP
          l_opt := APEX_JSON.get_number(p_path=>'list[%d].opts[%d]', p0=>i, p1=>j);
          INSERT INTO "SURVEY_ANSWERS" ("RESPONSE_ID","QUESTION_ID","OPTION_ID")
          VALUES (l_rid, l_q, l_opt);
        END LOOP;
      ELSE
        INSERT INTO "SURVEY_ANSWERS" ("RESPONSE_ID","QUESTION_ID","ANSWER_TEXT","ANSWER_NUMBER")
        VALUES (l_rid, l_q, l_txt, l_num);
      END IF;
    END LOOP;
  END IF;

  UPDATE "SURVEYS" SET "RESPONSE_COUNT"="RESPONSE_COUNT"+1 WHERE "ID"=l_sid;
  COMMIT;

  APEX_JSON.initialize_clob_output;
  APEX_JSON.open_object;
    APEX_JSON.write('success', TRUE);
    APEX_JSON.write('thanks', l_thanks);
  APEX_JSON.close_object;
  HTP.p(APEX_JSON.get_clob_output); APEX_JSON.free_output;
EXCEPTION WHEN OTHERS THEN
  HTP.p('{"success":false,"error":"'||REPLACE(SUBSTR(SQLERRM,1,200),'"','''')||'"}');
END;
~');

  COMMIT;
END;
/
