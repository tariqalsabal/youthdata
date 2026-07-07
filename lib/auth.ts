// lib/auth.ts
// عميل المصادقة لمنصة Youth Data — يتعامل مع Oracle ORDS
// المرجع: Youth Data Platform API Documentation v1.0

// نستدعي بروكسي Next.js الخادمي (same-origin) لتجاوز CORS،
// والبروكسي بدوره يمرّر الطلب إلى Oracle ORDS.
const API_BASE = process.env.NEXT_PUBLIC_AUTH_API || "/api/account";

// ===== الأنواع =====

export interface User {
  id: number;
  username?: string;
  email?: string;
  fullName?: string;
  userType: string;
  phone?: string;
  avatar?: string | null;
  country?: string;
  city?: string;
  gender?: string;
  university?: string;
  specialty?: string;
  degree?: string;
  researchField?: string | null;
}

export interface Session {
  token: string;
  refreshToken: string;
}

export interface RegisterData {
  email: string;
  password: string;
  full_name?: string;
  username?: string;
  phone?: string;
  user_type?: string;
  country?: string;
  city?: string;
}

// شكل الاستجابة الموحّد من الـ API
export interface ApiResponse {
  success: boolean;
  error?: string;
  message?: string;
  // register
  userId?: number;
  session?: Session;
  // login / me
  user?: User;
  // refresh
  token?: string;
  refreshToken?: string;
  // check
  available?: boolean;
  // forgot-password
  resetCode?: string;
}

// ===== إدارة الـ tokens =====
// نخزّن الـ token في localStorage (لقراءته من عميل الـ API)
// وأيضاً في cookie حتى يعمل الـ middleware على الخادم.

const TOKEN_KEY = "auth_token";
const REFRESH_KEY = "refresh_token";
const USER_KEY = "user";

function setCookie(name: string, value: string, days = 30) {
  if (typeof document === "undefined") return;
  const expires = new Date(Date.now() + days * 864e5).toUTCString();
  document.cookie = `${name}=${encodeURIComponent(
    value
  )}; expires=${expires}; path=/; SameSite=Lax`;
}

function deleteCookie(name: string) {
  if (typeof document === "undefined") return;
  document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
}

function saveSession(session: Session) {
  if (typeof window === "undefined") return;
  localStorage.setItem(TOKEN_KEY, session.token);
  localStorage.setItem(REFRESH_KEY, session.refreshToken);
  setCookie(TOKEN_KEY, session.token);
}

function clearSession() {
  if (typeof window === "undefined") return;
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
  localStorage.removeItem(USER_KEY);
  deleteCookie(TOKEN_KEY);
}

class AuthAPI {
  private getToken(): string | null {
    if (typeof window === "undefined") return null;
    return localStorage.getItem(TOKEN_KEY);
  }

