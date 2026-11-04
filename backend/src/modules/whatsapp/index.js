import { Router } from 'express';
import { AppError } from '../../utils/errors.js';
import { requirePerm } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { query } from '../../db/pool.js';

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
    res.json({
      success: true,
      data: WHATSAPP_CONFIG,
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
