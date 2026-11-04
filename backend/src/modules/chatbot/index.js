import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { chatbotService } from './service.js';

const router = Router();
router.use(requireAuth);

// ── POST /chatbot/message ── (envoyer un message au chatbot)
router.post(
  '/message',
  requirePerm('whatsapp:view'),
  validate({ body: { conversationId: 'string', message: 'string' } }),
  wrap(async (req, res) => {
    const { conversationId, message } = req.body;
    const pharmacyId = req.user.pharmacyId;

    const result = await chatbotService.processMessage(conversationId, message, pharmacyId);

    return ok(res, {
      conversationId,
      response: result.response,
      transferToHuman: result.transferToHuman,
    });
  })
);

// ── POST /chatbot/transfer ── (transférer vers un opérateur humain)
router.post(
  '/transfer',
  requirePerm('whatsapp:edit'),
  validate({ body: { conversationId: 'string' } }),
  wrap(async (req, res) => {
    const { conversationId } = req.body;
    const pharmacyId = req.user.pharmacyId;
    const userId = req.user.id;

    const result = await chatbotService.transferToHuman(conversationId, pharmacyId, userId);

    return ok(res, result);
  })
);

export const chatbotRouter = router;
