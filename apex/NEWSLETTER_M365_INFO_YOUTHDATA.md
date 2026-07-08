# إعدادات الإرسال عبر بريد المنصة info@youthdata.sa

## المتطلبات (مرة واحدة)
1. **نطاق `youthdata.sa` مُوثّق** في مركز إدارة Microsoft 365 (Settings → Domains) مع سجلّات DNS.
2. **صندوق `info@youthdata.sa` موجود** (مستخدم مُرخّص، أو Shared Mailbox — الأخير يعمل مع Graph دون ترخيص).
3. **تطبيق Entra** بصلاحية `Mail.Send` (Application) + **Grant admin consent** — راجع `NEWSLETTER_M365_SETUP.md`.
4. (موصى به بشدة) **تقييد التطبيق** ليُرسل من هذا الصندوق فقط:
   ```powershell
   # في Exchange Online PowerShell
   New-DistributionGroup -Name "NewsletterSenders" -Type Security -Members info@youthdata.sa
   New-ApplicationAccessPolicy -AppId <CLIENT_ID> -PolicyScopeGroupId NewsletterSenders `
     -AccessRight RestrictAccess -Description "Youth Data newsletter - info@youthdata.sa only"
   ```
5. (موصى به للتسليم) تفعيل **DKIM** لنطاق `youthdata.sa` من بوابة Defender، والتأكد من **SPF** (يضيفه M365).

## صلاحية الشبكة (ACL) في قاعدة البيانات
```sql
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(host=>'login.microsoftonline.com',
    ace=>xs$ace_type(privilege_list=>xs$name_list('http'),principal_name=>'DATA_CENTER',principal_type=>xs_acl.ptype_db));
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(host=>'graph.microsoft.com',
    ace=>xs$ace_type(privilege_list=>xs$name_list('http'),principal_name=>'DATA_CENTER',principal_type=>xs_acl.ptype_db));
END;
/
```

## إدخال إعدادات الإرسال (الأساسي — Graph)
```sql
UPDATE "NEWSLETTER_CONFIG" SET
  TENANT_ID     = '<Directory (tenant) ID من Entra>',
  CLIENT_ID     = '<Application (client) ID>',
  CLIENT_SECRET = '<قيمة Client secret>',
  SENDER_EMAIL  = 'info@youthdata.sa',
  FROM_NAME     = 'منصة بيانات الشباب',
  SITE_URL      = 'https://youth-data-platform.vercel.app'
WHERE ID = 1;
COMMIT;
```
> بعدها: أنشئ إجراء `NL_SEND_CAMPAIGN` (من `NEWSLETTER_M365_SETUP.md`)، وزر «إرسال» في اللوحة يعمل ويُرسل من `info@youthdata.sa`.

## اختبار سريع للاتصال (اختياري)
```sql
DECLARE l_resp CLOB; l_tok VARCHAR2(4000); c "NEWSLETTER_CONFIG"%ROWTYPE;
BEGIN
  SELECT * INTO c FROM "NEWSLETTER_CONFIG" WHERE ID=1;
  apex_web_service.g_request_headers.delete;
  apex_web_service.g_request_headers(1).name := 'Content-Type';
  apex_web_service.g_request_headers(1).value := 'application/x-www-form-urlencoded';
  l_resp := apex_web_service.make_rest_request(
    p_url=>'https://login.microsoftonline.com/'||c.TENANT_ID||'/oauth2/v2.0/token',
    p_http_method=>'POST',
    p_body=>'client_id='||c.CLIENT_ID||'&client_secret='||utl_url.escape(c.CLIENT_SECRET,TRUE)
           ||'&scope='||utl_url.escape('https://graph.microsoft.com/.default',TRUE)||'&grant_type=client_credentials');
  apex_json.parse(l_resp);
  l_tok := apex_json.get_varchar2('access_token');
  DBMS_OUTPUT.put_line( CASE WHEN l_tok IS NOT NULL THEN 'OK: تم الاتصال بنجاح' ELSE 'خطأ: '||SUBSTR(l_resp,1,400) END );
END;
/
```

---

## بديل: SMTP (فقط إن فعّلت SMTP AUTH للصندوق)
> مايكروسوفت تُقاعِد المصادقة الأساسية لـ SMTP؛ Graph أعلاه هو المُوصى به. لكن إن رغبت بـ APEX_MAIL:

| الإعداد | القيمة |
|---|---|
| SMTP Host | `smtp.office365.com` |
| Port | `587` |
| Security | `STARTTLS` |
| Username | `info@youthdata.sa` |
| Password | كلمة مرور الصندوق (أو App Password عند تفعيل MFA) |

يُضبط في APEX: **Administration → Instance Settings → Email**. ويجب تفعيل **SMTP AUTH** لهذا الصندوق من مركز إدارة Exchange.
