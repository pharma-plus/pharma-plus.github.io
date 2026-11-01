with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\core\l10n\strings.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = """      'address': 'العنوان',
      'reorderPlan': 'خطة إعادة التوريد',
      'reorderSubtitle': 'خطة إعادة التوريد الذكية',
      'salesAnalysis': 'تحليل المبيعات',
      'suggestedQty': 'اطلب',
      'estimatedCost': 'التكلفة التقديرية',
      'pOut': 'نفاد',
      'pCritical': 'حرج',
      'pHigh': 'عالية',
      'pNormal': 'عادي',
      'daysCover': 'التغطية',
      'totalEstCost': 'إجمالي التكلفة التقديرية',
      'productsToOrder': 'منتجات للطلب',
      'forecast7d': 'توقعات 7 أيام',
      'peakHours': 'ساعات الذروة',
      'topCategories': 'أفضل الفئات',
      'margin': 'الهامش',
      'vsPrevPeriod': 'مقارنة بالفترة السابقة',
      'reorderPlan': 'خطة إعادة التوريد',
      'reorderHistory': 'تاريخ إعادة التوريد',
      'insights': 'رؤى',
      'reorderSubtitle': 'خطة إعادة التوريد الذكية',
      'productsToOrder': 'منتجات للطلب',
      'totalEstCost': 'إجمالي التكلفة التقديرية',
      'suggestedQty': 'كمية مقترحة',
      'estimatedCost': 'التكلفة التقديرية',
      'stock': 'المخزون',
      'daysCover': 'التغطية (أيام)',
      'actions': 'إجراءات',
      'suppliers': 'الموردين',
      'bySupplier': 'حسب المورد',
      'priority': 'الأولوية',
      'noDataFiltered': 'لا توجد بيانات لهذا الفلتر',
      'reorderPlan': 'خطة إعادة التوريد الذكية',
      'reorderSubtitle': 'اقتراحات الذكاء الاصطناعي لتحسين طلباتك',
    },"""

new = """      'address': 'العنوان',
      'reorderPlan': 'خطة إعادة التوريد',
      'reorderSubtitle': 'خطة إعادة التوريد الذكية',
      'salesAnalysis': 'تحليل المبيعات',
      'suggestedQty': 'اطلب',
      'estimatedCost': 'التكلفة التقديرية',
      'pOut': 'نفاد',
      'pCritical': 'حرج',
      'pHigh': 'عالية',
      'pNormal': 'عادي',
      'daysCover': 'التغطية',
      'totalEstCost': 'إجمالي التكلفة التقديرية',
      'productsToOrder': 'منتجات للطلب',
      'forecast7d': 'توقعات 7 أيام',
      'peakHours': 'ساعات الذروة',
      'topCategories': 'أفضل الفئات',
      'margin': 'الهامش',
      'vsPrevPeriod': 'مقارنة بالفترة السابقة',
      'reorderPlan': 'خطة إعادة التوريد',
      'reorderHistory': 'تاريخ إعادة التوريد',
      'insights': 'رؤى',
      'reorderSubtitle': 'خطة إعادة التوريد الذكية',
      'productsToOrder': 'منتجات للطلب',
      'totalEstCost': 'إجمالي التكلفة التقديرية',
      'suggestedQty': 'كمية مقترحة',
      'estimatedCost': 'التكلفة التقديرية',
      'stock': 'المخزون',
      'daysCover': 'التغطية (أيام)',
      'actions': 'إجراءات',
      'suppliers': 'الموردين',
      'bySupplier': 'حسب المورد',
      'priority': 'الأولوية',
      'noDataFiltered': 'لا توجد بيانات لهذا الفلتر',
      'reorderPlan': 'خطة إعادة التوريد الذكية',
      'reorderSubtitle': 'اقتراحات الذكاء الاصطناعي لتحسين طلباتك',
      'pharmaAi': 'PHARMA AI',
      'aiAssistant': 'المساعد الذكي',
      'aiAnalytics': 'تحليلات وتنبيهات',
      'aiProductivity': 'مبيعاتك ومخزونك محللان لحظياً.',
      'aiRequests7d': 'طلبات IA (7j)',
      'reorderPlan': 'خطة إعادة التوريد',
      'reorderSubtitle': 'خطة إعادة التوريد الذكية',
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
    idx = content.find('reorderPlan')
    if idx >= 0:
        print('Found at:', idx)
        print(content[idx:idx+300])