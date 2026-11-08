import 'package:flutter/material.dart';

/// PHARMA+ - SUPER ADMIN : GESTION WHATSAPP
///
/// PAGE HONNÊTE « NON CONFIGURÉE »
///
/// Les routes Edge Function /whatsapp/*, /chatbot/* n'existent pas encore
/// côté backend (projet Supabase lwepnnecnrqdzadesyqo, fonction pharma-api).
/// Cette page ne simule aucun envoi et n'expose aucun token.
///
/// Quand les routes seront déployées (autorisation propriétaire requise),
/// cette page pourra être remplacée par une vraie gestion WhatsApp :
/// configuration globale, gestion des connexions, modèles de messages,
/// historiques, statuts d'envoi, journal d'activité.
class WhatsAppManagementPage extends StatelessWidget {
  const WhatsAppManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp — Super Admin'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.amber),
              SizedBox(height: 20),
              Text(
                'WhatsApp — Non configuré',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'La gestion WhatsApp du Super Admin n’est pas encore '
                'disponible. Aucune route Edge Function /whatsapp/*, '
                '/chatbot/* n’est déployée sur le projet Supabase '
                'lwepnnecnrqdzadesyqo (fonction pharma-api).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              SizedBox(height: 24),
              Text(
                'Étapes pour activer (autorisation propriétaire requise) :',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              _etape('1. Créer les routes Edge /whatsapp/* et /chatbot/*'),
              _etape('2. Déployer l’Edge Function pharma-api (workflow manuel)'),
              _etape('3. Remplacer cette page par une vraie gestion WhatsApp'),
              SizedBox(height: 24),
              Text(
                'Aucune donnée WhatsApp n’est exposée, aucun token n’est stocké '
                'dans cette page.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _etape(String texte) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          texte,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
      );
}
