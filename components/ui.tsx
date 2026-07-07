// components/ui.tsx — عناصر واجهة مشتركة بهوية منصة بيانات الشباب
"use client";

import Link from "next/link";
import { ReactNode, useState } from "react";

// شعار المنصة (الأشرطة الثلاثة المائلة) — يرث اللون من currentColor
export function BrandMark({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" className={className} fill="currentColor" aria-hidden="true">
      <polygon points="8,82 23,82 39,18 24,18" />
      <polygon points="34,82 49,82 65,18 50,18" />
      <polygon points="60,82 75,82 91,18 76,18" />
    </svg>
  );
}

// يعرض الشعار المرفوع من /logo.svg ثم /logo.png، وإلا يرجع إلى الرسم الاحتياطي
export function LogoImage({
  className = "h-12 w-auto",
  fallback,
}: {
  className?: string;
  fallback: ReactNode;
}) {
  const [stage, setStage] = useState(0);
  const srcs = ["/logo.svg", "/logo.png"];
  if (stage >= srcs.length) return <>{fallback}</>;
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={srcs[stage]}
      alt="منصة بيانات الشباب"
      className={className}
      onError={() => setStage((s) => s + 1)}
    />
  );
}

export function Logo() {
  return (
    <Link href="/" className="inline-flex items-center gap-2.5">
      <LogoImage className="h-11 w-auto" fallback={<BrandMark className="h-9 w-9 text-gold" />} />
      <span className="text-2xl font-extrabold text-navy">منصة بيانات الشباب</span>
    </Link>
  );
}

export function AuthShell({
  title,
  subtitle,
  children,
  footer,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-10">
      <div className="w-full max-w-md">
        <div className="mb-6 flex justify-center">
          <Logo />
        </div>
        <div className="rounded-2xl border border-slate-200 bg-white p-7 shadow-xl shadow-navy/10">
          <h1 className="text-xl font-bold text-navy">{title}</h1>
          {subtitle && <p className="mt-1 text-sm text-slate-500">{subtitle}</p>}
          <div className="mt-6">{children}</div>
        </div>
        {footer && <div className="mt-5 text-center text-sm text-slate-600">{footer}</div>}
      </div>
    </main>
  );
}

export function Field({
  label,
  hint,
  status,
  ...props
}: {
  label: string;
  hint?: string;
  status?: "ok" | "taken" | "checking" | null;
} & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <label className="block">
      <span className="mb-1.5 flex items-center justify-between text-sm font-medium text-slate-700">
        {label}
        {status === "checking" && <span className="text-xs text-slate-400">جارٍ التحقق…</span>}
        {status === "ok" && <span className="text-xs text-emerald-600">متاح ✓</span>}
        {status === "taken" && <span className="text-xs text-rose-600">مستخدم مسبقاً ✕</span>}
      </span>
      <input
        className="w-full rounded-xl border border-slate-300 bg-white px-3.5 py-2.5 text-sm outline-none transition focus:border-navy focus:ring-2 focus:ring-navy/15 disabled:bg-slate-50"
        {...props}
      />
      {hint && <span className="mt-1 block text-xs text-slate-400">{hint}</span>}
    </label>
  );
}

export function SelectField({
  label,
  children,
  ...props
}: {
  label: string;
  children: ReactNode;
} & React.SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm font-medium text-slate-700">{label}</span>
      <select
        className="w-full rounded-xl border border-slate-300 bg-white px-3.5 py-2.5 text-sm outline-none transition focus:border-navy focus:ring-2 focus:ring-navy/15"
        {...props}
      >
        {children}
      </select>
    </label>
  );
}

export function SubmitButton({
  loading,
  children,
}: {
  loading?: boolean;
  children: ReactNode;
}) {
  return (
    <button
      type="submit"
      disabled={loading}
      className="w-full rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-navy-2 focus:ring-2 focus:ring-navy/30 disabled:cursor-not-allowed disabled:opacity-60"
    >
      {loading ? "جارٍ المعالجة…" : children}
    </button>
  );
}

export function Alert({ kind, children }: { kind: "error" | "success"; children: ReactNode }) {
  if (!children) return null;
  const styles =
    kind === "error"
      ? "border-rose-200 bg-rose-50 text-rose-700"
      : "border-emerald-200 bg-emerald-50 text-emerald-700";
  return (
    <div className={`mb-4 rounded-xl border px-3.5 py-2.5 text-sm ${styles}`} role="alert">
      {children}
    </div>
  );
}
