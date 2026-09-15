import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';

export const cameraService = {
  async list(pharmacyId, { branchId = null } = {}) {
    const params = [pharmacyId];
    let where = 'WHERE c.pharmacy_id = $1';
    if (branchId) { params.push(branchId); where += ' AND c.branch_id = $2'; }
    const { rows } = await query(
      `SELECT c.*, b.name AS branch_name,
              (SELECT count(*)::int FROM camera_recordings r
                WHERE r.camera_id = c.id AND r.status = 'recording') AS recording_count
         FROM cameras c LEFT JOIN branches b ON b.id = c.branch_id
        ${where} ORDER BY c.name`,
      params,
    );
    return rows;
  },

  async create(pharmacyId, data, actor) {
    const id = uuid();
    await query(
      `INSERT INTO cameras (id, pharmacy_id, branch_id, name, location, stream_url,
                            snapshot_url, position_x, position_y, status, is_enabled)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [id, pharmacyId, data.branch_id ?? null, data.name, data.location ?? null,
       data.stream_url ?? null, data.snapshot_url ?? null, data.position_x ?? 0,
       data.position_y ?? 0, data.status ?? 'offline', data.is_enabled ?? true],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'cameras', entity: 'camera', entityId: id, newValues: { name: data.name } });
    return this.get(pharmacyId, id);
  },

  async get(pharmacyId, id) {
    const { rows } = await query(
      `SELECT c.*, b.name AS branch_name FROM cameras c
        LEFT JOIN branches b ON b.id = c.branch_id
       WHERE c.id = $1 AND c.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Caméra introuvable');
    return rows[0];
  },

  async update(pharmacyId, id, data, actor) {
    const existing = await this.get(pharmacyId, id);
    const fields = [];
    const params = [id, pharmacyId];
    let i = 3;
    const map = {
      branch_id: 'branch_id', name: 'name', location: 'location', stream_url: 'stream_url',
      snapshot_url: 'snapshot_url', position_x: 'position_x', position_y: 'position_y',
      status: 'status', is_enabled: 'is_enabled',
    };
    for (const [key, value] of Object.entries(data)) {
      if (!(key in map) || value === undefined) continue;
      fields.push(`${map[key]} = $${i}`);
      params.push(value);
      i++;
    }
    if (fields.length) {
      await query(`UPDATE cameras SET ${fields.join(', ')} WHERE id = $1 AND pharmacy_id = $2`, params);
    }
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'cameras', entity: 'camera', entityId: id, oldValues: { name: existing.name }, newValues: data });
    return this.get(pharmacyId, id);
  },

  async remove(pharmacyId, id, actor) {
    const { rows } = await query(
      `DELETE FROM cameras WHERE id = $1 AND pharmacy_id = $2 RETURNING id`, [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Caméra introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: 'delete', module: 'cameras', entity: 'camera', entityId: id });
  },

  async startRecording(pharmacyId, cameraId, actor) {
    const camera = await this.get(pharmacyId, cameraId);
    const id = uuid();
    await query(
      `INSERT INTO camera_recordings (id, pharmacy_id, camera_id, status)
       VALUES ($1,$2,$3,'recording')`,
      [id, pharmacyId, cameraId],
    );
    await query(`UPDATE cameras SET status = 'recording' WHERE id = $1`, [cameraId]);
    await auditLog({ pharmacyId, userId: actor?.id, action: 'start', module: 'cameras', entity: 'camera_recording', entityId: id, newValues: { camera: camera.name } });
    return { id, started_at: new Date() };
  },

  async stopRecording(pharmacyId, cameraId, actor) {
    await this.get(pharmacyId, cameraId);
    const { rows } = await query(
      `UPDATE camera_recordings
          SET ended_at = now(), status = 'completed'
        WHERE camera_id = $1 AND pharmacy_id = $2 AND status = 'recording'
        RETURNING id`,
      [cameraId, pharmacyId],
    );
    if (rows[0]) {
      await query(`UPDATE cameras SET status = 'online' WHERE id = $1`, [cameraId]);
      await auditLog({ pharmacyId, userId: actor?.id, action: 'stop', module: 'cameras', entity: 'camera_recording', entityId: rows[0].id, newValues: { cameraId } });
    }
    return rows[0] ?? null;
  },

  async recordings(pharmacyId, cameraId, { limit = 30 } = {}) {
    const params = [pharmacyId, limit];
    let where = 'WHERE r.pharmacy_id = $1';
    if (cameraId) { params.unshift(cameraId); where = 'WHERE r.camera_id = $1 AND r.pharmacy_id = $2'; }
    const { rows } = await query(
      `SELECT r.id, r.camera_id, c.name AS camera_name, r.started_at, r.ended_at,
              r.file_url, r.size_bytes, r.status
         FROM camera_recordings r LEFT JOIN cameras c ON c.id = r.camera_id
        ${where} ORDER BY r.started_at DESC LIMIT $${params.length}`,
      params,
    );
    return rows;
  },
};
