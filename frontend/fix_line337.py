with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\super_admin_crm_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = """          ),\n        ),\n      );\n    );"""

new = """          ),\n        ),\n      ),\n    );"""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\super_admin_crm_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('REPLACED')
else:
    print('NOT FOUND')