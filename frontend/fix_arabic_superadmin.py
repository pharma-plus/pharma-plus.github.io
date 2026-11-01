with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\core\l10n\strings.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Arabic section - add SuperAdmin CRM strings before the closing brace
old = """      'connectionType': 'نوع الاتصال',
      'enabled': 'مفعل',
      'disabled': 'معطل',
      'lastSync': 'آخر مزامنة',
      'clearFilters': 'مسح الفلاتر',
      'import': 'استيراد',
      'export': 'تصدير',
    },"""

new = """      'connectionType': 'نوع الاتصال',
      'enabled': 'مفعل',
      'disabled': 'معطل',
      'lastSync': 'آخر مزامنة',
      'clearFilters': 'مسح الفلاتر',
      'import': 'استيراد',
      'export': 'تصدير',
      'superAdminCRM': 'سوبر أدمن CRM',
      'superAdminPortal': 'بوابة السوبر أدمن',
      'superAdminHint': 'إدارة تجارية PHARMA+',
      'globalStats': 'إحصائيات عامة',
      'totalPharmacies': 'الصيدليات الكلية',
      'activePharmacies': 'صيدليات نشطة',
      'totalUsers': 'إجمالي المستخدمين',
      'totalSales': 'إجمالي المبيعات',
      'totalRevenue': 'إجمالي chiffre d\'affaires',
      'newPharmacy': 'صيدلية جديدة',
      'newProspect': ' Prospect جديد',
      'newInvoice': 'فاتورة جديدة',
      'newTicket': 'تذكرة جديدة',
      'prospects': 'العملاء المحتملون',
      'invoices': 'الفواتير',
      'tickets': 'تذاكر الدعم',
      'analytics': 'التحليلات',
      'revenue': 'الإيرادات',
      'conversionRate': 'معدل التحويل',
      'churnRate': 'معدل المغادرة',
      'mrr': 'MRR',
      'arr': 'ARR',
      'licenseManagement': 'إدارة التراخيص',
      'billing': 'الفوترة',
      'supportTickets': 'تذاكر الدعم',
      'supportResponseTime': 'وقت استجابة الدعم',
      'customerSatisfaction': 'رضا العملاء',
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
    idx = content.find('connectionType')
    if idx >= 0:
        print('Found at:', idx)
        print(content[idx:idx+500])