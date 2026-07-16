-- ============================================================
-- معالج AJAX للوحة تحليلات الزيارات والبحث
-- النوع: Ajax Callback  |  الاسم: GET_ANALYTICS
-- المصدر: VISITS + SEARCH_LOG
-- ============================================================
DECLARE
  c SYS_REFCURSOR;

  v_total NUMBER; v_today NUMBER; v_yest NUMBER; v_week NUMBER; v_month NUMBER;
  v_uniq NUMBER; v_uniq_today NUMBER; v_sessions NUMBER;
  v_reg NUMBER; v_guest NUMBER; v_countries NUMBER; v_regions NUMBER;
  s_total NUMBER; s_uniq NUMBER; s_zero NUMBER; s_today NUMBER;

  PROCEDURE wr_arr(p_name VARCHAR2, p_cur IN OUT SYS_REFCURSOR) IS
    l_label VARCHAR2(500);
    l_value NUMBER;
  BEGIN
    APEX_JSON.open_array(p_name);
    LOOP
      FETCH p_cur INTO l_label, l_value;
      EXIT WHEN p_cur%NOTFOUND;
      APEX_JSON.open_object;
      APEX_JSON.write('label', NVL(TRIM(l_label), 'غير محدد'));
      APEX_JSON.write('value', l_value);
      APEX_JSON.close_object;
    END LOOP;
    CLOSE p_cur;
    APEX_JSON.close_array;
  END wr_arr;
