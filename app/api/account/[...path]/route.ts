// app/api/account/[...path]/route.ts
// بروكسي خادمي يمرّر الطلبات إلى Oracle ORDS لتجاوز حظر CORS في المتصفح.
import { NextRequest, NextResponse } from "next/server";

const ORDS_BASE =
  process.env.ORDS_ACCOUNT_BASE ||
  "https://youthdata.maxapex.net/ords/data_center/account/v1";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

async function proxy(request: NextRequest) {
  // أعد بناء المسار بعد /api/account/ مع الحفاظ على الترميز و query string
  const marker = "/api/account/";
  const idx = request.url.indexOf(marker);
  const rest = idx >= 0 ? request.url.slice(idx + marker.length) : "";
  const target = `${ORDS_BASE}/${rest}`;

  const headers: Record<string, string> = {};
  const auth = request.headers.get("authorization");
  if (auth) headers["Authorization"] = auth;
  const ct = request.headers.get("content-type");
  if (ct) headers["Content-Type"] = ct;
  headers["Accept"] = "application/json";

  let body: string | undefined;
  if (request.method !== "GET" && request.method !== "HEAD") {
    body = await request.text();
  }

  try {
    const res = await fetch(target, {
      method: request.method,
      headers,
      body,
      cache: "no-store",
    });
    const text = await res.text();
    return new NextResponse(text, {
      status: res.status,
      headers: {
        "Content-Type": res.headers.get("content-type") || "application/json",
      },
    });
  } catch {
    return NextResponse.json(
      { success: false, error: "تعذّر الاتصال بخادم البيانات." },
      { status: 502 }
    );
  }
}

export const GET = proxy;
export const POST = proxy;
export const PUT = proxy;
export const DELETE = proxy;
export const PATCH = proxy;
