with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\super_admin_crm_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the exact pattern
idx = content.find('          ),\n        ),\n      );\n    );')
if idx >= 0:
    print('Found at:', idx)
    print(repr(content[idx:idx+100]))
else:
    print('Not found')
    # Try variations
    idx2 = content.find('      );\n    );')
    if idx2 >= 0:
        print('Found variant at:', idx2)
        print(repr(content[idx2:idx2+100]))