with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\core\l10n\strings.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the French section end (before 'ar': {)
# The French section ends with:
#       'reorderPlan': 'Plan de réapprovisionnement intelligent',
#       'reorderSubtitle': 'Suggestions IA pour optimiser vos commandes',
#     },

old = """      'reorderPlan': 'Plan de réapprovisionnement intelligent',
      'reorderSubtitle': 'Suggestions IA pour optimiser vos commandes',
    },"""

new = """      'reorderPlan': 'Plan de réapprovisionnement intelligent',
      'reorderSubtitle': 'Suggestions IA pour optimiser vos commandes',
      'whatsappCenter': 'Centre WhatsApp',
      'whatsappCenterSub': 'Centre communication WhatsApp',
      'conversations': 'Conversations',
      'templates': 'Templates',
      'campaigns': 'Campagnes',
      'whatsappSettings': 'Paramètres WhatsApp',
      'noConversations': 'Aucune conversation',
      'addFirstConversation': 'Ajoutez votre première conversation',
      'newConversation': 'Nouvelle conversation',
      'editConversation': 'Modifier conversation',
      'connectionType': 'Type connexion',
      'enabled': 'Activé',
      'disabled': 'Désactivé',
      'lastSync': 'Dernière sync',
      'clearFilters': 'Réinitialiser filtres',
      'import': 'Importer',
      'export': 'Exporter',
      'superAdminCRM': 'Super Admin CRM',
      'superAdminPortal': 'Portail Super Admin',
      'superAdminHint': 'Gestion commerciale PHARMA+',
      'globalStats': 'Statistiques globales',
      'totalPharmacies': 'Pharmacies totales',
      'activePharmacies': 'Pharmacies actives',
      'totalUsers': 'Utilisateurs totaux',
      'totalSales': 'Ventes totales',
      'totalRevenue': 'Chiffre d\'affaires total',
      'newPharmacy': 'Nouvelle pharmacie',
      'newProspect': 'Nouveau prospect',
      'newInvoice': 'Nouvelle facture',
      'newTicket': 'Nouveau ticket',
      'prospects': 'Prospects',
      'invoices': 'Factures',
      'tickets': 'Tickets support',
      'analytics': 'Analytiques',
      'revenue': 'Chiffre d\'affaires',
      'conversionRate': 'Taux de conversion',
      'churnRate': 'Taux de churn',
      'mrr': 'MRR',
      'arr': 'ARR',
      'licenseManagement': 'Gestion licences',
      'billing': 'Facturation',
      'supportTickets': 'Tickets support',
      'supportResponseTime': 'Temps réponse support',
      'customerSatisfaction': 'Satisfaction client',
    },"""

with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\core\l10n\strings.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if old in content:
    content = content.replace(old, new)
    with open('C:\\Users\\Merouan\\Documents\\Default Project\\pharma-maroc-gold\\frontend\\lib\\core\\l10n\\strings.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('REPLACED')
else:
    print('NOT FOUND')
    # Debug: find the exact text
    idx = content.find('reorderPlan')
    if idx >= 0:
        print('Found at:', idx)
        print(content[idx:idx+500])