  // طلب أساسي مع حقن الـ token تلقائياً
  private async request(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse> {
    const token = this.getToken();
    try {
      const res = await fetch(`${API_BASE}${endpoint}`, {
        ...options,
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...options.headers,
        },
      });

      // محاولة تجديد الـ token تلقائياً عند انتهاء الصلاحية
      if (res.status === 401 && endpoint !== "/refresh") {
        const refreshed = await this.refresh();
        if (refreshed?.success) {
          const retry = await fetch(`${API_BASE}${endpoint}`, {
            ...options,
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${this.getToken()}`,
              ...options.headers,
            },
          });
          return retry.json();
        }
      }

      return res.json();
    } catch {
      return {
        success: false,
        error: "تعذّر الاتصال بالخادم. تأكّد من اتصالك بالإنترنت.",
      };
    }
  }

  // POST /register — إنشاء حساب جديد
  async register(data: RegisterData): Promise<ApiResponse> {
    const result = await this.request("/register", {
      method: "POST",
      body: JSON.stringify(data),
    });
    if (result.success && result.session) {
      saveSession(result.session);
      // نخزّن نسخة مبدئية من المستخدم من بيانات النموذج (لأن /me قد لا يكون متاحاً)
      const u: User = {
        id: result.userId ?? 0,
        email: data.email,
        fullName: data.full_name,
        username: data.username,
        phone: data.phone,
        userType: data.user_type || "user_normal",
        country: data.country,
        city: data.city,
      };
      localStorage.setItem(USER_KEY, JSON.stringify(u));
    }
    return result;
  }

  // POST /google — تسجيل الدخول/إنشاء حساب عبر Google (id_token من Google Identity)
  async googleLogin(idToken: string): Promise<ApiResponse> {
    const result = await this.request("/google", {
      method: "POST",
      body: JSON.stringify({ id_token: idToken }),
    });
    if (result.success && result.session) {
      saveSession(result.session);
      if (result.user) {
        localStorage.setItem(USER_KEY, JSON.stringify(result.user));
      }
    }
    return result;
  }

  // POST /login — تسجيل الدخول (login = email أو username أو phone)
  async login(login: string, password: string): Promise<ApiResponse> {
    const result = await this.request("/login", {
      method: "POST",
      body: JSON.stringify({ login, password }),
    });
    if (result.success && result.session) {
      saveSession(result.session);
      if (result.user) {
        localStorage.setItem(USER_KEY, JSON.stringify(result.user));
      }
    }
    return result;
  }

  // POST /logout — إنهاء الجلسة
  async logout(): Promise<void> {
    try {
      await this.request("/logout", { method: "POST" });
    } finally {
      clearSession();
    }
  }

  // GET /me — بيانات المستخدم الحالي
  async me(): Promise<ApiResponse> {
    return this.request("/me");
  }

  // PUT /profile — تعديل الملف الشخصي
  async updateProfile(data: Partial<User> & Record<string, unknown>): Promise<ApiResponse> {
    return this.request("/profile", {
      method: "PUT",
      body: JSON.stringify(data),
    });
  }

  // PUT /password — تغيير كلمة المرور
  async changePassword(
    oldPassword: string,
    newPassword: string
  ): Promise<ApiResponse> {
    return this.request("/password", {
      method: "PUT",
      body: JSON.stringify({
        old_password: oldPassword,
        new_password: newPassword,
      }),
    });
  }

  // POST /refresh — تجديد الـ access token
  async refresh(): Promise<ApiResponse | null> {
    if (typeof window === "undefined") return null;
    const refreshToken = localStorage.getItem(REFRESH_KEY);
    if (!refreshToken) return null;
    const result = await this.request("/refresh", {
      method: "POST",
      body: JSON.stringify({ refresh_token: refreshToken }),
    });
    if (result.success && result.token && result.refreshToken) {
      saveSession({ token: result.token, refreshToken: result.refreshToken });
    }
    return result;
  }

  // POST /forgot-password — طلب رمز استعادة كلمة المرور
  async forgotPassword(email: string): Promise<ApiResponse> {
    return this.request("/forgot-password", {
      method: "POST",
      body: JSON.stringify({ email }),
    });
  }

  // POST /reset-password — تعيين كلمة مرور جديدة بالرمز
  async resetPassword(code: string, newPassword: string): Promise<ApiResponse> {
    return this.request("/reset-password", {
      method: "POST",
      body: JSON.stringify({ reset_code: code, new_password: newPassword }),
    });
  }

  // GET /check/:type/:value — التحقق من توفّر البريد/اسم المستخدم/الهاتف
  async checkAvailability(
    type: "email" | "username" | "phone",
    value: string
  ): Promise<ApiResponse> {
    return this.request(`/check/${type}/${encodeURIComponent(value)}`);
  }

  isAuthenticated(): boolean {
    return !!this.getToken();
  }

  getStoredUser(): User | null {
    if (typeof window === "undefined") return null;
    const raw = localStorage.getItem(USER_KEY);
    return raw ? (JSON.parse(raw) as User) : null;
  }
}

export const auth = new AuthAPI();
