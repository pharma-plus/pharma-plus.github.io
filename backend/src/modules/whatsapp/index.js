import { Router } from 'express';
import { AppError } from '../../utils/errors.js';
import { requirePerm } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { uuid } from '../../utils/crypto.js';
import crypto from 'node:crypto';

const router = Router();

// Configuration WhatsApp Business (à lier aux vraies credentials Meta plus tard)
const WHATSAPP_CONFIG = {
  phone_number_id: process.env.WHATSAPP_PHONE_NUMBER_ID || '',
  access_token: process.env.WHATSAPP_ACCESS_TOKEN || '',
  business_account_id: process.env.WHATSAPP_BUSINESS_ACCOUNT_ID || '',
  webhook_verify_token: process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN || '',
};

// ── GET /whatsapp/config ──
router.get(
  '/config',
  requirePerm('whatsapp:view'),
  async (_req, res) => {
    // SÉCURITÉ : aucun jeton Meta (access_token, webhook_verify_token) ne
    // quitte JAMAIS le serveur. Le frontend ne reçoit que des indicateurs de
    // configuration (présence + masque) pour l'affichage.
    const mask = (v) => (v ? `${v.slice(0, 4)}••••${v.slice(-4)}` : '');
    res.json({
      success: true,
      data: {
        phone_number_id: WHATSAPP_CONFIG.phone_number_id,
        business_account_id: WHATSAPP_CONFIG.business_account_id,
        access_token_set: Boolean(WHATSAPP_CONFIG.access_token),
        access_token_masked: mask(WHATSAPP_CONFIG.access_token),
        webhook_verify_token_set: Boolean(WHATSAPP_CONFIG.webhook_verify_token),
      },
    });
  }
);

// ── GET /whatsapp/conversations ──
router.get(
  '/conversations',
  requirePerm('whatsapp:view'),
  validate({ query: { limit: 'number', q: 'string' } }),
  async (req, res) => {
    const { limit = 50, q } = req.query;
    const pharmacyId = req.user.pharmacyId;

    let sql = `
      SELECT c.id, c.contact_phone, c.contact_name, c.last_message,
             c.last_message_at, c.status, c.unread_count,
             u.name AS assigned_to_name
      FROM whatsapp_conversations c
      LEFT JOIN users u ON u.id = c.assigned_to
      WHERE c.pharmacy_id = $1
    `;
    const params = [pharmacyId];

    if (q) {
      sql += ` AND (c.contact_name ILIKE $${params.length + 1} OR c.contact_phone ILIKE $${params.length + 1})`;
      params.push(`%${q}%`);
    }

    sql += ` ORDER BY c.last_message_at DESC NULLS LAST, c.updated_at DESC LIMIT $${params.length + 1}`;
    params.push(Number(limit));

    const { rows } = await query(sql, params);

    res.json({
      success: true,
      data: rows.map((r) => ({
        id: r.id,
        contactPhone: r.contact_phone,
        contactName: r.contact_name,
        lastMessage: r.last_message,
        lastMessageAt: r.last_message_at,
        status: r.status,
        unreadCount: r.unread_count,
        assignedTo: r.assigned_to_name,
      })),
    });
  }
);

// ── GET /whatsapp/conversations/:id/messages ──
router.get(
  '/conversations/:conversationId/messages',
  requirePerm('whatsapp:view'),
  validate({ query: { limit: 'number' } }),
  async (req, res) => {
    const { conversationId } = req.params;
    const { limit = 50 } = req.query;
    const pharmacyId = req.user.pharmacyId;

    // Vérifier que la conversation appartient à la pharmacie
    const { rows: convRows } = await query(
      'SELECT id FROM whatsapp_conversations WHERE id = $1 AND pharmacy_id = $2',
      [conversationId, pharmacyId]
    );
    if (!convRows[0]) {
      throw new AppError('Conversation introuvable', 404, 'CONVERSATION_NOT_FOUND');
    }

    const { rows } = await query(
      `SELECT m.id, m.from_me, m.content, m.message_type, m.timestamp,
              m.wa_message_id, m.status, u.name AS sender_name
       FROM whatsapp_messages m
       LEFT JOIN users u ON u.id = m.sender_id
       WHERE m.conversation_id = $1
       ORDER BY m.timestamp ASC
       LIMIT $2`,
      [conversationId, Number(limit)]
    );

    res.json({
      success: true,
      data: rows.map((r) => ({
        id: r.id,
        fromMe: r.from_me,
        content: r.content,
        type: r.message_type,
        timestamp: r.timestamp,
        waMessageId: r.wa_message_id,
        status: r.status,
        senderName: r.sender_name,
      })),
    });
  }
);

