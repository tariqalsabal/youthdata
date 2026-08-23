-- ============================================================
-- بانٍ الاستبيانات والاعتماد — معالج AJAX (م2 + م3)
-- النوع: Ajax Callback  |  الاسم: SURVEY_ADMIN
-- الإجراء عبر x01، المعاملات عبر x02..x04 و p_clob_01 (JSON)
-- ============================================================
DECLARE
  a  VARCHAR2(30)   := apex_application.g_x01;
  p2 VARCHAR2(4000) := apex_application.g_x02;
  p3 VARCHAR2(4000) := apex_application.g_x03;
  j  CLOB           := apex_application.g_clob_01;
  l_id NUMBER; l_n NUMBER;
BEGIN
  OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');

  -- ---------- قائمة الاستبيانات ----------
  IF a='list' THEN
    APEX_JSON.open_object; APEX_JSON.open_array('rows');
    FOR r IN (SELECT "ID","TITLE","STATUS","RESPONSE_COUNT","SHOW_ON_HOME","SHOW_ANALYTICS",
                     (SELECT COUNT(*) FROM "SURVEY_QUESTIONS" q WHERE q."SURVEY_ID"=s."ID") qn,
                     TO_CHAR("CREATED_AT",'YYYY-MM-DD') cr
              FROM "SURVEYS" s ORDER BY "ID" DESC) LOOP
      APEX_JSON.open_object;
        APEX_JSON.write('id',r."ID"); APEX_JSON.write('title',r."TITLE");
        APEX_JSON.write('status',r."STATUS"); APEX_JSON.write('responses',r."RESPONSE_COUNT");
        APEX_JSON.write('questions',r.qn); APEX_JSON.write('created',r.cr);
        APEX_JSON.write('onHome', CASE WHEN r."SHOW_ON_HOME"=1 THEN TRUE ELSE FALSE END);
        APEX_JSON.write('onAnalytics', CASE WHEN r."SHOW_ANALYTICS"=1 THEN TRUE ELSE FALSE END);
      APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array; APEX_JSON.close_object; RETURN;
  END IF;

  -- ---------- تفاصيل استبيان (meta + أسئلة + خيارات + شروط) ----------
  IF a='get' THEN
    l_id := TO_NUMBER(p2);
    APEX_JSON.open_object;
    FOR s IN (SELECT * FROM "SURVEYS" WHERE "ID"=l_id) LOOP
      APEX_JSON.write('id',s."ID"); APEX_JSON.write('slug',s."SLUG");
      APEX_JSON.write('title',s."TITLE"); APEX_JSON.write('description',s."DESCRIPTION");
      APEX_JSON.write('intro',s."INTRO_TEXT"); APEX_JSON.write('thanks',s."THANKS_TEXT");
      APEX_JSON.write('status',s."STATUS");
      APEX_JSON.write('requireLogin', CASE WHEN s."REQUIRE_LOGIN"=1 THEN TRUE ELSE FALSE END);
      APEX_JSON.write('allowMultiple', CASE WHEN s."ALLOW_MULTIPLE"=1 THEN TRUE ELSE FALSE END);
      APEX_JSON.write('collectEmail', CASE WHEN s."COLLECT_EMAIL"=1 THEN TRUE ELSE FALSE END);
      APEX_JSON.write('color',s."COVER_COLOR");
      APEX_JSON.write('reject',s."REJECT_REASON");
    END LOOP;
    APEX_JSON.open_array('questions');
    FOR q IN (SELECT * FROM "SURVEY_QUESTIONS" WHERE "SURVEY_ID"=l_id ORDER BY "DISPLAY_ORDER","ID") LOOP
      APEX_JSON.open_object;
        APEX_JSON.write('id',q."ID"); APEX_JSON.write('type',q."QTYPE");
        APEX_JSON.write('text',q."QTEXT"); APEX_JSON.write('desc',q."QDESC");
        APEX_JSON.write('required', CASE WHEN q."IS_REQUIRED"=1 THEN TRUE ELSE FALSE END);
        APEX_JSON.write('publishStat', CASE WHEN q."PUBLISH_STAT"=1 THEN TRUE ELSE FALSE END);
        APEX_JSON.write('settings', NVL(q."SETTINGS",'{}'));
        APEX_JSON.write('order', q."DISPLAY_ORDER");
        APEX_JSON.open_array('options');
        FOR o IN (SELECT * FROM "SURVEY_OPTIONS" WHERE "QUESTION_ID"=q."ID" ORDER BY "DISPLAY_ORDER","ID") LOOP
          APEX_JSON.open_object; APEX_JSON.write('id',o."ID"); APEX_JSON.write('text',o."OPT_TEXT"); APEX_JSON.close_object;
        END LOOP;
        APEX_JSON.close_array;
      APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array;
    APEX_JSON.open_array('conditions');
    FOR c IN (SELECT * FROM "SURVEY_CONDITIONS" WHERE "SURVEY_ID"=l_id ORDER BY "ID") LOOP
      APEX_JSON.open_object;
        APEX_JSON.write('id',c."ID"); APEX_JSON.write('target',c."TARGET_Q");
        APEX_JSON.write('source',c."SOURCE_Q"); APEX_JSON.write('operator',c."OPERATOR");
        APEX_JSON.write('value',c."MATCH_VALUE"); APEX_JSON.write('action',c."ACTION");
      APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array;
    APEX_JSON.close_object; RETURN;
  END IF;

  -- ---------- إنشاء استبيان ----------
  IF a='create' THEN
    INSERT INTO "SURVEYS" (TITLE,STATUS,CREATED_BY) VALUES (NVL(p3,'استبيان جديد'),'draft',NVL(V('APP_USER'),'admin'))
    RETURNING "ID" INTO l_id;
    COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.write('id',l_id); APEX_JSON.close_object; RETURN;
  END IF;

  -- ---------- حفظ بيانات الاستبيان ----------
  IF a='savemeta' THEN
    APEX_JSON.parse(j);
    UPDATE "SURVEYS" SET
      TITLE          = APEX_JSON.get_varchar2('title'),
      DESCRIPTION    = APEX_JSON.get_varchar2('description'),
      INTRO_TEXT     = APEX_JSON.get_varchar2('intro'),
      THANKS_TEXT    = APEX_JSON.get_varchar2('thanks'),
      SLUG           = APEX_JSON.get_varchar2('slug'),
      COVER_COLOR    = NVL(APEX_JSON.get_varchar2('color'),'#1e2a52'),
      REQUIRE_LOGIN  = NVL(APEX_JSON.get_number('requireLogin'),0),
      ALLOW_MULTIPLE = NVL(APEX_JSON.get_number('allowMultiple'),0),
      COLLECT_EMAIL  = NVL(APEX_JSON.get_number('collectEmail'),1)
    WHERE "ID"=TO_NUMBER(p2);
    COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='delsurvey' THEN
    DELETE FROM "SURVEYS" WHERE "ID"=TO_NUMBER(p2); COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  -- ---------- الأسئلة ----------
  IF a='addq' THEN
    SELECT NVL(MAX("DISPLAY_ORDER"),0)+10 INTO l_n FROM "SURVEY_QUESTIONS" WHERE "SURVEY_ID"=TO_NUMBER(p2);
    INSERT INTO "SURVEY_QUESTIONS" (SURVEY_ID,QTYPE,QTEXT,DISPLAY_ORDER)
    VALUES (TO_NUMBER(p2), p3, 'سؤال جديد', l_n) RETURNING "ID" INTO l_id;
    COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.write('id',l_id); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='saveq' THEN
    APEX_JSON.parse(j);
    UPDATE "SURVEY_QUESTIONS" SET
      QTYPE        = NVL(APEX_JSON.get_varchar2('type'),QTYPE),
      QTEXT        = APEX_JSON.get_varchar2('text'),
      QDESC        = APEX_JSON.get_varchar2('desc'),
      IS_REQUIRED  = NVL(APEX_JSON.get_number('required'),0),
      PUBLISH_STAT = NVL(APEX_JSON.get_number('publishStat'),0),
      SETTINGS     = APEX_JSON.get_varchar2('settings'),
      DISPLAY_ORDER= NVL(APEX_JSON.get_number('order'),DISPLAY_ORDER)
    WHERE "ID"=TO_NUMBER(p2);
    COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='delq' THEN
    DELETE FROM "SURVEY_QUESTIONS" WHERE "ID"=TO_NUMBER(p2); COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  -- ---------- الخيارات ----------
  IF a='addopt' THEN
    SELECT NVL(MAX("DISPLAY_ORDER"),0)+10 INTO l_n FROM "SURVEY_OPTIONS" WHERE "QUESTION_ID"=TO_NUMBER(p2);
    INSERT INTO "SURVEY_OPTIONS" (QUESTION_ID,OPT_TEXT,DISPLAY_ORDER)
    VALUES (TO_NUMBER(p2), NVL(p3,'خيار'), l_n) RETURNING "ID" INTO l_id;
    COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.write('id',l_id); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='saveopt' THEN
    UPDATE "SURVEY_OPTIONS" SET OPT_TEXT=p3 WHERE "ID"=TO_NUMBER(p2); COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='delopt' THEN
    DELETE FROM "SURVEY_OPTIONS" WHERE "ID"=TO_NUMBER(p2); COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  -- ---------- الشروط ----------
  IF a='addcond' THEN
    APEX_JSON.parse(j);
    INSERT INTO "SURVEY_CONDITIONS" (SURVEY_ID,TARGET_Q,SOURCE_Q,OPERATOR,MATCH_VALUE,ACTION)
    VALUES (TO_NUMBER(p2), APEX_JSON.get_number('target'), APEX_JSON.get_number('source'),
            APEX_JSON.get_varchar2('operator'), APEX_JSON.get_varchar2('value'),
            NVL(APEX_JSON.get_varchar2('action'),'show'));
    COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='delcond' THEN
    DELETE FROM "SURVEY_CONDITIONS" WHERE "ID"=TO_NUMBER(p2); COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  -- ---------- سير الاعتماد والنشر ----------
  IF a='submit_approval' THEN
    UPDATE "SURVEYS" SET STATUS='pending', SUBMITTED_AT=SYSTIMESTAMP, REJECT_REASON=NULL
     WHERE "ID"=TO_NUMBER(p2) AND STATUS IN ('draft','rejected'); COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='approve' THEN
    UPDATE "SURVEYS" SET STATUS='approved', APPROVED_BY=NVL(V('APP_USER'),'admin'), APPROVED_AT=SYSTIMESTAMP
     WHERE "ID"=TO_NUMBER(p2) AND STATUS='pending'; COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='reject' THEN
    UPDATE "SURVEYS" SET STATUS='rejected', REJECT_REASON=p3 WHERE "ID"=TO_NUMBER(p2) AND STATUS='pending'; COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='publish' THEN
    UPDATE "SURVEYS"
       SET STATUS='published', PUBLISHED_AT=SYSTIMESTAMP,
           SLUG=NVL(SLUG,'survey-'||"ID")
     WHERE "ID"=TO_NUMBER(p2) AND STATUS='approved'; COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='close' THEN
    UPDATE "SURVEYS" SET STATUS='closed' WHERE "ID"=TO_NUMBER(p2); COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='toggle_home' THEN
    UPDATE "SURVEYS" SET SHOW_ON_HOME=1-SHOW_ON_HOME WHERE "ID"=TO_NUMBER(p2); COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  IF a='toggle_analytics' THEN
    UPDATE "SURVEYS" SET SHOW_ANALYTICS=1-SHOW_ANALYTICS WHERE "ID"=TO_NUMBER(p2); COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  -- ---------- الردود (عرض + تصدير) ----------
  IF a='responses' THEN
    l_id := TO_NUMBER(p2);
    APEX_JSON.open_object;
    -- الأعمدة (الأسئلة)
    APEX_JSON.open_array('columns');
    FOR q IN (SELECT "ID","QTEXT" FROM "SURVEY_QUESTIONS" WHERE "SURVEY_ID"=l_id ORDER BY "DISPLAY_ORDER","ID") LOOP
      APEX_JSON.open_object; APEX_JSON.write('id',q."ID"); APEX_JSON.write('text',q."QTEXT"); APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array;
    -- الجلسات
    APEX_JSON.open_array('responses');
    FOR r IN (SELECT "ID","EMAIL","RESPONDENT",TO_CHAR("SUBMITTED_AT",'YYYY-MM-DD HH24:MI') dt,
                     "REGION","CITY","COUNTRY","USER_ID"
              FROM "SURVEY_RESPONSES" WHERE "SURVEY_ID"=l_id
              ORDER BY "ID" DESC FETCH FIRST 5000 ROWS ONLY) LOOP
      APEX_JSON.open_object;
        APEX_JSON.write('id',r."ID"); APEX_JSON.write('email',r."EMAIL");
        APEX_JSON.write('name',r."RESPONDENT"); APEX_JSON.write('date',r.dt);
        APEX_JSON.write('region',r."REGION"); APEX_JSON.write('city',r."CITY");
        APEX_JSON.write('country',r."COUNTRY");
        APEX_JSON.write('registered', CASE WHEN r."USER_ID" IS NOT NULL THEN TRUE ELSE FALSE END);
      APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array;
    -- الإجابات (قيمة نصية لكل سؤال في كل جلسة؛ الاختيار المتعدد مدموج)
    APEX_JSON.open_array('answers');
    FOR x IN (
      SELECT a."RESPONSE_ID" r, a."QUESTION_ID" q,
             LISTAGG(NVL(o."OPT_TEXT", NVL(a."ANSWER_TEXT", TO_CHAR(a."ANSWER_NUMBER"))), ' | ')
               WITHIN GROUP (ORDER BY a."ID") v
      FROM "SURVEY_ANSWERS" a
      LEFT JOIN "SURVEY_OPTIONS" o ON o."ID"=a."OPTION_ID"
      JOIN "SURVEY_RESPONSES" rs ON rs."ID"=a."RESPONSE_ID"
      WHERE rs."SURVEY_ID"=l_id
      GROUP BY a."RESPONSE_ID", a."QUESTION_ID"
    ) LOOP
      APEX_JSON.open_object;
        APEX_JSON.write('r',x.r); APEX_JSON.write('q',x.q); APEX_JSON.write('v',x.v);
      APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array;
    APEX_JSON.close_object; RETURN;
  END IF;

  APEX_JSON.open_object; APEX_JSON.write('success',FALSE); APEX_JSON.write('error','إجراء غير معروف'); APEX_JSON.close_object;
END;
