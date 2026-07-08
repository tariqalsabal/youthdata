// components/NewsletterForm.tsx — الاشتراك في النشرة البريدية (متاح للجميع)
"use client";

import { useState } from "react";

const API_BASE = process.env.NEXT_PUBLIC_AUTH_API || "/api/account";

export function NewsletterForm({ compact = false }: { compact?: boolean }) {
  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [state, setState] = useState<"idle" | "loading" | "ok" | "err">("idle");
  const [msg, setMsg] = useState("");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!email.includes("@")) {
      setState("err");
      setMsg("يرجى إدخال بريد إلكتروني صحيح.");
      return;
    }
    setState("loading");
    try {
      const res = await fetch(`${API_BASE}/newsletter/subscribe`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email.trim(), name: name.trim() || undefined }),
      });
      const data = await res.json();
      if (data.success) {
        setState("ok");
        setMsg(data.message || "تم الاشتراك بنجاح.");
        setEmail("");
        setName("");
      } else {
        setState("err");
        setMsg(data.error || "تعذّر الاشتراك، حاول مجدداً.");
      }
    } catch {
      setState("err");
      setMsg("تعذّر الاتصال بالخادم.");
    }
  }

  return (
    <div className="mx-auto w-full max-w-xl rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
      <h3 className="text-lg font-bold text-navy">النشرة البريدية</h3>
      <p className="mt-1 text-sm text-slate-500">
        اشترك ليصلك جديد بيانات الشباب والتقارير — متاح للجميع.
      </p>

      {state === "ok" ? (
        <div className="mt-4 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
          ✅ {msg}
        </div>
      ) : (
        <form onSubmit={submit} className="mt-4 space-y-3">
          {!compact && (
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="الاسم (اختياري)"
              className="w-full rounded-xl border border-slate-300 bg-white px-3.5 py-2.5 text-sm outline-none transition focus:border-navy focus:ring-2 focus:ring-navy/15"
            />
          )}
          <div className="flex flex-col gap-2 sm:flex-row">
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="بريدك الإلكتروني"
              className="flex-1 rounded-xl border border-slate-300 bg-white px-3.5 py-2.5 text-sm outline-none transition focus:border-navy focus:ring-2 focus:ring-navy/15"
            />
            <button
              type="submit"
              disabled={state === "loading"}
              className="rounded-xl bg-navy px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-navy-2 disabled:opacity-60"
            >
              {state === "loading" ? "جارٍ…" : "اشترك"}
            </button>
          </div>
          {state === "err" && <p className="text-sm text-rose-600">{msg}</p>}
        </form>
      )}
    </div>
  );
}