// ── POST /whatsapp/conversations ── (créer une conversation sortante)
router.post(
  '/conversations',
  requirePerm('whatsapp:edit'),
  validate({ body: { contact_phone: 'string', contact_name: 'string' } }),
  async (req, res) => {
    const { contact_phone, contact_name } = req.body;
    const pharmacyId = req.user.pharmacyId;
    const userId = req.user.id;

    const { rows } = await query(
      `INSERT INTO whatsapp_conversations (pharmacy_id, contact_phone, contact_name, status, unread_count, created_at, updated_at)
       VALUES ($1, $2, $3, 'active', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
       RETURNING id, contact_phone, contact_name, status, unread_count`,
      [pharmacyId, contact_phone, contact_name]
    );

    res.status(201).json({
      success: true,
      data: {
        id: rows[0].id,
        contactPhone: rows[0].contact_phone,
        contactName: rows[0].contact_name,
        status: rows[0].status,
        unreadCount: rows[0].unread_count,
      },
    });
  }
);

export const whatsappRouter = router;
export const whatsappService = {};

// ── POST /whatsapp/webhook ── (réception des messages WhatsApp entrants)
router.post(
  '/webhook',
  async (req, res) => {
    // SÉCURITÉ : validation de la signature Meta (X-Hub-Signature-256) dès
    // que WHATSAPP_APP_SECRET est configuré. Sans secret configuré, le
    // webhook reste ouvert (mode démonstration) mais c'est signalé dans les
    // logs — la mise en production DOIT définir WHATSAPP_APP_SECRET.
    const appSecret = process.env.WHATSAPP_APP_SECRET || '';
    if (appSecret) {
      const raw = typeof req.rawBody === 'string' || Buffer.isBuffer(req.rawBody)
        ? req.rawBody
        : JSON.stringify(req.body ?? {});
      const expected =
        'sha256=' +
        crypto.createHmac('sha256', appSecret).update(raw).digest('hex');
      const provided = String(req.headers['x-hub-signature-256'] ?? '');
      const a = Buffer.from(expected);
      const b = Buffer.from(provided);
      const okSig = a.length === b.length && crypto.timingSafeEqual(a, b);
      if (!okSig) {
        return res.status(401).json({ success: false, error: 'Invalid signature' });
      }
    }

    const { entry } = req.body;
    if (!entry) {
      return res.status(400).json({ success: false, error: 'Invalid webhook payload' });
    }

    // Multi-tenant : les conversations entrantes sont rattachées à la
    // pharmacie propriétaire du numéro WhatsApp (WHATSAPP_DEFAULT_PHARMACY_ID).
    // Sans cette variable, comportement historique (pharmacy_id NULL) conservé.
    const defaultPharmacyId = process.env.WHATSAPP_DEFAULT_PHARMACY_ID || null;

    for (const e of entry) {
      const changes = e.changes || [];
      for (const change of changes) {
        const value = change.value || {};
        const messages = value.messages || [];
        const statuses = value.statuses || [];

        // Traiter les messages entrants
        for (const msg of messages) {
          const conversationId = msg.from; // numéro de téléphone comme identifiant de conversation
          const content = msg.text?.body || msg.interactive?.body?.text || '';
          const messageType = msg.type || 'text';
          const waMessageId = msg.id;

          // Trouver ou créer la conversation — TOUJOURS rattachée à la
          // pharmacie configurée (jamais de collision inter-pharmacies).
          let convId;
          const convSql = defaultPharmacyId
            ? `SELECT id FROM whatsapp_conversations WHERE contact_phone = $1 AND pharmacy_id = $2 LIMIT 1`
            : `SELECT id FROM whatsapp_conversations WHERE contact_phone = $1 AND pharmacy_id IS NULL LIMIT 1`;
          const { rows: convRows } = await query(
            convSql,
            defaultPharmacyId ? [conversationId, defaultPharmacyId] : [conversationId]
          );
          if (convRows.length > 0) {
            convId = convRows[0].id;
          } else {
            const insertSql = defaultPharmacyId
              ? `INSERT INTO whatsapp_conversations (id, pharmacy_id, contact_phone, contact_name, status, unread_count, created_at, updated_at)
                 VALUES ($1, $2, $3, $4, 'active', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                 RETURNING id`
              : `INSERT INTO whatsapp_conversations (id, contact_phone, contact_name, status, unread_count, created_at, updated_at)
                 VALUES ($1, $2, $3, 'active', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                 RETURNING id`;
            const { rows: newConv } = await query(
              insertSql,
              defaultPharmacyId
                ? [uuid(), defaultPharmacyId, conversationId, 'Contact WhatsApp']
                : [uuid(), conversationId, 'Contact WhatsApp']
            );
            convId = newConv[0].id;
          }

          // Insérer le message
          await query(
            `INSERT INTO whatsapp_messages (id, conversation_id, wa_message_id, from_me, content, message_type, status, timestamp, created_at)
             VALUES ($1, $2, $3, 0, $4, $5, 'delivered', $6, CURRENT_TIMESTAMP)`,
            [uuid(), convId, waMessageId, content, messageType, new Date(msg.timestamp * 1000).toISOString()]
          );

          // Mettre à jour la conversation
          await query(
            `UPDATE whatsapp_conversations SET last_message = $1, last_message_at = CURRENT_TIMESTAMP, unread_count = unread_count + 1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
            [content, convId]
          );
        }

        // Traiter les statuts de message
        for (const status of statuses) {
          await query(
            `UPDATE whatsapp_messages SET status = $1 WHERE wa_message_id = $2`,
            [status.status, status.id]
          );
        }
      }
    }

    res.status(200).json({ success: true });
  }
);

// ── GET /whatsapp/webhook ── (vérification du webhook Meta)
router.get(
  '/webhook',
  async (req, res) => {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    // SÉCURITÉ : pas de jeton de repli codé en dur — si WHATSAPP_WEBHOOK_VERIFY_TOKEN
    // n'est pas configuré, la vérification échoue toujours (403) au lieu
    // d'accepter n'importe quel appel.
    const verifyToken = process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN || '';

    if (verifyToken && mode === 'subscribe' && token === verifyToken) {
      res.status(200).send(challenge);
    } else {
      res.status(403).send('Forbidden');
    }
  }
);

// ── POST /whatsapp/send ── (envoyer un message WhatsApp via le backend)
router.post(
  '/send',
  requirePerm('whatsapp:edit'),
  validate({ body: { to: 'string', type: 'string', content: 'string' } }),
  async (req, res) => {
    const { to, type = 'text', content } = req.body;
    const pharmacyId = req.user.pharmacyId;
    const userId = req.user.id;

    // Trouver ou créer la conversation
    let convId;
    const { rows: convRows } = await query(
      `SELECT id FROM whatsapp_conversations WHERE contact_phone = $1 AND pharmacy_id = $2`,
      [to, pharmacyId]
    );
    if (convRows.length > 0) {
      convId = convRows[0].id;
    } else {
      const { rows: newConv } = await query(
        `INSERT INTO whatsapp_conversations (id, pharmacy_id, contact_phone, contact_name, status, unread_count, created_at, updated_at)
         VALUES ($1, $2, $3, $4, 'active', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
         RETURNING id`,
        [uuid(), pharmacyId, to, 'Contact WhatsApp']
      );
      convId = newConv[0].id;
    }

    // Appel RÉEL à l'API Meta Cloud (le jeton reste côté serveur).
    // Sans WHATSAPP_ACCESS_TOKEN/WHATSAPP_PHONE_NUMBER_ID configurés, le
    // message est enregistré avec status 'pending' et la réponse indique
    // honnêtement la non-livraison (aucun faux succès).
    const token = process.env.WHATSAPP_ACCESS_TOKEN || '';
    const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID || '';
    let waMessageId = null;
    let delivered = false;
    let providerError = null;

    if (type === 'text' && token && phoneId) {
      try {
        const resp = await fetch(`https://graph.facebook.com/v18.0/${phoneId}/messages`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            messaging_product: 'whatsapp',
            to: String(to).replace(/[^\d]/g, ''),
            type: 'text',
            text: { body: content },
          }),
        });
        const data = await resp.json().catch(() => ({}));
        if (resp.ok) {
          delivered = true;
          waMessageId = data?.messages?.[0]?.id ?? null;
        } else {
          providerError = data?.error?.message ?? `HTTP ${resp.status}`;
        }
      } catch (e) {
        providerError = e.message;
      }
    } else if (!token || !phoneId) {
      providerError = 'WhatsApp non configuré côté serveur (WHATSAPP_ACCESS_TOKEN / WHATSAPP_PHONE_NUMBER_ID)';
    }

    // Insérer le message sortant avec le statut RÉEL.
    const { rows: msgRows } = await query(
      `INSERT INTO whatsapp_messages (id, conversation_id, wa_message_id, from_me, content, message_type, status, timestamp, created_at)
       VALUES ($1, $2, $3, 1, $4, $5, $6, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
       RETURNING id`,
      [uuid(), convId, waMessageId, content, type, delivered ? 'sent' : 'pending']
    );

    // Mettre à jour la conversation
    await query(
      `UPDATE whatsapp_conversations SET last_message = $1, last_message_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
      [content, convId]
    );

    await auditLog({
      pharmacyId, userId, action: 'send', module: 'whatsapp',
      entity: 'message', entityId: msgRows[0].id,
      newValues: { to, type, content },
    });

    res.status(201).json({
      success: true,
      data: {
        id: msgRows[0].id,
        conversationId: convId,
        to,
        type,
        content,
        status: delivered ? 'sent' : 'pending',
        delivered,
        providerError,
      },
    });
  }
);
