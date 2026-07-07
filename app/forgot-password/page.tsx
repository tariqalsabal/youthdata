// app/forgot-password/page.tsx — طلب رمز استعادة كلمة المرور ثم إعادة التعيين
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { auth } from "@/lib/auth";
import { AuthShell, Field, SubmitButton, Alert } from "@/components/ui";

export default function ForgotPasswordPage() {
  const router = useRouter();
  const [step, setStep] = useState<1 | 2>(1);
  const [email, setEmail] = useState("");
  const [resetCode, setResetCode] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [loading, setLoading] = useState(false);

  async function requestCode(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setInfo("");
    setLoading(true);
    const res = await auth.forgotPassword(email.trim());
    setLoading(false);
    if (res.success) {
      // ملاحظة: في الإنتاج يُرسل الرمز عبر البريد ولا يُعرض في الاستجابة
      if (res.resetCode) setResetCode(res.resetCode);
      setInfo(res.message || "تم إرسال رمز الاستعادة إلى بريدك.");
      setStep(2);
    } else {
      setError(res.error || "تعذّر إرسال رمز الاستعادة.");
    }
  }

  async function resetPassword(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    if (newPassword.length < 6) {
      setError("كلمة المرور يجب أن تكون 6 أحرف على الأقل.");
      return;
    }
    setLoading(true);
    const res = await auth.resetPassword(resetCode.trim(), newPassword);
    setLoading(false);
    if (res.success) {
      router.push("/login");
    } else {
      setError(res.error || "الرمز غير صحيح أو منتهي الصلاحية.");
    }
  }

  return (
    <AuthShell
      title="استعادة كلمة المرور"
      subtitle={step === 1 ? "أدخل بريدك لإرسال رمز الاستعادة" : "أدخل الرمز وكلمة المرور الجديدة"}
      footer={
        <Link href="/login" className="font-semibold text-navy hover:text-gold-2 hover:underline">
          العودة لتسجيل الدخول
        </Link>
      }
    >
      <Alert kind="error">{error}</Alert>
      <Alert kind="success">{info}</Alert>

      {step === 1 ? (
        <form onSubmit={requestCode} className="space-y-4">
          <Field
            label="البريد الإلكتروني"
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="ahmed@example.com"
          />
          <SubmitButton loading={loading}>إرسال رمز الاستعادة</SubmitButton>
        </form>
      ) : (
        <form onSubmit={resetPassword} className="space-y-4">
          <Field
            label="رمز الاستعادة"
            required
            value={resetCode}
            onChange={(e) => setResetCode(e.target.value)}
            placeholder="f3a9b2c4d8e1..."
          />
          <Field
            label="كلمة المرور الجديدة"
            type="password"
            required
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            placeholder="••••••••"
            hint="6 أحرف على الأقل"
          />
          <SubmitButton loading={loading}>تعيين كلمة المرور</SubmitButton>
        </form>
      )}
    </AuthShell>
  );
}
