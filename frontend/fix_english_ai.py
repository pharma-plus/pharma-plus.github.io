with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\core\l10n\strings.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = """      'reorderPlan': 'Smart reorder plan',
      'reorderSubtitle': 'AI suggestions to optimize your orders',
    },"""

new = """      'reorderPlan': 'Smart reorder plan',
      'reorderSubtitle': 'AI suggestions to optimize your orders',
      'pharmaAi': 'PHARMA AI',
      'aiAssistant': 'Smart assistant',
      'aiAnalytics': 'Analytics & alerts',
      'aiProductivity': 'Your sales and stock analyzed in real time.',
      'aiRequests7d': 'AI requests (7d)',
      'reorderPlan': 'Reorder plan',
      'reorderSubtitle': 'Smart reorder plan',
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