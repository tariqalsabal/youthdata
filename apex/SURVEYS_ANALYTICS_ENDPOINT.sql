-- ============================================================
-- تحليلات الاستبيانات — نقطة عامة (م7)
--   GET /auth/cms/survey-analytics
--   تُرجع تجميعاً تلقائياً للأسئلة المعلّمة للنشر (PUBLISH_STAT=1)
--   في الاستبيانات المعلّمة (SHOW_ANALYTICS=1) المنشورة.
-- يُعاد تشغيله بأمان.
-- ============================================================
BEGIN
  ORDS.DEFINE_TEMPLATE(p_module_name => 'AUTH_API', p_pattern => 'cms/survey-analytics');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'AUTH_API', p_pattern => 'cms/survey-analytics', p_method => 'GET',
    p_source_type => ORDS.source_type_plsql,
    p_source => q'~
DECLARE
  l_total NUMBER;
  l_avg   NUMBER;
BEGIN
  OWA_UTIL.mime_header('application/json', FALSE, 'UTF-8');
  HTP.p('Access-Control-Allow-Origin: *'); OWA_UTIL.http_header_close;
  APEX_JSON.initialize_clob_output;
  APEX_JSON.open_object;
  APEX_JSON.open_array('surveys');

  FOR s IN (SELECT "ID","TITLE","RESPONSE_COUNT","COVER_COLOR"
            FROM "SURVEYS" WHERE "STATUS"='published' AND "SHOW_ANALYTICS"=1
            ORDER BY "PUBLISHED_AT" DESC) LOOP
    APEX_JSON.open_object;
      APEX_JSON.write('id', s."ID");
      APEX_JSON.write('title', s."TITLE");
      APEX_JSON.write('color', s."COVER_COLOR");
      APEX_JSON.write('responseCount', s."RESPONSE_COUNT");
      APEX_JSON.open_array('questions');

      FOR q IN (SELECT "ID","QTYPE","QTEXT" FROM "SURVEY_QUESTIONS"
                WHERE "SURVEY_ID"=s."ID" AND "PUBLISH_STAT"=1
                ORDER BY "DISPLAY_ORDER","ID") LOOP
        APEX_JSON.open_object;
          APEX_JSON.write('id', q."ID");
          APEX_JSON.write('type', q."QTYPE");
          APEX_JSON.write('text', q."QTEXT");

          IF q."QTYPE" IN ('single','multiple','dropdown') THEN
            -- إجمالي الردود على السؤال (عدد الجلسات التي أجابت)
            SELECT COUNT(DISTINCT a."RESPONSE_ID") INTO l_total
            FROM "SURVEY_ANSWERS" a WHERE a."QUESTION_ID"=q."ID";
            APEX_JSON.write('answered', l_total);
            APEX_JSON.open_array('options');
            FOR o IN (SELECT o."OPT_TEXT",
                             (SELECT COUNT(*) FROM "SURVEY_ANSWERS" a WHERE a."OPTION_ID"=o."ID") cnt
                      FROM "SURVEY_OPTIONS" o WHERE o."QUESTION_ID"=q."ID"
                      ORDER BY o."DISPLAY_ORDER","ID") LOOP
              APEX_JSON.open_object;
                APEX_JSON.write('label', o."OPT_TEXT");
                APEX_JSON.write('count', o.cnt);
                APEX_JSON.write('pct', CASE WHEN l_total>0 THEN ROUND(o.cnt*100/l_total,1) ELSE 0 END);
              APEX_JSON.close_object;
            END LOOP;
            APEX_JSON.close_array;

          ELSIF q."QTYPE" = 'yesno' THEN
            SELECT COUNT(*) INTO l_total FROM "SURVEY_ANSWERS" WHERE "QUESTION_ID"=q."ID";
            APEX_JSON.write('answered', l_total);
            APEX_JSON.open_array('options');
            FOR o IN (SELECT "ANSWER_TEXT" v, COUNT(*) cnt FROM "SURVEY_ANSWERS"
                      WHERE "QUESTION_ID"=q."ID" GROUP BY "ANSWER_TEXT" ORDER BY 2 DESC) LOOP
              APEX_JSON.open_object;
                APEX_JSON.write('label', o.v);
                APEX_JSON.write('count', o.cnt);
                APEX_JSON.write('pct', CASE WHEN l_total>0 THEN ROUND(o.cnt*100/l_total,1) ELSE 0 END);
              APEX_JSON.close_object;
            END LOOP;
            APEX_JSON.close_array;

          ELSIF q."QTYPE" IN ('scale','rating','number') THEN
            SELECT COUNT(*), ROUND(AVG("ANSWER_NUMBER"),2)
            INTO l_total, l_avg FROM "SURVEY_ANSWERS"
            WHERE "QUESTION_ID"=q."ID" AND "ANSWER_NUMBER" IS NOT NULL;
            APEX_JSON.write('answered', l_total);
            APEX_JSON.write('average', l_avg);
            APEX_JSON.open_array('distribution');
            FOR d IN (SELECT "ANSWER_NUMBER" v, COUNT(*) cnt FROM "SURVEY_ANSWERS"
                      WHERE "QUESTION_ID"=q."ID" AND "ANSWER_NUMBER" IS NOT NULL
                      GROUP BY "ANSWER_NUMBER" ORDER BY "ANSWER_NUMBER") LOOP
              APEX_JSON.open_object;
                APEX_JSON.write('label', TO_CHAR(d.v));
                APEX_JSON.write('count', d.cnt);
              APEX_JSON.close_object;
            END LOOP;
            APEX_JSON.close_array;

          ELSE  -- نصوص/تاريخ/شبكة: نكتفي بعدد الردود (لا يُنشر المحتوى)
            SELECT COUNT(*) INTO l_total FROM "SURVEY_ANSWERS"
            WHERE "QUESTION_ID"=q."ID"
              AND ("ANSWER_TEXT" IS NOT NULL OR "ANSWER_NUMBER" IS NOT NULL);
            APEX_JSON.write('answered', l_total);
          END IF;

        APEX_JSON.close_object;
      END LOOP;

      APEX_JSON.close_array;
    APEX_JSON.close_object;
  END LOOP;

  APEX_JSON.close_array;
  APEX_JSON.close_object;
  HTP.p(APEX_JSON.get_clob_output); APEX_JSON.free_output;
END;
~');
  COMMIT;
END;
/
