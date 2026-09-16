import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-pharmacy-id",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jwtPayload(req: Request): Record<string, unknown> | null {
  const auth = req.headers.get("authorization") ?? "";
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  try {
    const parts = m[1].split(".");
    if (parts.length < 2) return null;
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(b64));
  } catch {
    return null;
  }
}

async function enrichProfile(sb: any, profile: any): Promise<any> {
  if (!profile) return null;
  const { data: role } = profile.role_id
    ? await sb
        .from("roles")
        .select("name")
        .eq("id", profile.role_id)
        .maybeSingle()
    : { data: null };
  const { data: pharmacy } = profile.pharmacy_id
    ? await sb
        .from("pharmacies")
        .select("name")
        .eq("id", profile.pharmacy_id)
        .maybeSingle()
    : { data: null };
  const { data: perms } = profile.role_id
    ? await sb
        .from("role_permissions")
        .select("permission_code")
        .eq("role_id", profile.role_id)
    : { data: null };
  return {
    ...profile,
    is_super_admin: profile.is_super_admin ?? false,
    permissions: (perms ?? []).map((p: any) => p.permission_code),
    pharmacy_name: pharmacy?.name ?? null,
    role_name: role?.name ?? null,
  };
}

function pharmacyId(req: Request, fallback = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"): string {
  const hdr = req.headers.get("x-pharmacy-id");
  if (hdr) return hdr;
  const p = jwtPayload(req);
  if (p) {
    const v =
      p.pharmacyId ?? p.pharmacy_id ?? p.app_metadata?.pharmacy_id ?? null;
    if (v) return String(v);
  }
  return fallback;
}

/* ---- Route helpers ---- */

const TABLE_MAP: Record<string, string> = {
  "/catalog/medications": "medications",
  "/catalog/categories": "categories",
  "/catalog/laboratories": "laboratories",
  "/catalog/families": "therapeutic_families",
  "/suppliers": "suppliers",
  "/customers": "customers",
  "/employees": "employees",
  "/cameras": "cameras",
  "/branches": "branches",
  "/roles": "roles",
  "/role_permissions": "role_permissions",
  "/permissions": "permissions",
  "/users": "users",
  "/notifications": "notifications",
  "/prescriptions": "prescriptions",
  "/pharmacies": "pharmacies",
  "/purchases/orders": "purchase_orders",
  "/purchases/receptions": "purchase_receptions",
  "/sales": "sales",
  "/sale-items": "sale_items",
  "/sale-returns": "sale_returns",
  "/payments": "payments",
  "/invoices": "invoices",
  "/invoice-items": "invoice_items",
  "/stock/adjustments": "stock_movements",
  "/stock/movements": "stock_movements",
  "/stock/balances": "stock_balances",
  "/stock/lots": "lots",
  "/stock/transfers": "stock_transfers",
  "/accounting/accounts": "accounts",
  "/accounting/journal": "journal_entries",
  "/accounting/expense-categories": "expense_categories",
  "/accounting/expenses": "expenses",
  "/accounting/registers": "cash_registers",
  "/accounting/closings": "closing_periods",
  "/attendance/leaves": "leaves",
  "/attendance/schedules": "schedules",
  "/reference/categories": "reference_categories",
  "/website/settings": "website_settings",
  "/website/blog/posts": "blog_posts",
  "/support/tickets": "support_tickets",
  "/backups": "backups",
};

function mapTable(raw: string): string | null {
  const clean = raw.replace(/\/+$/, "");
  return TABLE_MAP[clean] ?? null;
}

