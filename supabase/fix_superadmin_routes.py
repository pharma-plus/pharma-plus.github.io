with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\supabase\functions\pharma-api\index.ts', 'r', encoding='utf-8') as f:
    content = f.read()

old = """  /* ===========================================================
     ROOT
     =========================================================== */
  if (path === "/" || path === "") {"""

new = """/* ===========================================================
     SUPERADMIN — CRM Commercial & Gestion Société
     =========================================================== */
  // Guard: superadmin only
  const superadminPaths = [
    "superadmin/stats",
    "superadmin/pharmacies",
    "superadmin/prospects",
    "superadmin/invoices",
    "superadmin/tickets",
    "superadmin/roles",
  ];
  const isSuperadminPath = superadminPaths.some(
    (p) => path === p || path.startsWith(p + "/"),
  );
  if (isSuperadminPath) {
    const sa = await requireSuperAdmin(sb, req);
    if (!sa.allowed)
      return json(
        {
          error: {
            code: "FORBIDDEN",
            message: "Accès réservé au super administrateur",
          },
        },
        403,
      );
  }

  // Superadmin stats
  if (path === "superadmin/stats" && req.method === "GET") {
    try {
      const [
        pharmacies,
        users,
        sales,
        revenue,
        activeLicenses,
        prospects,
        tickets,
      ] = await Promise.all([
        sb.from("pharmacies").select("status, license_type", { count: "exact" }),
        sb.from("users").select("id", { count: "exact" }).eq("status", "active"),
        sb.from("sales").select("id", { count: "exact" }),
        sb.from("sales").select("total"),
        sb
          .from("pharmacies")
          .select("license_type")
          .eq("status", "active")
          .not("license_type", "is", null),
        sb.from("prospects").select("id", { count: "exact" }),
        sb.from("tickets").select("id", { count: "exact" }),
      ]);

      const phTotal = pharmacies.count ?? 0;
      const phActive =
        pharmacies.data?.filter((p: any) => p.status === "active").length ?? 0;
      const phTrial =
        pharmacies.data?.filter((p: any) => p.license_type === "trial").length ??
        0;
      const rev = revenue.data?.reduce((sum: number, s: any) => sum + (s.total ?? 0), 0) ?? 0;

      return json({
        data: {
          pharmacies: { total: phTotal, active: phActive, trial: phTrial },
          users: users.count ?? 0,
          sales: sales.count ?? 0,
          revenue: rev,
          activeLicenses: activeLicenses.data?.length ?? 0,
          prospects: prospects.count ?? 0,
          tickets: tickets.count ?? 0,
        },
      });
    } catch (e) {
      return json({ error: { code: "QUERY_FAILED", message: String(e) } }, 500);
    }
  }

  // Superadmin pharmacies
  if (path === "superadmin/pharmacies") {
    if (req.method === "GET") {
      try {
        const { data, error } = await sb
          .from("pharmacies")
          .select(
            "id, name, slug, city, email, phone, status, license_type, license_expiry, created_at",
          )
          .order("created_at", { ascending: false })
          .limit(200);
        if (error)
          return json(
            { error: { code: "QUERY_FAILED", message: error.message } },
            500,
          );

        // Enrich with counts
        const pharmacyIds = (data ?? []).map((p: any) => p.id);
        const [usersCount, branchesCount] = await Promise.all([
          sb
            .from("users")
            .select("pharmacy_id", { count: "exact" })
            .in("pharmacy_id", pharmacyIds),
          sb
            .from("branches")
            .select("pharmacy_id", { count: "exact" })
            .in("pharmacy_id", pharmacyIds),
        ]);

        const usersMap = new Map<string, number>();
        const branchesMap = new Map<string, number>();
        (usersCount.data ?? []).forEach((u: any) => {
          usersMap.set(u.pharmacy_id, (usersMap.get(u.pharmacy_id) ?? 0) + 1);
        });
        (branchesCount.data ?? []).forEach((b: any) => {
          branchesMap.set(b.pharmacy_id, (branchesMap.get(b.pharmacy_id) ?? 0) + 1);
        });

        const enriched = (data ?? []).map((p: any) => ({
          ...p,
          nb_users: usersMap.get(p.id) ?? 0,
          nb_branches: branchesMap.get(p.id) ?? 0,
        }));

        return json({ data: enriched });
      } catch (e) {
        return json({ error: { code: "QUERY_FAILED", message: String(e) } }, 500);
      }
    }

    if (req.method === "POST") {
      try {
        const body = await req.json().catch(() => ({}));
        const { name, slug, city, email, phone, address, license_type } = body ?? {};
        if (!name || !slug)
          return json(
            {
              error: { code: "VALIDATION", message: "name + slug requis" },
            },
            400,
          );
        const normalizedSlug = String(slug).trim().toLowerCase();
        const { data: dup } = await sb
          .from("pharmacies")
          .select("id")
          .eq("slug", normalizedSlug)
          .maybeSingle();
        if (dup)
          return json(
            { error: { code: "CONFLICT", message: "slug déjà utilisé" } },
            409,
          );
        const { data, error } = await sb.from("pharmacies").insert({
          name,
          slug: normalizedSlug,
          city,
          email,
          phone,
          address,
          license_type: license_type ?? "trial",
          status: "active",
        }).select().single();
        if (error)
          return json(
            { error: { code: "CREATE_FAILED", message: error.message } },
            500,
          );
        return json({ data });
      } catch (e) {
        return json({ error: { code: "CREATE_FAILED", message: String(e) } }, 500);
      }
    }
    return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
  }

  // Superadmin prospects
  if (path === "superadmin/prospects") {
    if (req.method === "GET") {
      try {
        const { data, error } = await sb
          .from("prospects")
          .select("*")
          .order("created_at", { ascending: false })
          .limit(200);
        if (error)
          return json(
            { error: { code: "QUERY_FAILED", message: error.message } },
            500,
          );
        return json({ data: data ?? [] });
      } catch (e) {
        return json({ error: { code: "QUERY_FAILED", message: String(e) } }, 500);
      }
    }
    if (req.method === "POST") {
      try {
        const body = await req.json().catch(() => ({}));
        const { name, company, email, phone, estimated_value } = body ?? {};
        if (!name)
          return json(
            { error: { code: "VALIDATION", message: "name requis" } },
            400,
          );
        const { data, error } = await sb.from("prospects").insert({
          name,
          company,
          email,
          phone,
          estimated_value: estimated_value ?? 0,
          status: "new",
        }).select().single();
        if (error)
          return json(
            { error: { code: "CREATE_FAILED", message: error.message } },
            500,
          );
        return json({ data });
      } catch (e) {
        return json({ error: { code: "CREATE_FAILED", message: String(e) } }, 500);
      }
    }
    return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
  }

  // Superadmin invoices
  if (path === "superadmin/invoices") {
    if (req.method === "GET") {
      try {
        const { data, error } = await sb
          .from("invoices")
          .select("*, pharmacies(name)")
          .order("created_at", { ascending: false })
          .limit(200);
        if (error)
          return json(
            { error: { code: "QUERY_FAILED", message: error.message } },
            500,
          );
        return json({ data: data ?? [] });
      } catch (e) {
        return json({ error: { code: "QUERY_FAILED", message: String(e) } }, 500);
      }
    }
    if (req.method === "POST") {
      try {
        const body = await req.json().catch(() => ({}));
        const { number, pharmacy_id, amount, status } = body ?? {};
        if (!number || !pharmacy_id || !amount)
          return json(
            {
              error: {
                code: "VALIDATION",
                message: "number + pharmacy_id + amount requis",
              },
            },
            400,
          );
        const { data, error } = await sb.from("invoices").insert({
          number,
          pharmacy_id,
          amount,
          status: status ?? "pending",
        }).select().single();
        if (error)
          return json(
            { error: { code: "CREATE_FAILED", message: error.message } },
            500,
          );
        return json({ data });
      } catch (e) {
        return json({ error: { code: "CREATE_FAILED", message: String(e) } }, 500);
      }
    }
    return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
  }

  // Superadmin tickets
  if (path === "superadmin/tickets") {
    if (req.method === "GET") {
      try {
        const { data, error } = await sb
          .from("tickets")
          .select("*, pharmacies(name)")
          .order("created_at", { ascending: false })
          .limit(200);
        if (error)
          return json(
            { error: { code: "QUERY_FAILED", message: error.message } },
            500,
          );
        return json({ data: data ?? [] });
      } catch (e) {
        return json({ error: { code: "QUERY_FAILED", message: String(e) } }, 500);
      }
    }
    if (req.method === "POST") {
      try {
        const body = await req.json().catch(() => ({}));
        const { subject, description, pharmacy_id, priority } = body ?? {};
        if (!subject || !pharmacy_id)
          return json(
            {
              error: {
                code: "VALIDATION",
                message: "subject + pharmacy_id requis",
              },
            },
            400,
          );
        const { data, error } = await sb.from("tickets").insert({
          subject,
          description,
          pharmacy_id,
          priority: priority ?? "medium",
          status: "open",
        }).select().single();
        if (error)
          return json(
            { error: { code: "CREATE_FAILED", message: error.message } },
            500,
          );
        return json({ data });
      } catch (e) {
        return json({ error: { code: "CREATE_FAILED", message: String(e) } }, 500);
      }
    }
    return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
  }

  // Superadmin roles
  if (path === "superadmin/roles" || path.startsWith("superadmin/roles/")) {
    const roleId = path.replace("superadmin/roles/", "");
    const isSingle = roleId && roleId !== "superadmin/roles";

    // Check superadmin for all role operations
    const saRole = await requireSuperAdmin(sb, req);
    if (!saRole.allowed)
      return json(
        {
          error: {
            code: "FORBIDDEN",
            message: "Gestion des rôles réservée au super administrateur",
          },
        },
        403,
      );

    if (req.method === "GET") {
      if (isSingle) {
        // Get single role with permissions
        try {
          const { data, error } = await sb
            .from("roles")
            .select("*, role_permissions(permission_code)")
            .eq("id", roleId)
            .maybeSingle();
          if (error)
            return json(
              { error: { code: "QUERY_FAILED", message: error.message } },
              500,
            );
          if (!data)
            return json(
              { error: { code: "NOT_FOUND", message: "Rôle introuvable" } },
              404,
            );
          return json({ data });
        } catch (e) {
          return json({ error: { code: "QUERY_FAILED", message: String(e) } }, 500);
        }
      } else {
        // List all roles
        try {
          const { data, error } = await sb
            .from("roles")
            .select("*, role_permissions(permission_code)")
            .order("name");
          if (error)
            return json(
              { error: { code: "QUERY_FAILED", message: error.message } },
              500,
            );
          return json({ data: data ?? [] });
        } catch (e) {
          return json({ error: { code: "QUERY_FAILED", message: String(e) } }, 500);
        }
      }
    }

    if (req.method === "POST") {
      try {
        const body = await req.json().catch(() => ({}));
        const { name, code, description } = body ?? {};
        if (!name || !code)
          return json(
            { error: { code: "VALIDATION", message: "name + code requis" } },
            400,
          );
        const normalizedCode = String(code).trim().toLowerCase();
        const { data: dup } = await sb
          .from("roles")
          .select("id")
          .eq("code", normalizedCode)
          .maybeSingle();
        if (dup)
          return json(
            { error: { code: "CONFLICT", message: "code déjà utilisé" } },
            409,
          );
        const { data, error } = await sb.from("roles").insert({
          name,
          code: normalizedCode,
          description,
          is_system: false,
        }).select().single();
        if (error)
          return json(
            { error: { code: "CREATE_FAILED", message: error.message } },
            500,
          );
        return json({ data });
      } catch (e) {
        return json({ error: { code: "CREATE_FAILED", message: String(e) } }, 500);
      }
    }

    if (isSingle && (req.method === "PUT" || req.method === "PATCH")) {
      try {
        const body = await req.json().catch(() => ({}));
        const { name, code, description } = body ?? {};
        const updateData: any = {};
        if (name) updateData.name = name;
        if (code) updateData.code = String(code).trim().toLowerCase();
        if (description !== undefined) updateData.description = description;
        const { data, error } = await sb
          .from("roles")
          .update(updateData)
          .eq("id", roleId)
          .select()
          .maybeSingle();
        if (error)
          return json(
            { error: { code: "UPDATE_FAILED", message: error.message } },
            500,
          );
        if (!data)
          return json(
            { error: { code: "NOT_FOUND", message: "Rôle introuvable" } },
            404,
          );
        return json({ data });
      } catch (e) {
        return json({ error: { code: "UPDATE_FAILED", message: String(e) } }, 500);
      }
    }

    if (isSingle && req.method === "DELETE") {
      try {
        const { error } = await sb.from("roles").delete().eq("id", roleId);
        if (error)
          return json(
            { error: { code: "DELETE_FAILED", message: error.message } },
            500,
          );
        return json({ data: { message: "Rôle supprimé" } });
      } catch (e) {
        return json({ error: { code: "DELETE_FAILED", message: String(e) } }, 500);
      }
    }

    // Permissions management
    if (isSingle && path === `superadmin/roles/${roleId}/permissions` && req.method === "PUT") {
      try {
        const body = await req.json().catch(() => ({}));
        const permissions = body?.permissions; // Map<module, string[]>
        if (!permissions || typeof permissions !== "object")
          return json(
            { error: { code: "VALIDATION", message: "permissions requis" } },
            500,
          );
        // Delete existing permissions
        await sb.from("role_permissions").delete().eq("role_id", roleId);
        // Insert new permissions
        const permsToInsert = Object.entries(permissions).flatMap(([module, actions]) =>
          (actions as string[]).map((action) => ({
            role_id: roleId,
            module,
            action,
          }))
        );
        if (permsToInsert.length > 0) {
          const { error } = await sb.from("role_permissions").insert(permsToInsert);
          if (error)
            return json(
              { error: { code: "UPDATE_FAILED", message: error.message } },
              500,
            );
        }
        return json({ data: { message: "Permissions mises à jour" } });
      } catch (e) {
        return json({ error: { code: "UPDATE_FAILED", message: String(e) } }, 500);
      }
    }

    return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
  }

  /* ===========================================================
     ROOT
     =========================================================== */
  if (path === "/" || path === "") {"""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\supabase\functions\pharma-api\index.ts', 'w', encoding='utf-8') as f:
        f.write(content)
    print('REPLACED')
else:
    print('NOT FOUND')