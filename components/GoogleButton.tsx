// components/GoogleButton.tsx — زر "تسجيل الدخول عبر Google" (Google Identity Services)
"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { auth } from "@/lib/auth";

declare global {
  interface Window {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    google?: any;
  }
}

const CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;

export function GoogleButton({
  onError,
  redirect = "/dashboard",
}: {
  onError?: (message: string) => void;
  redirect?: string;
}) {
  const router = useRouter();
  const divRef = useRef<HTMLDivElement>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!CLIENT_ID) return;

    function init() {
      if (!window.google || !divRef.current) return;
      window.google.accounts.id.initialize({
        client_id: CLIENT_ID,
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        callback: async (resp: any) => {
          setLoading(true);
          const result = await auth.googleLogin(resp.credential);
          setLoading(false);
          if (result.success) {
            router.push(redirect);
          } else {
            onError?.(result.error || "تعذّر تسجيل الدخول عبر Google.");
          }
        },
      });
      window.google.accounts.id.renderButton(divRef.current, {
        type: "standard",
        theme: "outline",
        size: "large",
        text: "continue_with",
        shape: "pill",
        logo_alignment: "center",
        width: 300,
        locale: "ar",
      });
    }

    if (window.google) {
      init();
      return;
    }
    const scriptId = "google-gsi-client";
    let script = document.getElementById(scriptId) as HTMLScriptElement | null;
    if (!script) {
      script = document.createElement("script");
      script.src = "https://accounts.google.com/gsi/client";
      script.async = true;
      script.defer = true;
      script.id = scriptId;
      script.onload = init;
      document.body.appendChild(script);
    } else {
      script.addEventListener("load", init);
    }
  }, [router, onError, redirect]);

  // مخفي حتى يُضبط معرّف Google (NEXT_PUBLIC_GOOGLE_CLIENT_ID)
  if (!CLIENT_ID) return null;

  return (
    <div className="flex flex-col items-center">
      <div ref={divRef} />
      {loading && <p className="mt-2 text-xs text-slate-400">جارٍ تسجيل الدخول…</p>}
    </div>
  );
}

// فاصل "أو" بين الدخول العادي و Google — يظهر فقط عند تفعيل Google
export function AuthDivider() {
  if (!CLIENT_ID) return null;
  return (
    <div className="my-5 flex items-center gap-3 text-xs text-slate-400">
      <span className="h-px flex-1 bg-slate-200" />
      أو
      <span className="h-px flex-1 bg-slate-200" />
    </div>
  );
}
