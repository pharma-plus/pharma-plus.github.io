with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\core\l10n\strings.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = """      'whatsappCenter': 'WhatsApp Center',
      'whatsappCenterSub': 'WhatsApp Communication Center',
      'conversations': 'Conversations',
      'templates': 'Templates',
      'campaigns': 'Campaigns',
      'whatsappSettings': 'WhatsApp Settings',
      'noConversations': 'No conversations',
      'addFirstConversation': 'Add your first conversation',
      'newConversation': 'New conversation',
      'editConversation': 'Edit conversation',
      'connectionType': 'Connection Type',
      'enabled': 'Enabled',
      'disabled': 'Disabled',
      'lastSync': 'Last Sync',
      'clearFilters': 'Clear Filters',
      'import': 'Import',
      'export': 'Export',
    },"""

new = """      'whatsappCenter': 'WhatsApp Center',
      'whatsappCenterSub': 'WhatsApp Communication Center',
      'conversations': 'Conversations',
      'templates': 'Templates',
      'campaigns': 'Campaigns',
      'whatsappSettings': 'WhatsApp Settings',
      'noConversations': 'No conversations',
      'addFirstConversation': 'Add your first conversation',
      'newConversation': 'New conversation',
      'editConversation': 'Edit conversation',
      'connectionType': 'Connection Type',
      'enabled': 'Enabled',
      'disabled': 'Disabled',
      'lastSync': 'Last Sync',
      'clearFilters': 'Clear Filters',
      'import': 'Import',
      'export': 'Export',
      'superAdminCRM': 'Super Admin CRM',
      'superAdminPortal': 'Super Admin Portal',
      'superAdminHint': 'PHARMA+ Commercial Management',
      'globalStats': 'Global Statistics',
      'totalPharmacies': 'Total Pharmacies',
      'activePharmacies': 'Active Pharmacies',
      'totalUsers': 'Total Users',
      'totalSales': 'Total Sales',
      'totalRevenue': 'Total Revenue',
      'newPharmacy': 'New Pharmacy',
      'newProspect': 'New Prospect',
      'newInvoice': 'New Invoice',
      'newTicket': 'New Ticket',
      'prospects': 'Prospects',
      'invoices': 'Invoices',
      'tickets': 'Support Tickets',
      'analytics': 'Analytics',
      'revenue': 'Revenue',
      'conversionRate': 'Conversion Rate',
      'churnRate': 'Churn Rate',
      'mrr': 'MRR',
      'arr': 'ARR',
      'licenseManagement': 'License Management',
      'billing': 'Billing',
      'supportTickets': 'Support Tickets',
      'supportResponseTime': 'Support Response Time',
      'customerSatisfaction': 'Customer Satisfaction',
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