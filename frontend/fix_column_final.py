with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# The pattern to find and replace
old = """            )),\n          ],\n          const SizedBox(height: 16),\n          Row("""

new = """            )),\n          ],\n          const SizedBox(height: 16),\n          Row("""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('REPLACED')
else:
    print('NOT FOUND')
    # Try to find the exact text
    idx = content.find('            )),\n          ],\n')
    if idx >= 0:
        print('Found partial at:', idx)
        print(repr(content[idx:idx+200]))