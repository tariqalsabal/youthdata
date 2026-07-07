// app/dashboard/page.tsx — لوحة محمية تعرض بيانات المستخدم (GET /me)
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { auth, User } from "@/lib/auth";
import { BrandMark } from "@/components/ui";

function Row({ label, value }: { label: string; value?: string | number | null }) {
  return (
    <div className="flex items-center justify-between border-b border-slate-100 py-3 last:border-0">
      <span className="text-sm text-slate-500">{label}</span>
      <span className="text-sm font-medium text-slate-900">{value || "—"}</span>
    </div>
  );
}

export default function DashboardPage() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    (async () => {
      if (!auth.isAuthenticated()) {
        router.replace("/login");
        return;
      }
      // اعرض البيانات المخزّنة من تسجيل الدخول/التسجيل فوراً
      const stored = auth.getStoredUser();
      if (stored) setUser(stored);

      // حاول جلب بيانات أحدث من /me (تحسين اختياري — لا يُظهر خطأً إن فشل)
      const res = await auth.me();
      if (res.success && res.user) {
        setUser(res.user);
      } else if (!stored) {
        setError(res.error || "تعذّر جلب بياناتك. يرجى تسجيل الدخول من جديد.");
      }
      setLoading(false);
    })();
  }, [router]);

  async function handleLogout() {
    await auth.logout();
    router.replace("/login");
  }

  if (loading) {
    return (
      <main className="grid min-h-screen place-items-center">
        <p className="text-slate-400">جارٍ تحميل بياناتك…</p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-2xl px-4 py-10">
      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <BrandMark className="h-8 w-8 text-gold" />
          <h1 className="text-2xl font-extrabold text-navy">لوحة الحساب</h1>
        </div>
        <button
          onClick={handleLogout}
          className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-2 text-sm font-semibold text-rose-700 transition hover:bg-rose-100"
        >
          تسجيل الخروج
        </button>
      </div>

      {error && (
        <div className="mb-4 rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
          {error}
        </div>
      )}

      {user && (
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="mb-4 flex items-center gap-4">
            <div className="grid h-14 w-14 place-items-center rounded-full bg-navy text-lg font-bold text-white">
              {(user.fullName || user.username || "U").charAt(0)}
            </div>
            <div>
              <p className="text-lg font-bold text-slate-900">{user.fullName || user.username}</p>
              <p className="text-sm text-slate-500">{user.email}</p>
            </div>
          </div>

          <Row label="رقم المستخدم" value={user.id} />
          <Row label="اسم المستخدم" value={user.username} />
          <Row label="نوع الحساب" value={user.userType} />
          <Row label="رقم الجوال" value={user.phone} />
          <Row label="الدولة" value={user.country} />
          <Row label="المدينة" value={user.city} />
          <Row label="الجامعة" value={user.university} />
          <Row label="التخصص" value={user.specialty} />
          <Row label="الدرجة العلمية" value={user.degree} />
        </div>
      )}
    </main>
  );
}
