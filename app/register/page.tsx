// app/register/page.tsx — إنشاء حساب جديد
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { auth } from "@/lib/auth";
import { AuthShell, Field, SelectField, SubmitButton, Alert } from "@/components/ui";
import { GoogleButton, AuthDivider } from "@/components/GoogleButton";

type CheckStatus = "ok" | "taken" | "checking" | null;

export default function RegisterPage() {
  const router = useRouter();
  const [form, setForm] = useState({
    full_name: "",
    username: "",
    email: "",
    phone: "",
    password: "",
    confirm: "",
    user_type: "user_normal",
    country: "",
    city: "",
  });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  // حالات التحقق من التوفّر
  const [emailStatus, setEmailStatus] = useState<CheckStatus>(null);
  const [usernameStatus, setUsernameStatus] = useState<CheckStatus>(null);

  function update(key: keyof typeof form, value: string) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  // التحقق من البريد (debounced 500ms)
  useEffect(() => {
    const v = form.email.trim();
    if (!v || !v.includes("@")) {
      setEmailStatus(null);
      return;
    }
    setEmailStatus("checking");
    const t = setTimeout(async () => {
      const res = await auth.checkAvailability("email", v);
      setEmailStatus(res.success && res.available ? "ok" : "taken");
    }, 500);
    return () => clearTimeout(t);
  }, [form.email]);

  // التحقق من اسم المستخدم (debounced 500ms)
  useEffect(() => {
    const v = form.username.trim();
    if (v.length < 3) {
      setUsernameStatus(null);
      return;
    }
    setUsernameStatus("checking");
    const t = setTimeout(async () => {
      const res = await auth.checkAvailability("username", v);
      setUsernameStatus(res.success && res.available ? "ok" : "taken");
    }, 500);
    return () => clearTimeout(t);
  }, [form.username]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");

    // تحقق من جهة العميل (frontend validation)
    if (!form.email.includes("@")) {
      setError("يرجى إدخال بريد إلكتروني صحيح.");
      return;
    }
    if (form.password.length < 6) {
      setError("كلمة المرور يجب أن تكون 6 أحرف على الأقل.");
      return;
    }
    if (form.password !== form.confirm) {
      setError("كلمتا المرور غير متطابقتين.");
      return;
    }
    if (emailStatus === "taken") {
      setError("البريد الإلكتروني مستخدم مسبقاً.");
      return;
    }
    if (usernameStatus === "taken") {
      setError("اسم المستخدم مستخدم مسبقاً.");
      return;
    }

    setLoading(true);
    const result = await auth.register({
      email: form.email.trim(),
      password: form.password,
      full_name: form.full_name.trim() || undefined,
      username: form.username.trim() || undefined,
      phone: form.phone.trim() || undefined,
      user_type: form.user_type,
      country: form.country.trim() || undefined,
      city: form.city.trim() || undefined,
    });
    setLoading(false);

    if (result.success) {
      router.push("/dashboard");
    } else {
      setError(result.error || "تعذّر إنشاء الحساب. حاول مرة أخرى.");
    }
  }

  return (
    <AuthShell
      title="إنشاء حساب جديد"
      subtitle="أدخل بياناتك للانضمام إلى منصة بيانات الشباب"
      footer={
        <>
          لديك حساب بالفعل؟{" "}
          <Link href="/login" className="font-semibold text-navy hover:text-gold-2 hover:underline">
            تسجيل الدخول
          </Link>
        </>
      }
    >
      <Alert kind="error">{error}</Alert>

      <form onSubmit={handleSubmit} className="space-y-4">
        <Field
          label="الاسم الكامل"
          value={form.full_name}
          onChange={(e) => update("full_name", e.target.value)}
          placeholder="مثال: أحمد محمد"
        />

        <Field
          label="اسم المستخدم"
          status={usernameStatus}
          value={form.username}
          onChange={(e) => update("username", e.target.value)}
          placeholder="ahmed_2026"
          hint="3 أحرف على الأقل"
        />

        <Field
          label="البريد الإلكتروني *"
          type="email"
          required
          status={emailStatus}
          value={form.email}
          onChange={(e) => update("email", e.target.value)}
          placeholder="ahmed@example.com"
        />

        <Field
          label="رقم الجوال"
          type="tel"
          value={form.phone}
          onChange={(e) => update("phone", e.target.value)}
          placeholder="+966500000000"
        />

        <div className="grid grid-cols-2 gap-3">
          <Field
            label="الدولة"
            value={form.country}
            onChange={(e) => update("country", e.target.value)}
            placeholder="السعودية"
          />
          <Field
            label="المدينة"
            value={form.city}
            onChange={(e) => update("city", e.target.value)}
            placeholder="الرياض"
          />
        </div>

        <SelectField
          label="نوع الحساب"
          value={form.user_type}
          onChange={(e) => update("user_type", e.target.value)}
        >
          <option value="user_normal">مستخدم عادي</option>
          <option value="user_researcher">باحث</option>
          <option value="user_entity">جهة</option>
        </SelectField>

        <Field
          label="كلمة المرور *"
          type="password"
          required
          value={form.password}
          onChange={(e) => update("password", e.target.value)}
          placeholder="••••••••"
          hint="6 أحرف على الأقل"
        />

        <Field
          label="تأكيد كلمة المرور *"
          type="password"
          required
          value={form.confirm}
          onChange={(e) => update("confirm", e.target.value)}
          placeholder="••••••••"
        />

        <SubmitButton loading={loading}>إنشاء الحساب</SubmitButton>
      </form>

      <AuthDivider />
      <GoogleButton onError={setError} />
    </AuthShell>
  );
}
