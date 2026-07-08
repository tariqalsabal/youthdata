# إعداد الإرسال عبر Microsoft 365 (Graph API)

يمكّن الطرف الخلفي من إرسال النشرة من بريدك في M365 دون رسوم إضافية.

## أ) تسجيل تطبيق في Entra ID (Azure AD) — مرة واحدة

1. [entra.microsoft.com](https://entra.microsoft.com) → **App registrations → New registration**.
   - الاسم: `YouthData Newsletter` — النوع: Single tenant → Register.
2. من صفحة التطبيق انسخ: **Application (client) ID** و **Directory (tenant) ID**.
3. **Certificates & secrets → New client secret** → انسخ **قيمة** السر فوراً.
4. **API permissions → Add a permission → Microsoft Graph → Application permissions →** ابحث عن **`Mail.Send`** → Add.
   ثم اضغط **Grant admin consent** (يتطلب حساب مدير — لديك Business Premium).
5. تأكّد أن بريد المُرسِل (`SENDER_EMAIL`) صندوق بريد مُرخّص فعّال.

> **أمان (موصى به):** بشكل افتراضي يمكن للتطبيق الإرسال باسم أي مستخدم. لتقييده ببريد واحد،
> شغّل في Exchange Online PowerShell:
> ```powershell
> New-DistributionGroup -Name "NewsletterSenders" -Type Security -Members newsletter@yourdomain.com
> New-ApplicationAccessPolicy -AppId <CLIENT_ID> -PolicyScopeGroupId NewsletterSenders `
>   -AccessRight RestrictAccess -Description "Newsletter app - restricted"
> ```

## ب) صلاحية الشبكة (ACL) في قاعدة البيانات

```sql
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(host=>'login.microsoftonline.com',
    ace=>xs$ace_type(privilege_list=>xs$name_list('http'),principal_name=>'DATA_CENTER',principal_type=>xs_acl.ptype_db));
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(host=>'graph.microsoft.com',
    ace=>xs$ace_type(privilege_list=>xs$name_list('http'),principal_name=>'DATA_CENTER',principal_type=>xs_acl.ptype_db));
END;
/
```

## ج) إدخال الإعدادات

```sql
UPDATE "NEWSLETTER_CONFIG" SET
  TENANT_ID     = '<TENANT_ID>',
  CLIENT_ID     = '<CLIENT_ID>',
  CLIENT_SECRET = '<CLIENT_SECRET>',
  SENDER_EMAIL  = 'newsletter@yourdomain.com',
  FROM_NAME     = 'منصة بيانات الشباب'
WHERE ID = 1;
COMMIT;
```

## د) إجراء الإرسال (شغّله مرة واحدة لإنشائه)

```sql
CREATE OR REPLACE PROCEDURE NL_SEND_CAMPAIGN(p_id IN NUMBER) IS
  l_tenant VARCHAR2(100); l_client VARCHAR2(100); l_secret VARCHAR2(300);
  l_sender VARCHAR2(320); l_from VARCHAR2(200); l_unsub VARCHAR2(300);
  l_subject VARCHAR2(500); l_body CLOB;
  l_resp CLOB; l_access VARCHAR2(4000); l_reqbody CLOB; l_html CLOB;
  l_sent NUMBER := 0; l_fail NUMBER := 0; l_total NUMBER := 0;
BEGIN
  SELECT TENANT_ID,CLIENT_ID,CLIENT_SECRET,SENDER_EMAIL,FROM_NAME,UNSUB_BASE
    INTO l_tenant,l_client,l_secret,l_sender,l_from,l_unsub
    FROM "NEWSLETTER_CONFIG" WHERE ID=1;

  IF l_tenant IS NULL OR l_client IS NULL OR l_secret IS NULL OR l_sender IS NULL THEN
    RAISE_APPLICATION_ERROR(-20001,'إعدادات M365 غير مكتملة في NEWSLETTER_CONFIG');
  END IF;

  SELECT SUBJECT, BODY_HTML INTO l_subject,l_body FROM "NEWSLETTER_CAMPAIGNS" WHERE ID=p_id;
  UPDATE "NEWSLETTER_CAMPAIGNS" SET STATUS='sending' WHERE ID=p_id; COMMIT;

  -- 1) رمز الوصول (client credentials)
  apex_web_service.g_request_headers.delete;
  apex_web_service.g_request_headers(1).name  := 'Content-Type';
  apex_web_service.g_request_headers(1).value := 'application/x-www-form-urlencoded';
  l_resp := apex_web_service.make_rest_request(
    p_url => 'https://login.microsoftonline.com/'||l_tenant||'/oauth2/v2.0/token',
    p_http_method => 'POST',
    p_body => 'client_id='||l_client
            ||'&client_secret='||utl_url.escape(l_secret,TRUE)
            ||'&scope='||utl_url.escape('https://graph.microsoft.com/.default',TRUE)
            ||'&grant_type=client_credentials');
  apex_json.parse(l_resp);
  l_access := apex_json.get_varchar2('access_token');
  IF l_access IS NULL THEN
    UPDATE "NEWSLETTER_CAMPAIGNS" SET STATUS='draft' WHERE ID=p_id; COMMIT;
    RAISE_APPLICATION_ERROR(-20002,'تعذّر الحصول على رمز Microsoft: '||SUBSTR(l_resp,1,300));
  END IF;

  -- 2) إرسال لكل مشترك نشط
  FOR r IN (SELECT EMAIL, CONFIRM_TOKEN FROM "NEWSLETTER_SUBSCRIBERS" WHERE STATUS='active') LOOP
    l_total := l_total + 1;
    l_html := l_body
      || '<hr style="margin-top:24px"><p style="font-size:12px;color:#888;font-family:sans-serif">'
      || 'وصلتك هذه الرسالة من '||l_from||'. '
      || '<a href="'||l_unsub||r.CONFIRM_TOKEN||'">إلغاء الاشتراك</a></p>';

    apex_json.initialize_clob_output;
    apex_json.open_object;
      apex_json.open_object('message');
        apex_json.write('subject', l_subject);
        apex_json.open_object('body');
          apex_json.write('contentType','HTML');
          apex_json.write('content', l_html);
        apex_json.close_object;
        apex_json.open_array('toRecipients');
          apex_json.open_object;
            apex_json.open_object('emailAddress');
              apex_json.write('address', r.EMAIL);
            apex_json.close_object;
          apex_json.close_object;
        apex_json.close_array;
      apex_json.close_object;
      apex_json.write('saveToSentItems', FALSE);
    apex_json.close_object;
    l_reqbody := apex_json.get_clob_output;
    apex_json.free_output;

    apex_web_service.g_request_headers.delete;
    apex_web_service.g_request_headers(1).name  := 'Authorization';
    apex_web_service.g_request_headers(1).value := 'Bearer '||l_access;
    apex_web_service.g_request_headers(2).name  := 'Content-Type';
    apex_web_service.g_request_headers(2).value := 'application/json; charset=utf-8';

    BEGIN
      l_resp := apex_web_service.make_rest_request(
        p_url => 'https://graph.microsoft.com/v1.0/users/'||l_sender||'/sendMail',
        p_http_method => 'POST', p_body => l_reqbody);
      IF apex_web_service.g_status_code = 202 THEN
        l_sent := l_sent + 1;
        INSERT INTO "NEWSLETTER_SEND_LOG"(CAMPAIGN_ID,EMAIL,STATUS) VALUES(p_id,r.EMAIL,'sent');
      ELSE
        l_fail := l_fail + 1;
        INSERT INTO "NEWSLETTER_SEND_LOG"(CAMPAIGN_ID,EMAIL,STATUS,ERROR_MSG)
        VALUES(p_id,r.EMAIL,'failed','HTTP '||apex_web_service.g_status_code||' '||SUBSTR(l_resp,1,400));
      END IF;
    EXCEPTION WHEN OTHERS THEN
      l_fail := l_fail + 1;
      INSERT INTO "NEWSLETTER_SEND_LOG"(CAMPAIGN_ID,EMAIL,STATUS,ERROR_MSG)
      VALUES(p_id,r.EMAIL,'failed',SUBSTR(SQLERRM,1,400));
    END;
  END LOOP;

  UPDATE "NEWSLETTER_CAMPAIGNS"
     SET STATUS='sent', RECIPIENTS=l_total, SENT_COUNT=l_sent, FAIL_COUNT=l_fail, SENT_AT=SYSTIMESTAMP
   WHERE ID=p_id;
  COMMIT;
END;
/
```

## ملاحظات
- زر «إرسال» في اللوحة يستدعي هذا الإجراء. للقوائم الكبيرة (آلاف)، شغّله عبر **DBMS_SCHEDULER**
  في الخلفية بدل الطلب المباشر تفادياً لمهلة الـ AJAX.
- كل رسالة تتضمّن رابط **إلغاء اشتراك** خاصّاً بالمستلم تلقائياً.
- السجل الكامل لكل إرسال في جدول `NEWSLETTER_SEND_LOG`.
- بديل بلا كود: Power Automate (Office 365 Outlook) عبر مُشغّل HTTP — أخبرني إن رغبت به بدل Graph.