BEGIN
  -- مؤشرات الزيارات
  SELECT COUNT(*),
         COUNT(CASE WHEN TRUNC("VISITED_AT") = TRUNC(SYSDATE)   THEN 1 END),
         COUNT(CASE WHEN TRUNC("VISITED_AT") = TRUNC(SYSDATE)-1 THEN 1 END),
         COUNT(CASE WHEN "VISITED_AT" >= TRUNC(SYSDATE)-6       THEN 1 END),
         COUNT(CASE WHEN "VISITED_AT" >= TRUNC(SYSDATE,'MM')    THEN 1 END),
         COUNT(DISTINCT "VISITOR_ID"),
         COUNT(DISTINCT CASE WHEN TRUNC("VISITED_AT") = TRUNC(SYSDATE) THEN "VISITOR_ID" END),
         COUNT(DISTINCT "SESSION_KEY"),
         COUNT(CASE WHEN "IS_REGISTERED" = 1 THEN 1 END),
         COUNT(CASE WHEN "IS_REGISTERED" = 0 THEN 1 END),
         COUNT(DISTINCT "COUNTRY_CODE"),
         COUNT(DISTINCT CASE WHEN "COUNTRY_CODE" = 'SA' THEN "REGION_NAME" END)
    INTO v_total, v_today, v_yest, v_week, v_month, v_uniq, v_uniq_today,
         v_sessions, v_reg, v_guest, v_countries, v_regions
    FROM "VISITS";

  -- مؤشرات البحث
  SELECT COUNT(*), COUNT(DISTINCT "TERM_NORM"),
         COUNT(CASE WHEN "RESULTS_CNT" = 0 THEN 1 END),
         COUNT(CASE WHEN TRUNC("SEARCHED_AT") = TRUNC(SYSDATE) THEN 1 END)
    INTO s_total, s_uniq, s_zero, s_today
    FROM "SEARCH_LOG";

  APEX_JSON.open_object;

  APEX_JSON.open_object('kpis');
    APEX_JSON.write('total_visits',   v_total);
    APEX_JSON.write('today',          v_today);
    APEX_JSON.write('yesterday',      v_yest);
    APEX_JSON.write('week',           v_week);
    APEX_JSON.write('month',          v_month);
    APEX_JSON.write('unique_visitors',v_uniq);
    APEX_JSON.write('unique_today',   v_uniq_today);
    APEX_JSON.write('sessions',       v_sessions);
    APEX_JSON.write('registered',     v_reg);
    APEX_JSON.write('guests',         v_guest);
    APEX_JSON.write('countries',      v_countries);
    APEX_JSON.write('sa_regions',     v_regions);
    APEX_JSON.write('searches',       s_total);
    APEX_JSON.write('unique_terms',   s_uniq);
    APEX_JSON.write('zero_results',   s_zero);
    APEX_JSON.write('searches_today', s_today);
  APEX_JSON.close_object;

  -- الزيارات آخر 30 يوماً
  OPEN c FOR SELECT TO_CHAR(TRUNC("VISITED_AT"),'YYYY-MM-DD'), COUNT(*)
             FROM "VISITS" WHERE "VISITED_AT" >= TRUNC(SYSDATE)-29
             GROUP BY TRUNC("VISITED_AT") ORDER BY TRUNC("VISITED_AT");
  wr_arr('visits_timeline', c);

  -- أكثر الصفحات زيارة (المسار الكامل)
  OPEN c FOR SELECT "PAGE_PATH", COUNT(*) FROM "VISITS"
             WHERE "PAGE_PATH" IS NOT NULL
             GROUP BY "PAGE_PATH" ORDER BY 2 DESC FETCH FIRST 12 ROWS ONLY;
  wr_arr('top_pages', c);

  -- أكثر الأقسام زيارة (النمط)
  OPEN c FOR SELECT "PAGE_PATTERN", COUNT(*) FROM "VISITS"
             WHERE "PAGE_PATTERN" IS NOT NULL
             GROUP BY "PAGE_PATTERN" ORDER BY 2 DESC FETCH FIRST 10 ROWS ONLY;
  wr_arr('top_sections', c);

  -- مناطق السعودية
  OPEN c FOR SELECT "REGION_NAME", COUNT(*) FROM "VISITS"
             WHERE "COUNTRY_CODE" = 'SA' AND "REGION_NAME" IS NOT NULL
             GROUP BY "REGION_NAME" ORDER BY 2 DESC;
  wr_arr('sa_regions', c);

  -- أعلى المدن (السعودية)
  OPEN c FOR SELECT "CITY", COUNT(*) FROM "VISITS"
             WHERE "COUNTRY_CODE" = 'SA' AND "CITY" IS NOT NULL
             GROUP BY "CITY" ORDER BY 2 DESC FETCH FIRST 10 ROWS ONLY;
  wr_arr('sa_cities', c);

  -- الدول
  OPEN c FOR SELECT "COUNTRY_CODE", COUNT(*) FROM "VISITS"
             WHERE "COUNTRY_CODE" IS NOT NULL
             GROUP BY "COUNTRY_CODE" ORDER BY 2 DESC FETCH FIRST 10 ROWS ONLY;
  wr_arr('by_country', c);

  -- الأجهزة / المتصفحات / الأنظمة
  OPEN c FOR SELECT "DEVICE_TYPE", COUNT(*) FROM "VISITS" GROUP BY "DEVICE_TYPE" ORDER BY 2 DESC;
  wr_arr('by_device', c);
  OPEN c FOR SELECT "BROWSER", COUNT(*) FROM "VISITS" GROUP BY "BROWSER" ORDER BY 2 DESC;
  wr_arr('by_browser', c);
  OPEN c FOR SELECT "OS", COUNT(*) FROM "VISITS" GROUP BY "OS" ORDER BY 2 DESC;
  wr_arr('by_os', c);

  -- الزيارات حسب ساعة اليوم / يوم الأسبوع
  OPEN c FOR SELECT TO_CHAR(TO_NUMBER(TO_CHAR("VISITED_AT",'HH24'))), COUNT(*)
             FROM "VISITS" GROUP BY TO_NUMBER(TO_CHAR("VISITED_AT",'HH24')) ORDER BY 1;
  wr_arr('by_hour', c);
  OPEN c FOR SELECT TO_CHAR(TRUNC("VISITED_AT") - TRUNC("VISITED_AT",'IW')), COUNT(*)
             FROM "VISITS" GROUP BY (TRUNC("VISITED_AT") - TRUNC("VISITED_AT",'IW')) ORDER BY 1;
  wr_arr('by_weekday', c);

  -- أكثر الكلمات بحثاً
  OPEN c FOR SELECT "TERM_NORM", COUNT(*) FROM "SEARCH_LOG"
             WHERE "TERM_NORM" IS NOT NULL
             GROUP BY "TERM_NORM" ORDER BY 2 DESC FETCH FIRST 15 ROWS ONLY;
  wr_arr('top_terms', c);

  -- كلمات بحث بلا نتائج (فرص محتوى)
  OPEN c FOR SELECT "TERM_NORM", COUNT(*) FROM "SEARCH_LOG"
             WHERE "RESULTS_CNT" = 0 AND "TERM_NORM" IS NOT NULL
             GROUP BY "TERM_NORM" ORDER BY 2 DESC FETCH FIRST 10 ROWS ONLY;
  wr_arr('zero_terms', c);

  -- عمليات البحث آخر 30 يوماً
  OPEN c FOR SELECT TO_CHAR(TRUNC("SEARCHED_AT"),'YYYY-MM-DD'), COUNT(*)
             FROM "SEARCH_LOG" WHERE "SEARCHED_AT" >= TRUNC(SYSDATE)-29
             GROUP BY TRUNC("SEARCHED_AT") ORDER BY TRUNC("SEARCHED_AT");
  wr_arr('search_timeline', c);

  APEX_JSON.close_object;
END;
