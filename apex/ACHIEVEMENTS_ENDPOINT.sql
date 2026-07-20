-- ============================================================
-- نقطة عرض منجزات الشباب السعودي (وحدة AUTH_API — مسار /auth/cms/)
--   GET /auth/cms/achievements            كل المنجزات المنشورة لأحدث سنة
--   GET /auth/cms/achievements?year=2025&category=awards
-- يُعاد تشغيله بأمان (ORDS.DEFINE_* تحدّث الموجود).
-- ============================================================
BEGIN
  ORDS.DEFINE_TEMPLATE(p_module_name => 'AUTH_API', p_pattern => 'cms/achievements');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'AUTH_API',
    p_pattern     => 'cms/achievements',
    p_method      => 'GET',
    p_source_type => ORDS.source_type_plsql,
    p_source      => q'~
DECLARE
  l_year NUMBER;
  l_cat  VARCHAR2(40) := :category;
BEGIN
  OWA_UTIL.mime_header('application/json', FALSE, 'UTF-8');
  HTP.p('Access-Control-Allow-Origin: *');
  OWA_UTIL.http_header_close;

  -- السنة: المطلوبة أو الأحدث المتاحة
  BEGIN
    l_year := TO_NUMBER(:year);
  EXCEPTION WHEN OTHERS THEN l_year := NULL;
  END;
  IF l_year IS NULL THEN
    SELECT NVL(MAX("YEAR_NO"), 2025) INTO l_year
    FROM "YOUTH_ACHIEVEMENTS" WHERE "IS_PUBLISHED" = 1;
  END IF;

  APEX_JSON.initialize_clob_output;
  APEX_JSON.open_object;
    APEX_JSON.write('year', l_year);

    -- السنوات المتاحة (لعنصر التصفية)
    APEX_JSON.open_array('years');
    FOR r IN (SELECT DISTINCT "YEAR_NO" y FROM "YOUTH_ACHIEVEMENTS"
              WHERE "IS_PUBLISHED"=1 ORDER BY y DESC) LOOP
      APEX_JSON.write(r.y);
    END LOOP;
    APEX_JSON.close_array;

    -- الأرقام البارزة (المميّزة التي لها رقم) — لشريط الإحصاءات
    APEX_JSON.open_array('stats');
    FOR r IN (SELECT a."FIGURE_VALUE" v, a."FIGURE_LABEL" l, a."CATEGORY" c, c."COLOR" col
              FROM "YOUTH_ACHIEVEMENTS" a JOIN "ACHIEVEMENT_CATEGORIES" c ON c."CODE"=a."CATEGORY"
              WHERE a."IS_PUBLISHED"=1 AND a."YEAR_NO"=l_year
                AND a."IS_FEATURED"=1 AND a."FIGURE_VALUE" IS NOT NULL
              ORDER BY c."DISPLAY_ORDER", a."DISPLAY_ORDER") LOOP
      APEX_JSON.open_object;
        APEX_JSON.write('value', r.v);
        APEX_JSON.write('label', r.l);
        APEX_JSON.write('category', r.c);
        APEX_JSON.write('color', r.col);
      APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array;

    -- التصنيفات مع عدد المنجزات
    APEX_JSON.open_array('categories');
    FOR r IN (SELECT c."CODE", c."NAME_AR", c."ICON", c."COLOR",
                     (SELECT COUNT(*) FROM "YOUTH_ACHIEVEMENTS" a
                      WHERE a."CATEGORY"=c."CODE" AND a."IS_PUBLISHED"=1 AND a."YEAR_NO"=l_year) cnt
              FROM "ACHIEVEMENT_CATEGORIES" c ORDER BY c."DISPLAY_ORDER") LOOP
      IF r.cnt > 0 THEN
        APEX_JSON.open_object;
          APEX_JSON.write('code', r."CODE");
          APEX_JSON.write('name', r."NAME_AR");
          APEX_JSON.write('icon', r."ICON");
          APEX_JSON.write('color', r."COLOR");
          APEX_JSON.write('count', r.cnt);
        APEX_JSON.close_object;
      END IF;
    END LOOP;
    APEX_JSON.close_array;

    -- المنجزات
    APEX_JSON.open_array('items');
    FOR r IN (SELECT a."ID", a."CATEGORY", a."TITLE", a."SUMMARY",
                     a."FIGURE_VALUE", a."FIGURE_LABEL", a."SOURCE_URL", a."IS_FEATURED",
                     c."NAME_AR" cat_name, c."ICON" icon, c."COLOR" color
              FROM "YOUTH_ACHIEVEMENTS" a JOIN "ACHIEVEMENT_CATEGORIES" c ON c."CODE"=a."CATEGORY"
              WHERE a."IS_PUBLISHED"=1 AND a."YEAR_NO"=l_year
                AND (l_cat IS NULL OR l_cat='all' OR a."CATEGORY"=l_cat)
              ORDER BY c."DISPLAY_ORDER", a."DISPLAY_ORDER", a."ID") LOOP
      APEX_JSON.open_object;
        APEX_JSON.write('id', r."ID");
        APEX_JSON.write('category', r."CATEGORY");
        APEX_JSON.write('categoryName', r.cat_name);
        APEX_JSON.write('icon', r.icon);
        APEX_JSON.write('color', r.color);
        APEX_JSON.write('title', r."TITLE");
        APEX_JSON.write('summary', r."SUMMARY");
        APEX_JSON.write('figureValue', r."FIGURE_VALUE");
        APEX_JSON.write('figureLabel', r."FIGURE_LABEL");
        APEX_JSON.write('sourceUrl', r."SOURCE_URL");
        APEX_JSON.write('featured', CASE WHEN r."IS_FEATURED"=1 THEN TRUE ELSE FALSE END);
      APEX_JSON.close_object;
    END LOOP;
    APEX_JSON.close_array;
  APEX_JSON.close_object;

  HTP.p(APEX_JSON.get_clob_output);
  APEX_JSON.free_output;
END;
~');
  COMMIT;
END;
/
