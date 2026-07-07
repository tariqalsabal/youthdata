-- ============================================================
-- معالج AJAX للوحة الإحصاءات — يُرجع كل البيانات كـ JSON واحد
-- النوع: Ajax Callback  |  الاسم: GET_DASHBOARD
-- المصدر: جدول USERS + USER_SESSIONS (سكيمة DATA_CENTER)
-- ============================================================
DECLARE
  c SYS_REFCURSOR;

  -- مؤشرات جدول USERS
  u_total NUMBER; u_today NUMBER; u_yest NUMBER; u_week NUMBER; u_month NUMBER;
  u_active NUMBER; u_google NUMBER; u_local NUMBER; u_avatar NUMBER; u_phone NUMBER;
  u_male NUMBER; u_female NUMBER; u_countries NUMBER; u_cities NUMBER; u_univ NUMBER;

  -- مؤشرات جدول USER_SESSIONS
  s_total NUMBER; s_active NUMBER; s_today NUMBER; s_week NUMBER; s_month NUMBER;
  s_last24 NUMBER; s_uniq7 NUMBER; s_uniq30 NUMBER; s_ips NUMBER;

  -- يكتب مصفوفة {label,value} من مؤشر يعيد عمودين (نص، رقم)
  PROCEDURE wr_arr(p_name VARCHAR2, p_cur IN OUT SYS_REFCURSOR) IS
    l_label VARCHAR2(400);
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
  -- حساب مؤشرات USERS في استعلام واحد
  SELECT
    COUNT(*),
    COUNT(CASE WHEN TRUNC("تاريخ_التسجيل") = TRUNC(SYSDATE)   THEN 1 END),
    COUNT(CASE WHEN TRUNC("تاريخ_التسجيل") = TRUNC(SYSDATE)-1 THEN 1 END),
    COUNT(CASE WHEN "تاريخ_التسجيل" >= TRUNC(SYSDATE)-6       THEN 1 END),
    COUNT(CASE WHEN "تاريخ_التسجيل" >= TRUNC(SYSDATE,'MM')    THEN 1 END),
    COUNT(CASE WHEN "حالة_الحساب" = 'نشط'                     THEN 1 END),
    COUNT(CASE WHEN "كلمة_المرور" IS NULL                     THEN 1 END),
    COUNT(CASE WHEN "كلمة_المرور" IS NOT NULL                 THEN 1 END),
    COUNT(CASE WHEN "صورة_الملف_الشخصي" IS NOT NULL           THEN 1 END),
    COUNT(CASE WHEN "رقم_الهاتف" IS NOT NULL                  THEN 1 END),
    COUNT(CASE WHEN "الجنس" IN ('ذكر','Male','male','M')      THEN 1 END),
    COUNT(CASE WHEN "الجنس" IN ('أنثى','Female','female','F') THEN 1 END),
    COUNT(DISTINCT "البلد"),
    COUNT(DISTINCT "المدينة"),
    COUNT(DISTINCT "الجامعة")
  INTO u_total, u_today, u_yest, u_week, u_month, u_active, u_google, u_local,
       u_avatar, u_phone, u_male, u_female, u_countries, u_cities, u_univ
  FROM "USERS";

  -- حساب مؤشرات USER_SESSIONS في استعلام واحد
  SELECT
    COUNT(*),
    COUNT(CASE WHEN IS_ACTIVE = 1 AND EXPIRES_AT > SYSTIMESTAMP THEN 1 END),
    COUNT(CASE WHEN TRUNC(CREATED_AT) = TRUNC(SYSDATE)          THEN 1 END),
    COUNT(CASE WHEN CREATED_AT >= TRUNC(SYSDATE)-6              THEN 1 END),
    COUNT(CASE WHEN CREATED_AT >= TRUNC(SYSDATE,'MM')           THEN 1 END),
    COUNT(CASE WHEN CREATED_AT >= SYSTIMESTAMP - INTERVAL '24' HOUR THEN 1 END),
    COUNT(DISTINCT CASE WHEN CREATED_AT >= TRUNC(SYSDATE)-6  THEN USER_ID END),
    COUNT(DISTINCT CASE WHEN CREATED_AT >= TRUNC(SYSDATE)-29 THEN USER_ID END),
    COUNT(DISTINCT IP_ADDRESS)
  INTO s_total, s_active, s_today, s_week, s_month, s_last24, s_uniq7, s_uniq30, s_ips
  FROM "USER_SESSIONS";

  APEX_JSON.open_object;

  -- ============ مؤشرات رقمية (KPIs) ============
  APEX_JSON.open_object('kpis');
    APEX_JSON.write('total_users',       u_total);
    APEX_JSON.write('today',             u_today);
    APEX_JSON.write('yesterday',         u_yest);
    APEX_JSON.write('week',              u_week);
    APEX_JSON.write('month',             u_month);
    APEX_JSON.write('active_accounts',   u_active);
    APEX_JSON.write('google_users',      u_google);
    APEX_JSON.write('local_users',       u_local);
    APEX_JSON.write('with_avatar',       u_avatar);
    APEX_JSON.write('with_phone',        u_phone);
    APEX_JSON.write('males',             u_male);
    APEX_JSON.write('females',           u_female);
    APEX_JSON.write('countries_count',   u_countries);
    APEX_JSON.write('cities_count',      u_cities);
    APEX_JSON.write('universities_count',u_univ);
    APEX_JSON.write('total_sessions',    s_total);
    APEX_JSON.write('active_sessions',   s_active);
    APEX_JSON.write('logins_today',      s_today);
    APEX_JSON.write('logins_week',       s_week);
    APEX_JSON.write('logins_month',      s_month);
    APEX_JSON.write('last_24h_logins',   s_last24);
    APEX_JSON.write('unique_logins_7d',  s_uniq7);
    APEX_JSON.write('unique_logins_30d', s_uniq30);
    APEX_JSON.write('distinct_ips',      s_ips);
  APEX_JSON.close_object;

  -- ============ مصفوفات المخططات ============

  OPEN c FOR SELECT "نوع_المستخدم", COUNT(*) FROM "USERS" GROUP BY "نوع_المستخدم" ORDER BY 2 DESC;
  wr_arr('by_type', c);

  OPEN c FOR SELECT "الجنس", COUNT(*) FROM "USERS" GROUP BY "الجنس" ORDER BY 2 DESC;
  wr_arr('by_gender', c);

  OPEN c FOR SELECT "حالة_الحساب", COUNT(*) FROM "USERS" GROUP BY "حالة_الحساب" ORDER BY 2 DESC;
  wr_arr('by_status', c);

  OPEN c FOR SELECT "البلد", COUNT(*) FROM "USERS" WHERE "البلد" IS NOT NULL
             GROUP BY "البلد" ORDER BY 2 DESC FETCH FIRST 8 ROWS ONLY;
  wr_arr('by_country', c);

  OPEN c FOR SELECT "المدينة", COUNT(*) FROM "USERS" WHERE "المدينة" IS NOT NULL
             GROUP BY "المدينة" ORDER BY 2 DESC FETCH FIRST 10 ROWS ONLY;
  wr_arr('by_city', c);

  OPEN c FOR SELECT "الجامعة", COUNT(*) FROM "USERS" WHERE "الجامعة" IS NOT NULL
             GROUP BY "الجامعة" ORDER BY 2 DESC FETCH FIRST 8 ROWS ONLY;
  wr_arr('by_university', c);

  OPEN c FOR SELECT "الدرجة_العلمية", COUNT(*) FROM "USERS" WHERE "الدرجة_العلمية" IS NOT NULL
             GROUP BY "الدرجة_العلمية" ORDER BY 2 DESC;
  wr_arr('by_degree', c);

  OPEN c FOR SELECT "مجال_البحث", COUNT(*) FROM "USERS" WHERE "مجال_البحث" IS NOT NULL
             GROUP BY "مجال_البحث" ORDER BY 2 DESC FETCH FIRST 8 ROWS ONLY;
  wr_arr('by_research', c);

  OPEN c FOR SELECT "التخصص", COUNT(*) FROM "USERS" WHERE "التخصص" IS NOT NULL
             GROUP BY "التخصص" ORDER BY 2 DESC FETCH FIRST 8 ROWS ONLY;
  wr_arr('by_specialty', c);

  -- الفئات العمرية
  OPEN c FOR
    SELECT grp, COUNT(*) FROM (
      SELECT CASE
               WHEN age < 18 THEN 'أقل من 18'
               WHEN age BETWEEN 18 AND 24 THEN '18 - 24'
               WHEN age BETWEEN 25 AND 34 THEN '25 - 34'
               WHEN age BETWEEN 35 AND 44 THEN '35 - 44'
               ELSE '45 فأكثر'
             END grp,
             CASE
               WHEN age < 18 THEN 1 WHEN age BETWEEN 18 AND 24 THEN 2
               WHEN age BETWEEN 25 AND 34 THEN 3 WHEN age BETWEEN 35 AND 44 THEN 4 ELSE 5 END srt
      FROM ( SELECT FLOOR(MONTHS_BETWEEN(SYSDATE,"تاريخ_الميلاد")/12) age
             FROM "USERS" WHERE "تاريخ_الميلاد" IS NOT NULL )
    ) GROUP BY grp, srt ORDER BY srt;
  wr_arr('age_groups', c);

  -- التسجيلات آخر 30 يوماً
  OPEN c FOR SELECT TO_CHAR(TRUNC("تاريخ_التسجيل"),'YYYY-MM-DD'), COUNT(*)
             FROM "USERS" WHERE "تاريخ_التسجيل" >= TRUNC(SYSDATE)-29
             GROUP BY TRUNC("تاريخ_التسجيل") ORDER BY TRUNC("تاريخ_التسجيل");
  wr_arr('reg_timeline', c);

  -- تسجيلات الدخول آخر 30 يوماً
  OPEN c FOR SELECT TO_CHAR(TRUNC(CREATED_AT),'YYYY-MM-DD'), COUNT(*)
             FROM "USER_SESSIONS" WHERE CREATED_AT >= TRUNC(SYSDATE)-29
             GROUP BY TRUNC(CREATED_AT) ORDER BY TRUNC(CREATED_AT);
  wr_arr('login_timeline', c);

  -- التسجيل حسب ساعة اليوم
  OPEN c FOR SELECT TO_CHAR(TO_NUMBER(TO_CHAR("تاريخ_التسجيل",'HH24'))), COUNT(*)
             FROM "USERS" GROUP BY TO_NUMBER(TO_CHAR("تاريخ_التسجيل",'HH24')) ORDER BY 1;
  wr_arr('reg_by_hour', c);

  -- تسجيل الدخول حسب ساعة اليوم (الأوقات)
  OPEN c FOR SELECT TO_CHAR(TO_NUMBER(TO_CHAR(CREATED_AT,'HH24'))), COUNT(*)
             FROM "USER_SESSIONS" GROUP BY TO_NUMBER(TO_CHAR(CREATED_AT,'HH24')) ORDER BY 1;
  wr_arr('login_by_hour', c);

  -- تسجيل الدخول حسب يوم الأسبوع (0=الاثنين .. 6=الأحد)
  OPEN c FOR SELECT TO_CHAR(TRUNC(CREATED_AT) - TRUNC(CREATED_AT,'IW')), COUNT(*)
             FROM "USER_SESSIONS" GROUP BY (TRUNC(CREATED_AT) - TRUNC(CREATED_AT,'IW')) ORDER BY 1;
  wr_arr('login_by_weekday', c);

  -- أكثر المستخدمين نشاطاً
  OPEN c FOR SELECT NVL(u."الاسم_الكامل", u."اسم_المستخدم"), COUNT(s.SESSION_ID)
             FROM "USERS" u JOIN "USER_SESSIONS" s ON s.USER_ID = u."ID"
             GROUP BY NVL(u."الاسم_الكامل", u."اسم_المستخدم")
             ORDER BY 2 DESC FETCH FIRST 8 ROWS ONLY;
  wr_arr('top_users', c);

  APEX_JSON.close_object;
END;
