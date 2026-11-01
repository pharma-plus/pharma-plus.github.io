with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\super_admin_crm_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the _ProspectCard end
idx = content.find('      ]);\n    );\n  }\n}\n\nclass _InvoiceCard')
if idx >= 0:
    print('Found at:', idx)
    print(repr(content[idx:idx+100]))
else:
    print('Not found')