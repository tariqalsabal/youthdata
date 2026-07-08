import Link from "next/link";
import { BrandMark, LogoImage } from "@/components/ui";
import { NewsletterForm } from "@/components/NewsletterForm";

export default function HomePage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center px-4 text-center">
      <div className="max-w-2xl">
        <LogoImage
          className="mx-auto h-24 w-auto"
          fallback={<BrandMark className="mx-auto h-20 w-20 text-gold" />}
        />
        <h1 className="mt-6 text-4xl font-extrabold tracking-tight text-navy sm:text-5xl">
          منصة بيانات الشباب
        </h1>
        <p className="mt-3 text-lg font-medium text-gold-2">Youth Data</p>
        <p className="mt-4 text-lg text-slate-600">
          بيانات دقيقة ومراجع موثوقة... أساس أبحاث رصينة في منصة واحدة.
        </p>
        <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <Link
            href="/register"
            className="w-full rounded-xl bg-navy px-6 py-3 text-sm font-semibold text-white transition hover:bg-navy-2 sm:w-auto"
          >
            إنشاء حساب جديد
          </Link>
          <Link
            href="/login"
            className="w-full rounded-xl border border-gold bg-gold px-6 py-3 text-sm font-semibold text-navy transition hover:bg-gold-2 sm:w-auto"
          >
            تسجيل الدخول
          </Link>
        </div>

        <div className="mt-12">
          <NewsletterForm />
        </div>
      </div>
    </main>
  );
}
