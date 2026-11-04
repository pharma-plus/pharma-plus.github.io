import { query } from '../../db/pool.js';
import { uuid } from '../../utils/crypto.js';

/**
 * Service Chatbot PHARMA+
 * Répond automatiquement aux messages entrants basés sur des mots-clés/intents.
 * Supporte le transfert vers un opérateur humain.
 */

const INTENTS = [
  {
    id: 'horaires',
    keywords: ['horaire', 'heure', 'ouvert', 'fermé', 'ouverture', 'fermeture'],
    response: 'Notre officine est ouverte du lundi au samedi de 8h30 à 19h30. Fermé le dimanche et jours fériés.',
  },
  {
    id: 'localisation',
    keywords: ['adresse', 'où', 'situer', 'localisation', 'trouver', 'venue', 'venir'],
    response: 'PHARMA+ est située au centre-ville. Appelez-nous pour plus de précisions sur l’accès et le stationnement.',
  },
  {
    id: 'contact',
    keywords: ['téléphone', 'tel', 'contacter', 'appeler', 'numéro', 'contact'],
    response: 'Vous pouvez nous joindre par téléphone ou par WhatsApp. Notre équipe vous répondra dans les plus brefs délais.',
  },
  {
    id: 'ordonnance',
    keywords: ['ordonnance', 'prescription', 'régler', 'délivrer', 'médicament'],
    response: 'Nous acceptons les ordonnances médicales. Vous pouvez nous les envoyer par WhatsApp ou les apporter à l’officine.',
  },
  {
    id: 'prix',
    keywords: ['prix', 'tarif', 'coût', 'combien', 'devis', 'estimation'],
    response: 'Nos prix sont affichés en officine. Pour un devis précis, envoyez-nous la liste des produits recherchés.',
  },
  {
    id: 'urgence',
    keywords: ['urgence', 'urgent', 'nuit', 'dimanche', 'garde', 'pharmacie de garde'],
    response: 'En cas d’urgence, appelez le 15 (SAMU) ou le 17 (police secours). Pour une pharmacie de garde, consultez l’affichage devant l’officine ou appelez le 3237.',
  },
  {
    id: 'transfert',
    keywords: ['humain', 'opérateur', 'personne', 'conseiller', 'pharmacien', 'parler à'],
    response: null, // spécial : transfert vers humain
  },
];

function matchIntent(message) {
  const lower = message.toLowerCase();
  for (const intent of INTENTS) {
    for (const kw of intent.keywords) {
      if (lower.includes(kw.toLowerCase())) {
        return intent;
      }
    }
  }
  return null;
}

export const chatbotService = {
  /**
   * Traite un message entrant et génère une réponse automatique.
   * Retourne { response, transferToHuman }.
   */
  async processMessage(conversationId, message, pharmacyId) {
    const intent = matchIntent(message);

    if (!intent) {
      return {
        response: "Je n'ai pas compris votre demande. Pouvez-vous reformuler ou écrire 'humain' pour parler à un opérateur ?",
        transferToHuman: false,
      };
    }

    if (intent.id === 'transfert') {
      return {
        response: 'Je vous mets en relation avec un opérateur humain. Veuillez patienter...',
        transferToHuman: true,
      };
    }

    return {
      response: intent.response,
      transferToHuman: false,
    };
  },

  /**
   * Transfère une conversation vers un opérateur humain.
   */
  async transferToHuman(conversationId, pharmacyId, userId) {
    await query(
      `UPDATE whatsapp_conversations SET assigned_to = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
      [userId, conversationId]
    );
    return { success: true, message: 'Conversation transférée vers un opérateur humain' };
  },
};