/** Proxy POST/PUT/DELETE to PostgREST with pharmacy_id injection. */
async function proxyToTable(
  serviceKey: string,
  supabaseUrl: string,
  req: Request,
  table: string,
  subpath: string,
  pid: string,
) {
  let restPath = `/rest/v1/${table}`;
  const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (subpath && uuidRe.test(subpath)) {
    // UUID → filtre PostgREST id=eq.xxx (pas de sous-chemin)
    restPath += ``;
  } else if (subpath) {
    restPath += `/${subpath}`;
  }
  const targetUrl = new URL(`${supabaseUrl}${restPath}`);
  // Si subpath est un UUID, on l'ajoute comme filtre id=eq
  if (subpath && uuidRe.test(subpath)) {
    targetUrl.searchParams.set("id", `eq.${subpath}`);
  }
  const url = new URL(req.url);
  const limit = parseInt(url.searchParams.get("limit") ?? "50", 10);
  const page = parseInt(url.searchParams.get("page") ?? "1", 10);
  url.searchParams.forEach((v, k) => {
    if (k === "page") {
      targetUrl.searchParams.set("offset", String((page - 1) * limit));
    } else if (k === "limit") {
      targetUrl.searchParams.set("limit", v);
    } else if (v === "true" || v === "false") {
      targetUrl.searchParams.set(k, `eq.${v}`);
    } else {
      targetUrl.searchParams.set(k, v);
    }
  });

  const headers: Record<string, string> = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    "Content-Type": "application/json",
    Prefer: "return=representation",
  };

  const method = req.method;
  let body: string | undefined;
  if (method !== "GET" && method !== "HEAD") {
    const raw = await req.text();
    const parsed = JSON.parse(raw || "{}");
    if (!parsed.pharmacy_id && table !== "pharmacies" && table !== "roles") {
      parsed.pharmacy_id = pid;
    }
    body = JSON.stringify(parsed);
  }

  const isUuidLookup = !!(subpath && uuidRe.test(subpath));
  if (isUuidLookup) {
    targetUrl.searchParams.set("limit", "1");
  }

  const res = await fetch(targetUrl.toString(), { method, headers, body });
  const text = await res.text();

  // UUID lookup : unwrap [item] → item (le Flutter attend un Map, pas une List)
  if (isUuidLookup && method === "GET" && res.status >= 200 && res.status < 300) {
    try {
      const arr = JSON.parse(text);
      if (Array.isArray(arr) && arr.length === 1) {
        return json(arr[0]);
      }
      if (Array.isArray(arr) && arr.length === 0) {
        return json({ error: { code: "NOT_FOUND", message: "Not found" } }, 404);
      }
    } catch (_) { /* fallback to raw */ }
  }

  return new Response(text, {
    status: res.status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS")
    return new Response(null, { headers: corsHeaders });

  const url = new URL(req.url);
  const raw = url.pathname.replace(/^\/pharma-api\/?/, "").replace(/^\/+/, "/");
  const path = raw.startsWith("api/v1/") ? raw.slice(7) : raw;
  const pid = pharmacyId(req);
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey =
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? serviceKey;
  // Client données (service_role, insensible à la session).
  const sb = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  // Client auth isolé pour ne pas polluer le token service des requêtes data.
  const sbAuth = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  /* ===========================================================
     HEALTH
     =========================================================== */
  if (path === "health") {
    try {
      const { count } = await sb
        .from("pharmacies")
        .select("id", { count: "exact", head: true });
      return json({
        status: "ok",
        database: "connected",
        pharmacies: count,
        version: "2.1.0",
        uptime: Math.round(performance.now() / 1000),
        timestamp: new Date().toISOString(),
      });
    } catch (e) {
      return json({ status: "error", message: String(e) }, 500);
    }
  }

  /* ===========================================================
     AUTH
     =========================================================== */
  if (path === "auth/login" || path === "/auth/login") {
    if (req.method !== "POST")
      return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
    const body = await req.json().catch(() => ({}));
    const { email, password } = body as any;
    if (!email || !password)
      return json(
        { error: { code: "VALIDATION", message: "email + password requis" } },
        400,
      );

    const buildSession = async (session: any) => {
      const normalized = String(email).trim().toLowerCase();
      const { data: profile, error: profileErr } = await sb
        .from("users")
        .select(
          "id, pharmacy_id, branch_id, role_id, first_name, last_name, email, username, phone, is_super_admin",
        )
        .ilike("email", normalized)
        .maybeSingle();
      if (profileErr) console.error("[login] profile error:", profileErr.message);

      let userProfile: any;
      if (profile) {
        userProfile = await enrichProfile(sb, profile);
      } else {
        userProfile = {
          email: normalized,
          id: session?.user?.id ?? crypto.randomUUID(),
          pharmacy_id: pid,
          branch_id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
          role_id: "00000000-0000-0000-0000-000000000002",
          first_name: "Admin",
          last_name: "Pharma",
          is_super_admin: true,
          permissions: [],
          pharmacy_name: null,
          role_name: "Pharmacien Administrateur",
        };
      }

      return json({
        data: {
          accessToken: session?.access_token ?? null,
          refreshToken: session?.refresh_token ?? null,
          user: userProfile,
        },
      });
    };

    // 1) Connexion directe via Supabase Auth.
    {
      const { data: authData, error: authErr } =
        await sbAuth.auth.signInWithPassword({ email, password });
      if (authData?.session && !authErr) {
        return await buildSession(authData.session);
      }
    }

    // 2) Migration automatique : utilisateur présent dans public.users
    //    mais pas encore dans Supabase Auth. On vérifie le mot de passe
    //    argon2 stocké, puis on provisionne le compte Auth.
    {
      const { data: user } = await sb
        .from("users")
        .select("id, pharmacy_id, email, status, password_hash, role_id, first_name, last_name, is_super_admin")
        .ilike("email", String(email).trim().toLowerCase())
        .maybeSingle();
      if (user && user.status === "active") {
        const hash = user.password_hash;
        try {
          const mod = await import("https://esm.sh/@phc/argon2@0.1.1");
          const ok = await mod.verify(hash, password);
          if (ok) {
            const { error: createErr } = await sb.auth.admin.createUser({
              email: String(email).trim().toLowerCase(),
              password,
              email_confirm: true,
              user_metadata: {
                pharmacy_id: user.pharmacy_id,
                role_id: user.role_id,
              },
            });
            if (createErr) {
              return json(
                { error: { code: "MIGRATION_FAILED", message: createErr.message } },
                500,
              );
            }
            const { data: authData2, error: authErr2 } =
await sbAuth.auth.signInWithPassword({ email, password });
            if (authData2?.session && !authErr2) {
              return await buildSession(authData2.session);
            }
            return json(
              { error: { code: "MIGRATION_FAILED", message: authErr2?.message ?? "login après migration" } },
              500,
            );
          }
        } catch (e) {
          // Verif argon2 impossible => on laisse tomber vers credentials invalides.
          console.error("argon2 verify error:", String(e));
        }
        return json(
          { error: { code: "INVALID_CREDENTIALS", message: "Identifiants invalides" } },
          401,
        );
      }
    }
    return json(
      { error: { code: "INVALID_CREDENTIALS", message: "Identifiants invalides" } },
      401,
    );
  }

  if (path === "auth/signup" || path === "/auth/signup") {
    if (req.method !== "POST")
      return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
    const body = await req.json().catch(() => ({}));
    const { email, password, first_name, last_name, pharmacy_id: pId } =
      body as any;
    if (!email || !password)
      return json({ error: { code: "VALIDATION" } }, 400);
    const { data, error } = await sbAuth.auth.signUp({ email, password });
    if (error)
      return json(
        { error: { code: "SIGNUP_FAILED", message: error.message } },
        400,
      );
    if (pId) {
      await sb.from("users").insert({
        email,
        first_name: first_name ?? "New",
        last_name: last_name ?? "User",
        pharmacy_id: pId,
        password_hash: "supabase-auth",
      });
    }
    return json({ data });
  }

  /* -----------------------------------------------
     AUTH / PROVISION — provisionne un compte Supabase
     Auth pour un utilisateur DÉJÀ présent dans
     public.users (migration). Idempotent.
     ----------------------------------------------- */
  if (path === "auth/provision" || path === "/auth/provision") {
    if (req.method !== "POST")
      return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
    const body = await req.json().catch(() => ({}));
    const { email, password } = body as any;
    if (!email || !password)
      return json({ error: { code: "VALIDATION" } }, 400);
    const normalized = String(email).trim().toLowerCase();
    const { data: u } = await sb
      .from("users")
      .select("id, pharmacy_id, role_id, first_name, last_name, email")
      .ilike("email", normalized)
      .maybeSingle();
    if (!u) {
      return json(
        { error: { code: "NOT_FOUND", message: "Utilisateur absent de public.users" } },
        404,
      );
    }
    const { data: existing } = await sb.auth.admin.listUsers({
      page: 1,
      perPage: 1000,
    });
    if (existing?.users?.some((x: any) => x.email?.toLowerCase() === normalized)) {
      return json({ data: { message: "Compte déjà provisionné" } });
    }
    const { data: created, error: createErr } = await sb.auth.admin.createUser({
      email: normalized,
      password,
      email_confirm: true,
      user_metadata: {
        pharmacy_id: u.pharmacy_id,
        role_id: u.role_id,
      },
    });
    if (createErr && !String(createErr.message).includes("already been registered")) {
      return json(
        { error: { code: "PROVISION_FAILED", message: createErr.message } },
        400,
      );
    }
    await sb.from("users").update({ password_hash: "supabase-auth" }).eq("id", u.id);
    return json({ data: { message: "Compte provisionné", userId: created?.user?.id } });
  }

  if (path === "auth/refresh" || path === "/auth/refresh") {
    if (req.method !== "POST")
      return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
    const body = await req.json().catch(() => ({}));
    const { refresh_token, refreshToken } = body as any;
    const rt = refresh_token ?? refreshToken;
    if (!rt)
      return json({ error: { code: "VALIDATION" } }, 400);
    const { data, error } = await sbAuth.auth.refreshSession({ refresh_token: rt });
    if (error)
      return json({ error: { code: "REFRESH_FAILED", message: error.message } }, 401);
    const email = data.session?.user?.email ?? "";
    const { data: profile } = await sb
      .from("users")
      .select(
        "id, pharmacy_id, branch_id, role_id, first_name, last_name, email, username, phone, is_super_admin",
      )
      .ilike("email", email)
      .maybeSingle();
    const user = profile ? await enrichProfile(sb, profile) : null;
    return json({
      data: {
        accessToken: data.session?.access_token,
        refreshToken: data.session?.refresh_token,
        user: user ?? {
          email,
          id: data.session?.user?.id ?? "",
          pharmacy_id: pid,
          first_name: "Admin",
          last_name: "Pharma",
          is_super_admin: false,
        },
      },
    });
  }

  if (path === "auth/change-password" || path === "/auth/change-password") {
    if (req.method !== "POST")
      return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
    const body = await req.json().catch(() => ({}));
    const { newPassword } = body as any;
    const payload = jwtPayload(req);
    const userId = payload?.sub as string;
    if (!userId || !newPassword)
      return json({ error: { code: "VALIDATION" } }, 400);
    const { error } = await sb.auth.admin.updateUserById(userId, {
      password: newPassword,
    });
    if (error)
      return json({ error: { code: "UPDATE_FAILED", message: error.message } }, 400);
    return json({ data: { message: "Mot de passe mis à jour" } });
  }

  if (path === "__diag" || path === "/__diag") {
    try {
      const r1 = await sb
        .from("users")
        .select("id, email")
        .ilike("email", "admin@pharma.ma")
        .limit(5);
      const r2 = await sb
        .from("users")
        .select("id, email, role_id")
        .eq("email", "admin@pharma.ma")
        .limit(5);
      const r3 = await sb
        .from("roles")
        .select("id, name")
        .limit(3);
      const [saleItems, payments, moves] = await Promise.all([
        sb.from("sale_items").select("id, sale_id, medication_id, quantity").limit(5),
        sb.from("payments").select("id, sale_id, method, amount").limit(5),
        sb.from("stock_movements").select("id, movement_type, reference_id, quantity").limit(5).order("created_at", { ascending: false }),
      ]);
      let schemaInfo: any = {};
      try {
        const sres = await fetch(
          `${supabaseUrl}/rest/v1/?apikey=${serviceKey}`,
          { headers: { Accept: "application/openapi+json", apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
        );
        const sjson: any = await sres.json();
        const defs: any = sjson?.definitions ?? {};
        const salesDef = defs?.sales;
        if (salesDef) {
          const sc = salesDef.properties ?? {};
          schemaInfo.sales_properties = Object.fromEntries(
            Object.entries(sc).map(([k, v]: any) => [k, (v as any)?.enum ?? (v as any)?.type ?? "?"]),
          );
          schemaInfo.sales_required = salesDef.required ?? [];
        }
        const prodDef = defs?.sale_items;
        schemaInfo.sale_items_def = prodDef
          ? Object.fromEntries(
              Object.entries(prodDef.properties ?? {}).map(([k, v]: any) => [k, (v as any)?.type ?? "?"]),
            )
          : null;
        schemaInfo.sale_items_required = prodDef?.required ?? [];
        const payDef = defs?.payments;
        schemaInfo.payments_def = payDef
          ? Object.fromEntries(
              Object.entries(payDef.properties ?? {}).map(([k, v]: any) => [k, (v as any)?.type ?? "?"]),
            )
          : null;
        schemaInfo.all_def_keys = Object.keys(defs).slice(0, 80);
      } catch (e: any) {
        schemaInfo.openapi_error = String(e);
      }
      return json({
        diag: {
          ilike: { data: r1.data, error: r1.error?.message ?? null },
          eq: { data: r2.data, error: r2.error?.message ?? null },
          roles: { data: r3.data, error: r3.error?.message ?? null },
          sanity: {
            sale_items: { count: saleItems.data?.length, err: saleItems.error?.message ?? null, sample: saleItems.data?.map((x: any) => ({ sale: x.sale_id, med: x.medication_id, qty: x.quantity })) },
            payments: { count: payments.data?.length, err: payments.error?.message ?? null, sample: payments.data?.map((x: any) => ({ sale: x.sale_id, method: x.method, amount: x.amount })) },
            stock_movements: { count: moves.data?.length, err: moves.error?.message ?? null, sample: moves.data?.map((x: any) => ({ type: x.movement_type, ref: x.reference_id, qty: x.quantity })) },
          },
          schema: schemaInfo,
        },
      });
    } catch (e) {
      return json({ diag: { throw: String(e) } }, 500);
    }
  }

  /* ===========================================================
     DASHBOARD
     =========================================================== */
  if (path === "dashboard/overview" || path === "/dashboard/overview") {
    try {
      const now = new Date();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

      const [meds, cats, labs, suppliers, customers, prescs, stockBalances, salesToday, salesMonth] =
        await Promise.all([
          sb.from("medications").select("id", { count: "exact", head: true }).eq("pharmacy_id", pid),
          sb.from("categories").select("id", { count: "exact", head: true }).eq("pharmacy_id", pid),
          sb.from("laboratories").select("id", { count: "exact", head: true }).eq("pharmacy_id", pid),
          sb.from("suppliers").select("id", { count: "exact", head: true }).eq("pharmacy_id", pid),
          sb.from("customers").select("id", { count: "exact", head: true }).eq("pharmacy_id", pid),
          sb.from("prescriptions").select("id", { count: "exact", head: true }).eq("pharmacy_id", pid),
          sb.from("stock_balances").select("quantity").eq("pharmacy_id", pid),
          sb.from("sales").select("total, cost_total").eq("pharmacy_id", pid).eq("status", "completed").gte("created_at", startOfDay.toISOString()),
          sb.from("sales").select("total, cost_total").eq("pharmacy_id", pid).eq("status", "completed").gte("created_at", startOfMonth.toISOString()),
        ]);

      const lowStock = (stockBalances.data ?? []).filter((r: any) => Number(r.quantity) < 10).length;
      const revenueToday = (salesToday.data ?? []).reduce((s: number, r: any) => s + Number(r.total ?? 0), 0);
      const revenueMonth = (salesMonth.data ?? []).reduce((s: number, r: any) => s + Number(r.total ?? 0), 0);
      const costMonth = (salesMonth.data ?? []).reduce((s: number, r: any) => s + Number(r.cost_total ?? 0), 0);
      const salesCountToday = (salesToday.data ?? []).length;

      return json({
        data: {
          revenue: {
            revenue_today: revenueToday,
            revenue_month: revenueMonth,
            profit_month: revenueMonth - costMonth,
            sales_today: salesCountToday,
            sales_month: (salesMonth.data ?? []).length,
          },
          alerts: { low_stock: lowStock, expiring: 0, expired: 0, pending_orders: 0 },
          counts: {
            medications: { total: meds.count ?? 0, available: meds.count ?? 0 },
            prescriptions: { month: prescs.count ?? 0, pending: 0 },
            customers: { total: customers.count ?? 0, active: customers.count ?? 0 },
            suppliers: { total: suppliers.count ?? 0, active: suppliers.count ?? 0 },
          },
          stock: { stock_value: 0 },
          top_products: [],
          sales_trend: [],
          pharma_plus: {
            parapharmacy: { products: cats.count ?? 0, revenue_month: 0 },
            cameras: { total: 0, online: 0, recording: 0 },
            pharma_ai: { requests_7d: 0, success_7d: 0 },
            reference: { total: labs.count ?? 0, last_sync: {} },
          },
          employees_present: 0,
        },
      });
    } catch (e) {
      return json({ error: { code: "DASHBOARD_ERROR", message: String(e) } }, 500);
    }
  }

  /* ===========================================================
     AI — CHAT, INSIGHTS, REORDER-PLAN, SALES-ANALYSIS
     =========================================================== */
  if (path === "ai/chat" && req.method === "POST") {
    const body = await req.json().catch(() => ({}));
    const text = (body as any).message ?? (body as any).query ?? "";
    const lower = text.toLowerCase();
    const fmt = (n: unknown) =>
      `${Number(n ?? 0).toLocaleString("fr-FR", { maximumFractionDigits: 2 })} MAD`;
    const detectPeriod = (l: string) => {
      if (/(aujourd|today|du jour)/.test(l)) return 1;
      if (/(semaine|week|7)/.test(l)) return 7;
      if (/(mois|month|30)/.test(l)) return 30;
      if (/(trimestre|quarter|90)/.test(l)) return 90;
      return 30;
    };
    const days = detectPeriod(lower);

    // Helper: list products
    const chatCatalog = async () => {
      const { data } = await sb.from("medications").select("name, price_sale").eq("pharmacy_id", pid).eq("status", "available").order("name").limit(25);
      if (!data?.length) return { reply: "Votre catalogue est vide.", intent: "catalog", data: [] };
      const lines = data.map((r: any) => `• ${r.name} — ${fmt(r.price_sale)}`);
      return { reply: `Catalogue (${data.length} ref) :\n${lines.join("\n")}`, intent: "catalog", data };
    };

    // Product stock lookup
    const matchProduct = async (q: string) => {
      const n = q.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
      const stop = new Set(["combien","avoir","est","sont","il","en","de","du","des","les","dans","niveau","stock","rupture"]);
      const tokens = n.split(/[^a-z0-9]/).filter((t: string) => t.length >= 4 && !stop.has(t));
      if (!tokens.length) return null;
      const { data } = await sb.from("medications").select("id, name").eq("pharmacy_id", pid).eq("status", "available").limit(200);
      if (!data?.length) return null;
      let best: any = null, bestScore = 0;
      for (const r of data) {
        const norm = String(r.name).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
        if (n.includes(norm)) { if (norm.length > bestScore) { best = r; bestScore = norm.length; } continue; }
        const nameTokens = new Set(norm.split(/[^a-z0-9]/).filter((t: string) => t.length >= 4));
        let score = 0;
        for (const t of nameTokens) if (tokens.includes(t)) score++;
        if (score > bestScore) { best = r; bestScore = score; }
      }
      if (!best) return null;
      const { data: found } = await sb.from("medications").select("name, reorder_level").eq("pharmacy_id", pid).ilike("name", best.name).limit(1);
      const { data: sbData } = await sb.from("stock_balances").select("quantity").eq("pharmacy_id", pid).eq("medication_id", best.id);
      const stock = (sbData ?? []).reduce((s: number, r: any) => s + Number(r.quantity ?? 0), 0);
      const r = found?.[0] ?? best;
      return { reply: `• ${r.name} : ${stock} u. en stock (seuil ${Number(r.reorder_level ?? 0)} u.)`, intent: "stock", data: { ...r, stock } };
    };

    let result: any;
    if (/(bonjour|salut|hello|salam|bonsoir)/.test(lower)) {
      result = { reply: "Bonjour ! Je suis l'assistant PHARMA+. Comment puis-je vous aider ?", intent: "greeting" };
    } else if (/(aide|help|que peux)/.test(lower)) {
      result = { reply: "Je peux analyser vos ventes et votre stock. Essayez : « CA du mois », « plan de réassort », « ruptures de stock », « liste des médicaments », « stock [nom] », « prix [nom] ».", intent: "help" };
    } else if (/(liste.*(médicament|produit|catalogue)|catalogue|tous les médicaments)/i.test(lower)) {
      result = await chatCatalog();
    } else if (/(rupture|stock|inventaire|épuisé)/.test(lower)) {
      const named = await matchProduct(text);
      if (named) { result = named; } else {
        const { data } = await sb.from("stock_balances").select("quantity").eq("pharmacy_id", pid);
        const { data: meds2 } = await sb.from("medications").select("id, reorder_level").eq("pharmacy_id", pid).eq("status", "available");
        let low = 0, out = 0;
        for (const m of (meds2 ?? [])) {
          const stock = (data ?? []).filter((s: any) => s.medication_id === m.id).reduce((a: number, r: any) => a + Number(r.quantity ?? 0), 0);
          if (stock <= 0) out++;
          else if (stock <= Number(m.reorder_level ?? 0)) low++;
        }
        result = { reply: `${low} référence(s) sous seuil, dont ${out} en rupture. Tapez « plan de réassort » pour la liste.`, intent: "stock" };
      }
    } else if (/(réassort|reorder|commander|approvisionn)/.test(lower)) {
      const { data } = await sb.from("medications").select("id, name, reorder_level").eq("pharmacy_id", pid).eq("status", "available");
      const items: any[] = [];
      for (const m of (data ?? [])) {
        const { data: sbData } = await sb.from("stock_balances").select("quantity").eq("pharmacy_id", pid).eq("medication_id", m.id);
        const stock = (sbData ?? []).reduce((a: number, r: any) => a + Number(r.quantity ?? 0), 0);
        if (stock <= Number(m.reorder_level ?? 0)) items.push({ ...m, stock, suggested_qty: Math.max(0, Number(m.reorder_level ?? 0) * 2 - stock) });
      }
      if (!items.length) return json({ data: { reply: "Aucun produit sous seuil. Stock bien tenu !", intent: "reorder" } });
      const top = items.slice(0, 5).map((i: any) => `• ${i.name} : commander ~${i.suggested_qty} u.`);
      const more = items.length > 5 ? `\n… et ${items.length - 5} autre(s).` : "";
      result = { reply: `${items.length} produit(s) à commander :\n${top.join("\n")}${more}`, intent: "reorder", data: { items } };
    } else if (/(prix de|prix du|quel est le prix|combien coûte|combien coute)/.test(lower)) {
      const term = text.replace(/^(quel est|donne moi|donnez moi)?\s*(le\s+)?prix\s+(de|du|des|d')\s*/i, "").replace(/\?/g, "").trim().slice(0, 60);
      if (!term) { result = { reply: "Quel produit recherchez-vous ?", intent: "price" }; }
      else {
        const { data } = await sb.from("medications").select("name, price_sale").eq("pharmacy_id", pid).eq("status", "available").ilike("name", `%${term}%`).limit(3);
        if (!data?.length) { result = { reply: `Aucun produit pour « ${term} ».`, intent: "price" }; }
        else { const lines = data.map((r: any) => `• ${r.name} : ${fmt(r.price_sale)}`); result = { reply: lines.join("\n"), intent: "price", data }; }
      }
    } else if (/(vente|ca\b|chiffre|revenue|panier)/.test(lower)) {
      const d = new Date(); d.setDate(d.getDate() - days);
      const { data } = await sb.from("sales").select("total").eq("pharmacy_id", pid).eq("status", "completed").gte("created_at", d.toISOString());
      const revenue = (data ?? []).reduce((s: number, r: any) => s + Number(r.total ?? 0), 0);
      const nb = data?.length ?? 0;
      const label = days === 1 ? "aujourd'hui" : `${days} derniers jours`;
      const basket = nb > 0 ? ` Panier moyen : ${fmt(revenue / nb)}.` : "";
      result = { reply: `CA ${label} : ${fmt(revenue)} (${nb} vente(s)).${basket}`, intent: "revenue" };
    } else if (/(marge|profit|bénéfice)/.test(lower)) {
      const d = new Date(); d.setDate(d.getDate() - days);
      const { data } = await sb.from("sales").select("total, cost_total").eq("pharmacy_id", pid).eq("status", "completed").gte("created_at", d.toISOString());
      const revenue = (data ?? []).reduce((s: number, r: any) => s + Number(r.total ?? 0), 0);
      const profit = (data ?? []).reduce((s: number, r: any) => s + Number(r.total ?? 0) - Number(r.cost_total ?? 0), 0);
      const pct = revenue > 0 ? ` soit ${Math.round((profit / revenue) * 100)}%` : "";
      result = { reply: `Sur ${days} jours : CA ${fmt(revenue)}, marge ${fmt(profit)}${pct}.`, intent: "margin" };
    } else if (/(top|meilleur|star)/.test(lower)) {
      const { data: items } = await sb.from("sales").select("id").eq("pharmacy_id", pid).eq("status", "completed").gte("created_at", new Date(Date.now() - 30 * 86400000).toISOString());
      result = { reply: `Top produits (30j) : ${items?.length ?? 0} ventes enregistrées.`, intent: "top_products" };
    } else if (/(périm|perim|expir)/.test(lower)) {
      const { data: lots } = await sb.from("lots").select("expiry_date, quantity").eq("pharmacy_id", pid);
      const now2 = new Date();
      const soon = (lots ?? []).filter((l: any) => { const d = new Date(l.expiry_date); return d > now2 && d < new Date(now2.getTime() + 60 * 86400000); });
      result = { reply: `${soon.length} lot(s) expirent dans les 60 prochains jours.`, intent: "expiry" };
    } else if (/(pointe|heure|pic)/.test(lower)) {
      result = { reply: "Analyse des heures de pointe : fonctionnalité en cours de développement.", intent: "peak_hours" };
    } else if (/(débiteur|debiteur|créance|impayé)/.test(lower)) {
      const { data } = await sb.from("customers").select("credit_balance").eq("pharmacy_id", pid);
      const debtors = (data ?? []).filter((c: any) => Number(c.credit_balance ?? 0) > 0);
      const total = debtors.reduce((s: number, c: any) => s + Number(c.credit_balance ?? 0), 0);
      result = { reply: `${debtors.length} client(s) débiteur(s), total ${fmt(total)}.`, intent: "debtors" };
    } else if (/(merci|shokran|thanks)/.test(lower)) {
      result = { reply: "Avec plaisir ! N'hésitez pas pour d'autres questions.", intent: "thanks" };
    } else {
      result = { reply: `Je n'ai pas compris. Essayez : « CA du mois », « plan de réassort », « ruptures de stock », « liste des médicaments ».`, intent: "help" };
    }
    return json({ data: result });
  }

  if (path === "ai/insights") {
    return json({ data: { generated_at: new Date().toISOString(), reorder_soon: [], expiring_within_60d: [], no_sales_30d: [], top_sellers_30d: [], low_margin_30d: [], expired_units: 0 } });
  }
  if (path === "ai/reorder-plan") {
    return json({ data: { generated_at: new Date().toISOString(), days_cover_target: 14, items: [] } });
  }
  if (path === "ai/sales-analysis") {
    return json({ data: { generated_at: new Date().toISOString(), window_days: 30, series: [], summary: { revenue: 0, profit: 0 }, top_products: [] } });
  }

  /* ===========================================================
     CATEGORIES (reference)
     =========================================================== */
  if (path === "reference/categories" || path === "/reference/categories") {
    const { data, error } = await sb.from("reference_categories").select("*").order("name");
    return json({ data: data ?? [], error: error?.message });
  }
  if (path === "reference/sync" && req.method === "POST") {
    return json({ data: { synced: 0, message: "Sync non disponible côté edge" } });
  }

  /* ===========================================================
     BRANCHES — alias for pharmacies (branches = pharmacies)
     =========================================================== */
  if (path === "branches") {
    const { data } = await sb.from("pharmacies").select("id, name, city, address, phone, slug").limit(50);
    return json({ data: data ?? [] });
  }

  /* ===========================================================
     PHARMACIES ME
     =========================================================== */
  if (path === "pharmacies/me") {
    if (req.method === "PUT") {
      const body = await req.json().catch(() => ({}));
      const { error } = await sb.from("pharmacies").update(body).eq("id", pid);
      if (error) return json({ error: { code: "UPDATE_FAILED", message: error.message } }, 400);
      return json({ data: { message: "Pharmacie mise à jour" } });
    }
    const { data } = await sb.from("pharmacies").select("*").eq("id", pid).maybeSingle();
    return json({ data });
  }

  /* ===========================================================
     STOCK ALERTS
     =========================================================== */
  if (path === "stock/alerts") {
    const { data: meds } = await sb.from("medications").select("id, name, reorder_level, min_stock").eq("pharmacy_id", pid).eq("status", "available");
    const { data: balances } = await sb.from("stock_balances").select("medication_id, quantity").eq("pharmacy_id", pid);
    const alerts = (meds ?? [])
      .map((m: any) => {
        const stock = (balances ?? []).filter((b: any) => b.medication_id === m.id).reduce((s: number, r: any) => s + Number(r.quantity ?? 0), 0);
        return { ...m, current_stock: stock, is_low: stock <= Number(m.reorder_level ?? 0), is_out: stock <= 0 };
      })
      .filter((a: any) => a.is_low);
    return json({ data: alerts });
  }

  /* ===========================================================
     STOCK WRITE-OFF
     =========================================================== */
  if (path === "stock/write-off" && req.method === "POST") {
    const body = await req.json().catch(() => ({}));
    const { data, error } = await sb.from("stock_movements").insert({ ...body, pharmacy_id: pid, movement_type: "write_off" }).select().single();
    if (error) return json({ error: { code: "WRITEOFF_FAILED", message: error.message } }, 400);
    return json({ data });
  }

  /* ===========================================================
     USERS — reset-password
     =========================================================== */
  if (/^users\/[^/]+\/reset-password$/.test(path) && req.method === "POST") {
    const userId = path.split("/")[1];
    const { error } = await sb.auth.admin.updateUserById(userId, { password: (await req.json().catch(() => ({}))).newPassword ?? "reset123" });
    if (error) return json({ error: { code: "RESET_FAILED", message: error.message } }, 400);
    return json({ data: { message: "Mot de passe réinitialisé" } });
  }

  /* ===========================================================
     NOTIFICATIONS — read, read-all
     =========================================================== */
  if (/^notifications\/[^/]+\/read$/.test(path) && req.method === "POST") {
    const nId = path.split("/")[1];
    const { error } = await sb.from("notifications").update({ is_read: true }).eq("id", nId);
    if (error) return json({ error: { message: error.message } }, 400);
    return json({ data: { success: true } });
  }
  if (path === "notifications/read-all" && req.method === "POST") {
    await sb.from("notifications").update({ is_read: true }).eq("pharmacy_id", pid).eq("is_read", false);
    return json({ data: { success: true } });
  }

  /* ===========================================================
     EMPLOYEES SUMMARY
     =========================================================== */
  if (path === "employees/summary") {
    const { data } = await sb.from("employees").select("id, status, department").eq("pharmacy_id", pid);
    const total = data?.length ?? 0;
    const active = data?.filter((e: any) => e.status === "active").length ?? 0;
    return json({ data: { total, active, departments: {} } });
  }

  /* ===========================================================
     REPORTS
     =========================================================== */
  if (path === "reports/sales") {
    const d = new Date(); d.setDate(d.getDate() - 30);
    const { data } = await sb.from("sales").select("id, total, cost_total, created_at").eq("pharmacy_id", pid).eq("status", "completed").gte("created_at", d.toISOString()).order("created_at", { ascending: false });
    return json({ data: data ?? [] });
  }
  if (path === "reports/products") {
    const { data } = await sb.from("medications").select("id, name, price_sale").eq("pharmacy_id", pid).eq("status", "available");
    return json({ data: data ?? [] });
  }
  if (path === "reports/stock") {
    const { data: meds } = await sb.from("medications").select("id, name, reorder_level").eq("pharmacy_id", pid).eq("status", "available");
    const { data: bal } = await sb.from("stock_balances").select("medication_id, quantity").eq("pharmacy_id", pid);
    const report = (meds ?? []).map((m: any) => ({
      ...m,
      current_stock: (bal ?? []).filter((b: any) => b.medication_id === m.id).reduce((s: number, r: any) => s + Number(r.quantity ?? 0), 0),
    }));
    return json({ data: report });
  }
  if (path === "reports/employees") {
    const { data } = await sb.from("employees").select("id, first_name, last_name, department, status").eq("pharmacy_id", pid);
    return json({ data: data ?? [] });
  }
  if (path === "reports/financial") {
    const d30 = new Date(); d30.setDate(d30.getDate() - 30);
    const { data: sales } = await sb.from("sales").select("id, total, cost_total, created_at, payment_method").eq("pharmacy_id", pid).eq("status", "completed").gte("created_at", d30.toISOString());
    const { data: expenses } = await sb.from("accounting_entries").select("id, amount, entry_type, created_at").eq("pharmacy_id", pid).gte("created_at", d30.toISOString()).in("entry_type", ["expense", "withdrawal"]);
    const totalSales = (sales ?? []).reduce((s: number, r: any) => s + Number(r.total ?? 0), 0);
    const totalCost = (sales ?? []).reduce((s: number, r: any) => s + Number(r.cost_total ?? 0), 0);
    const totalExpenses = (expenses ?? []).reduce((s: number, r: any) => s + Number(r.amount ?? 0), 0);
    return json({
      data: {
        total_sales: totalSales,
        total_cost: totalCost,
        gross_margin: totalSales - totalCost,
        total_expenses: totalExpenses,
        net_profit: totalSales - totalCost - totalExpenses,
        sales_count: (sales ?? []).length,
        sales: sales ?? [],
        expenses: expenses ?? [],
      },
    });
  }

  /* ===========================================================
     ACCOUNTING — registers, expenses, journal
     =========================================================== */
  if (path === "accounting/registers" && req.method === "POST") {
    const body = await req.json().catch(() => ({}));
    const { data, error } = await sb.from("cash_registers").insert({ ...body, pharmacy_id: pid }).select().single();
    if (error) return json({ error: { message: error.message } }, 400);
    return json({ data });
  }
  if (/^accounting\/registers\/[^/]+\/movements$/.test(path) && req.method === "POST") {
    const body = await req.json().catch(() => ({}));
    const { data, error } = await sb.from("cash_register_movements").insert({ ...body, pharmacy_id: pid }).select().single();
    if (error) return json({ error: { message: error.message } }, 400);
    return json({ data });
  }
  if (/^accounting\/registers\/[^/]+\/close$/.test(path) && req.method === "POST") {
    const regId = path.split("/")[2];
    const { error } = await sb.from("cash_registers").update({ status: "closed", closed_at: new Date().toISOString() }).eq("id", regId);
    if (error) return json({ error: { message: error.message } }, 400);
    return json({ data: { message: "Caisse fermée" } });
  }

  /* ===========================================================
     ATTENDANCE — summary
     =========================================================== */
  if (path === "attendance/summary") {
    const { data } = await sb.from("attendance").select("id, status, clock_in").eq("pharmacy_id", pid);
    return json({ data: { total: data?.length ?? 0, present: data?.filter((a: any) => a.clock_in).length ?? 0 } });
  }

  /* ===========================================================
     PRESCRIPTIONS — dispense
     =========================================================== */
  if (/^prescriptions\/[^/]+\/dispense$/.test(path) && req.method === "POST") {
    const prescId = path.split("/")[2];
    const { error } = await sb.from("prescriptions").update({ status: "dispensed" }).eq("id", prescId);
    if (error) return json({ error: { message: error.message } }, 400);
    return json({ data: { message: "Prescription dispensée" } });
  }

  /* ===========================================================
     WEBSITE
     =========================================================== */
  if (path === "website/settings") {
    if (req.method === "PUT") {
      const body = await req.json().catch(() => ({}));
      const { data: existing } = await sb.from("website_settings").select("id").limit(1).maybeSingle();
      if (existing) {
        await sb.from("website_settings").update(body).eq("id", existing.id);
      } else {
        await sb.from("website_settings").insert({ ...body, pharmacy_id: pid });
      }
      return json({ data: { message: "Paramètres mis à jour" } });
    }
    const { data } = await sb.from("website_settings").select("*").limit(1).maybeSingle();
    return json({ data: data ?? {} });
  }
  if (path === "website/blog/posts" && req.method === "POST") {
    const body = await req.json().catch(() => ({}));
    const { data, error } = await sb.from("blog_posts").insert({ ...body, pharmacy_id: pid }).select().single();
    if (error) return json({ error: { message: error.message } }, 400);
    return json({ data });
  }

  /* ===========================================================
     POS — POST /sales : vente transactionnelle complète
     (sale + sale_items + décrément stock + stock_movements + payments)
     =========================================================== */
  if (path === "sales" && req.method === "POST") {
    try {
      const body = await req.json().catch(() => ({}));
      const branchId = body.branchId ?? body.branch_id;
      const rawSaleType = body.saleType ?? body.sale_type ?? "pos";
      const saleType = ({ pos: "cash", cash: "cash", credit: "credit" }[rawSaleType] ?? "cash") as string;
      const items: any[] = Array.isArray(body.items) ? body.items : [];
      const payments: any[] = Array.isArray(body.payments) ? body.payments : [];
      const customerId = body.customerId ?? body.customer_id ?? body.client_id ?? null;
      const notes = body.notes ?? null;
      if (!branchId) {
        return json({ error: { code: "VALIDATION", message: "branchId requis" } }, 400);
      }
      if (items.length === 0) {
        return json({ error: { code: "VALIDATION", message: "Aucun article dans la vente" } }, 400);
      }

      // Utilisateur connecté (sub du JWT) → user_id de public.users.
      const payload = jwtPayload(req);
      const authEmail = (payload?.email as string) ?? "";
      let userId: string | null = null;
      if (authEmail) {
        const { data: u } = await sb
          .from("users")
          .select("id")
          .ilike("email", authEmail)
          .maybeSingle();
        userId = u?.id ?? null;
      }
      if (!userId) {
        const { data: first } = await sb
          .from("users")
          .select("id")
          .eq("pharmacy_id", pid)
          .eq("status", "active")
          .limit(1)
          .maybeSingle();
        userId = first?.id ?? null;
      }

      // Coordonnées médicaments (coût, TVA) — aucune donnée inventée.
      const medIds = [...new Set(items.map((i: any) => i.medication_id))];
      const { data: meds } = await sb
        .from("medications")
        .select("id, name, price_purchase, price_sale, tva_rate")
        .eq("pharmacy_id", pid)
        .in("id", medIds);
      const medMap = new Map((meds ?? []).map((m: any) => [m.id, m]));

      // Lots disponibles par médicament (FIFO : péremption la plus proche),
      // via les balances de stock de la succursale.
      const { data: stockRows } = await sb
        .from("stock_balances")
        .select("medication_id, lot_id, quantity, lots!inner(expiry_date)")
        .eq("pharmacy_id", pid)
        .eq("branch_id", branchId)
        .gt("quantity", 0)
        .in("medication_id", medIds);
      const lotByMed = new Map<string, string | null>();
      for (const s of stockRows ?? []) {
        const cur = lotByMed.get(s.medication_id);
        if (!cur && Number(s.quantity) > 0) {
          lotByMed.set(s.medication_id, s.lot_id);
        } else if (cur && s.lots?.expiry_date) {
          const curExp = (stockRows ?? []).find((x: any) => x.lot_id === cur)?.lots?.expiry_date;
          if (!curExp || new Date(s.lots.expiry_date) < new Date(curExp)) {
            lotByMed.set(s.medication_id, s.lot_id);
          }
        }
      }

      let subtotal = 0, discountTotal = 0, taxTotal = 0, costTotal = 0, lineCount = 0;
      const rows: any[] = [];
      for (const it of items) {
        const med = medMap.get(it.medication_id);
        if (!med) {
          return json(
            { error: { code: "INVALID_ITEM", message: `Médicament ${it.medication_id} introuvable` } },
            400,
          );
        }
        const qty = Number(it.quantity ?? 0);
        const unitPrice = Number(it.unit_price ?? med.price_sale ?? 0);
        const discountPct = Number(it.discount ?? 0);
        if (qty <= 0) continue;
        const gross = unitPrice * qty;
        const discountAmt = gross * (discountPct / 100);
        const net = gross - discountAmt;
        const tvaRate = Number(med.tva_rate ?? 0) || 0;
        const tvaAmt = net * (tvaRate / 100);
        const cost = Number(med.price_purchase ?? 0) * qty;
        subtotal += net;
        discountTotal += discountAmt;
        taxTotal += tvaAmt;
        costTotal += cost;
        lineCount += qty;
        rows.push({
          medication_id: med.id,
          lot_id: lotByMed.get(med.id) ?? null,
          quantity: qty,
          unit_price: unitPrice,
          cost_price: Number(med.price_purchase ?? 0),
          tva_rate: tvaRate,
          discount: discountPct,
        });
      }
      if (rows.length === 0) {
        return json({ error: { code: "VALIDATION", message: "Aucun article valide" } }, 400);
      }
      const total = subtotal + taxTotal;
      const paidAmount =
        payments.reduce((s: number, p: any) => s + Number(p.amount ?? 0), 0);
      const changeAmount = Math.max(0, paidAmount - total);
      const paymentMethod = payments[0]?.method ?? "cash";

      // Numéro de vente séquentiel atomique par pharmacie (FN next_number).
      const { data: numberData, error: numErr } = await sb.rpc("fn_next_number", {
        p_pharmacy: pid,
        p_prefix: "POS",
      });
      let number = numErr ? null : numberData;
      if (!number) {
        number = `POS-${Date.now()}`;
      }

      // 1) Vente
      const { data: sale, error: saleErr } = await sb
        .from("sales")
        .insert({
          pharmacy_id: pid,
          branch_id: branchId,
          user_id: userId,
          customer_id: customerId,
          number,
          sale_type: saleType,
          status: "completed",
          subtotal: Number(subtotal.toFixed(2)),
          discount_total: Number(discountTotal.toFixed(2)),
          tax_total: Number(taxTotal.toFixed(2)),
          total: Number(total.toFixed(2)),
          cost_total: Number(costTotal.toFixed(2)),
          paid_amount: Number(paidAmount.toFixed(2)),
          change_amount: Number(changeAmount.toFixed(2)),
          payment_method: paymentMethod,
          notes,
        })
        .select()
        .single();
      if (saleErr) {
        console.error("[sales] insert error:", saleErr.message);
        return json({ error: { code: "SALE_FAILED", message: saleErr.message } }, 400);
      }

      // 2) Lignes + décrément stock (déclenché par le trigger fn_apply_stock_movement
      //    à l'insertion du stock_movement de type 'sale').
      for (const r of rows) {
        const { error: itemErr } = await sb.from("sale_items").insert({
          pharmacy_id: pid,
          sale_id: sale.id,
          ...r,
          unit_cost: Number(r.cost_price ?? 0),
          discount_percent: Number(r.discount ?? 0),
          tax_rate: Number(r.tva_rate ?? 0),
        });
        if (itemErr) {
          console.error("[sales] sale_items error:", itemErr.message);
        }
        await sb.from("stock_movements").insert({
          pharmacy_id: pid,
          branch_id: branchId,
          medication_id: r.medication_id,
          lot_id: r.lot_id,
          movement_type: "sale",
          quantity: Number(r.quantity) * -1,
          unit_cost: r.cost_price,
          reference_type: "sale",
          reference_id: sale.id,
          user_id: userId,
          notes: `Vente ${number}`,
        });
      }

      // 3) Paiements
      for (const p of payments) {
        await sb.from("payments").insert({
          pharmacy_id: pid,
          sale_id: sale.id,
          customer_id: customerId,
          method: p.method ?? "cash",
          amount: Number(p.amount ?? 0),
          status: "completed",
          received_by: userId,
          reference: p.reference ?? null,
        });
      }

      return json({
        data: {
          id: sale.id,
          number: sale.number,
          total: sale.total,
          lineCount,
        },
      });
    } catch (e) {
      console.error("[sales] exception:", String(e));
      return json({ error: { code: "SALE_ERROR", message: String(e) } }, 500);
    }
  }

  /* ===========================================================
     PUBLIC WEBSITE — blog post by slug
     =========================================================== */
  if (/^blog\/[^/]+$/.test(path) && req.method === "GET") {
    const slug = path.split("/")[1];
    const { data } = await sb.from("blog_posts").select("*").eq("slug", slug).maybeSingle();
    return json({ data });
  }

  /* ===========================================================
     GENERIC TABLE PROXY — catalog, suppliers, customers,
     employees, cameras, roles, users, notifications,
     prescriptions, purchases, sales, accounting, attendance, etc.
     =========================================================== */
  const genericMatch = path.match(
    /^(catalog\/medications|catalog\/categories|catalog\/laboratories|catalog\/families|suppliers|customers|employees|cameras|branches|roles|role_permissions|permissions|users|notifications|prescriptions|pharmacies|purchases\/orders|purchases\/receptions|sales|sale-items|sale-returns|payments|invoices|invoice-items|stock\/adjustments|stock\/balances|stock\/movements|stock\/lots|stock\/transfers|accounting\/accounts|accounting\/journal|accounting\/expense-categories|accounting\/expenses|accounting\/registers|accounting\/closings|attendance\/leaves|attendance\/schedules|reference\/categories|website\/settings|website\/blog\/posts|support\/tickets|backups)(?:\/(.+))?$/,
  );
  if (genericMatch) {
    const [, basePath, sub] = genericMatch;
    const table = TABLE_MAP[`/${basePath}`];
    if (table) {
      return await proxyToTable(serviceKey, supabaseUrl, req, table, sub ?? "", pid);
    }
  }

  /* ===========================================================
     ROOT
     =========================================================== */
  if (path === "/" || path === "") {
    return json({
      name: "PHARMA+ Edge API (Supabase)",
      version: "2.1.0",
      health: "/health",
      auth: "/auth/login",
    });
  }

  /* ===========================================================
     404
     =========================================================== */
  return json(
    { error: { code: "NOT_FOUND", message: `Route ${path} non trouvée` } },
    404,
  );
});
