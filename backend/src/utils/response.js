/** Réponse API normalisée. */
export function ok(res, data, meta = undefined) {
  const body = { success: true, data };
  if (meta !== undefined) body.meta = meta;
  return res.json(body);
}

export function created(res, data) {
  return res.status(201).json({ success: true, data });
}

export function noContent(res) {
  return res.status(204).end();
}

/** Construit les métadonnées de pagination. */
export function paginate(page = 1, limit = 20, total = 0) {
  const p = Math.max(1, parseInt(page, 10) || 1);
  const l = Math.min(200, Math.max(1, parseInt(limit, 10) || 20));
  return {
    page: p,
    limit: l,
    total,
    pages: Math.max(1, Math.ceil(total / l)),
    offset: (p - 1) * l,
  };
}
