-- ============================================================
-- معالج AJAX لإدارة النشرة البريدية
-- النوع: Ajax Callback  |  الاسم: NL_ADMIN
-- الإجراء عبر x01 ، والمعاملات عبر x02..x03 و p_clob_01
-- ============================================================
DECLARE
  l_act  VARCHAR2(30)   := apex_application.g_x01;
  l_p2   VARCHAR2(4000) := apex_application.g_x02;
  l_p3   VARCHAR2(4000) := apex_application.g_x03;
  l_body CLOB           := apex_application.g_clob_01;
  l_id   NUMBER;
  n1 NUMBER; n2 NUMBER; n3 NUMBER; n4 NUMBER; n5 NUMBER; n6 NUMBER; n7 NUMBER; n8 NUMBER; n9 NUMBER;
BEGIN
  OWA_UTIL.mime_header('application/json', TRUE, 'UTF-8');

  -- ------------------- إحصاءات -------------------
  IF l_act = 'stats' THEN
    SELECT COUNT(*),
           COUNT(CASE WHEN STATUS='active' THEN 1 END),
           COUNT(CASE WHEN STATUS='unsubscribed' THEN 1 END),
           COUNT(CASE WHEN TRUNC(SUBSCRIBED_AT)=TRUNC(SYSDATE) THEN 1 END),
           COUNT(CASE WHEN SUBSCRIBED_AT>=TRUNC(SYSDATE)-6 THEN 1 END),
           COUNT(CASE WHEN SUBSCRIBED_AT>=TRUNC(SYSDATE,'MM') THEN 1 END),
           COUNT(CASE WHEN USER_ID IS NOT NULL THEN 1 END)
      INTO n1,n2,n3,n4,n5,n6,n7
      FROM "NEWSLETTER_SUBSCRIBERS";
    SELECT COUNT(*), COUNT(CASE WHEN STATUS='sent' THEN 1 END)
      INTO n8,n9 FROM "NEWSLETTER_CAMPAIGNS";
    APEX_JSON.open_object;
      APEX_JSON.write('total',n1);        APEX_JSON.write('active',n2);
      APEX_JSON.write('unsubscribed',n3); APEX_JSON.write('today',n4);
      APEX_JSON.write('week',n5);         APEX_JSON.write('month',n6);
      APEX_JSON.write('registered',n7);   APEX_JSON.write('campaigns',n8);
      APEX_JSON.write('sent',n9);
    APEX_JSON.close_object;
    RETURN;
  END IF;

  -- ------------------- قائمة المشتركين -------------------
  IF l_act = 'list' THEN
    APEX_JSON.open_object; APEX_JSON.open_array('rows');
    FOR r IN (
      SELECT * FROM (
        SELECT ID, EMAIL, FULL_NAME, STATUS, SOURCE, USER_ID,
               TO_CHAR(SUBSCRIBED_AT,'YYYY-MM-DD HH24:MI') SUB_AT
        FROM "NEWSLETTER_SUBSCRIBERS"
        WHERE (l_p2 IS NULL OR LOWER(EMAIL) LIKE '%'||LOWER(l_p2)||'%'
               OR LOWER(FULL_NAME) LIKE '%'||LOWER(l_p2)||'%')
          AND (l_p3 IS NULL OR l_p3='all' OR STATUS=l_p3)
        ORDER BY ID DESC
      ) WHERE ROWNUM <= 300
    ) LOOP
      APEX_JSON.open_object;
        APEX_JSON.write('id', r.ID);           APEX_JSON.write('email', r.EMAIL);
        APEX_JSON.write('name', r.FULL_NAME);  APEX_JSON.write('status', r.STATUS);
        APEX_JSON.write('source', r.SOURCE);   APEX_JSON.write('at', r.SUB_AT);
        APEX_JSON.write('registered', CASE WHEN r.USER_ID IS NOT NULL THEN 1 ELSE 0 END);
      APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array; APEX_JSON.close_object;
    RETURN;
  END IF;

  -- ------------------- إضافة مشترك -------------------
  IF l_act = 'add' THEN
    l_p2 := LOWER(TRIM(l_p2));
    IF l_p2 IS NULL OR INSTR(l_p2,'@')=0 THEN
      APEX_JSON.open_object; APEX_JSON.write('success',FALSE); APEX_JSON.write('error','بريد غير صحيح'); APEX_JSON.close_object; RETURN;
    END IF;
    MERGE INTO "NEWSLETTER_SUBSCRIBERS" t
    USING (SELECT l_p2 em FROM dual) s ON (LOWER(t.EMAIL)=s.em)
    WHEN MATCHED THEN UPDATE SET STATUS='active', UNSUBSCRIBED_AT=NULL, FULL_NAME=NVL(l_p3,t.FULL_NAME)
    WHEN NOT MATCHED THEN INSERT (EMAIL,FULL_NAME,STATUS,CONFIRM_TOKEN,SOURCE)
                          VALUES (l_p2,l_p3,'active',RAWTOHEX(SYS_GUID()),'admin');
    COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  -- ------------------- تغيير الحالة -------------------
  IF l_act = 'setstatus' THEN
    UPDATE "NEWSLETTER_SUBSCRIBERS"
       SET STATUS=l_p3, UNSUBSCRIBED_AT = CASE WHEN l_p3='unsubscribed' THEN SYSTIMESTAMP ELSE NULL END
     WHERE ID = TO_NUMBER(l_p2);
    COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  -- ------------------- حذف -------------------
  IF l_act = 'delete' THEN
    DELETE FROM "NEWSLETTER_SUBSCRIBERS" WHERE ID = TO_NUMBER(l_p2);
    COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object; RETURN;
  END IF;

  -- ------------------- قائمة النشرات -------------------
  IF l_act = 'campaigns' THEN
    APEX_JSON.open_object; APEX_JSON.open_array('rows');
    FOR r IN (SELECT ID, SUBJECT, STATUS, RECIPIENTS, SENT_COUNT, FAIL_COUNT,
                     TO_CHAR(CREATED_AT,'YYYY-MM-DD HH24:MI') CR,
                     TO_CHAR(SENT_AT,'YYYY-MM-DD HH24:MI') SN
              FROM "NEWSLETTER_CAMPAIGNS" ORDER BY ID DESC) LOOP
      APEX_JSON.open_object;
        APEX_JSON.write('id',r.ID);            APEX_JSON.write('subject',r.SUBJECT);
        APEX_JSON.write('status',r.STATUS);    APEX_JSON.write('recipients',r.RECIPIENTS);
        APEX_JSON.write('sent',r.SENT_COUNT);  APEX_JSON.write('fail',r.FAIL_COUNT);
        APEX_JSON.write('created',r.CR);       APEX_JSON.write('sent_at',r.SN);
      APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array; APEX_JSON.close_object;
    RETURN;
  END IF;

  -- ------------------- حفظ نشرة (مسودة) -------------------
  IF l_act = 'savecampaign' THEN
    IF l_p2 IS NOT NULL AND l_p2 <> '' THEN
      UPDATE "NEWSLETTER_CAMPAIGNS" SET SUBJECT=l_p3, BODY_HTML=l_body
       WHERE ID=TO_NUMBER(l_p2) AND STATUS='draft' RETURNING ID INTO l_id;
    ELSE
      INSERT INTO "NEWSLETTER_CAMPAIGNS" (SUBJECT, BODY_HTML, STATUS, CREATED_BY)
      VALUES (l_p3, l_body, 'draft', NVL(V('APP_USER'),'admin')) RETURNING ID INTO l_id;
    END IF;
    COMMIT;
    APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.write('id',l_id); APEX_JSON.close_object;
    RETURN;
  END IF;

  -- ------------------- إرسال نشرة -------------------
  IF l_act = 'send' THEN
    -- يستدعي NL_SEND_CAMPAIGN (يُنشأ من ملف إعداد M365) ديناميكياً
    BEGIN
      EXECUTE IMMEDIATE 'BEGIN NL_SEND_CAMPAIGN(:1); END;' USING TO_NUMBER(l_p2);
      APEX_JSON.open_object; APEX_JSON.write('success',TRUE); APEX_JSON.close_object;
    EXCEPTION WHEN OTHERS THEN
      APEX_JSON.open_object; APEX_JSON.write('success',FALSE);
      APEX_JSON.write('error', SUBSTR(SQLERRM,1,300)); APEX_JSON.close_object;
    END;
    RETURN;
  END IF;

  APEX_JSON.open_object; APEX_JSON.write('success',FALSE); APEX_JSON.write('error','إجراء غير معروف'); APEX_JSON.close_object;
END;
