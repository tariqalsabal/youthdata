// app/login/page.tsx — تسجيل الدخول
"use client";

import { Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { auth } from "@/lib/auth";
import { AuthShell, Field, SubmitButton, Alert } from "@/components/ui";
import { GoogleButton, AuthDivider } from "@/components/GoogleButton";

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const redirect = params.get("redirect") || "/dashboard";

  const [login, setLogin] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    const result = await auth.login(login.trim(), password);
    setLoading(false);

    if (result.success) {
      router.push(redirect);
    } else {
      setError(result.error || "بيانات الدخول غير صحيحة.");
    }
  }

  return (
    <>
      <Alert kind="error">{error}</Alert>
      <form onSubmit={handleSubmit} className="space-y-4">
        <Field
          label="البريد الإلكتروني / اسم المستخدم / الجوال"
          required
          value={login}
          onChange={(e) => setLogin(e.target.value)}
          placeholder="ahmed@example.com"
        />
        <Field
          label="كلمة المرور"
          type="password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="••••••••"
        />
        <div className="text-left">
          <Link href="/forgot-password" className="text-xs font-medium text-navy hover:text-gold-2 hover:underline">
            نسيت كلمة المرور؟
          </Link>
        </div>
        <SubmitButton loading={loading}>تسجيل الدخول</SubmitButton>
      </form>

      <AuthDivider />
      <GoogleButton onError={setError} redirect={redirect} />
    </>
  );
}

export default function LoginPage() {
  return (
    <AuthShell
      title="تسجيل الدخول"
      subtitle="أدخل بياناتك للوصول إلى حسابك"
      footer={
        <>
          ليس لديك حساب؟{" "}
          <Link href="/register" className="font-semibold text-navy hover:text-gold-2 hover:underline">
            إنشاء حساب جديد
          </Link>
        </>
      }
    >
      <Suspense fallback={<p className="text-sm text-slate-400">جارٍ التحميل…</p>}>
        <LoginForm />
      </Suspense>
    </AuthShell>
  );
}
