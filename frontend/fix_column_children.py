with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# The issue is that `],` at line 432 closes Column children, then SizedBox and Row are outside
# We need to move SizedBox and Row inside the Column children
# Find: "          ],\n        const SizedBox(height: 16),\n        Row("
# Replace with: "          ],\n          const SizedBox(height: 16),\n          Row("

old = """          ],
        const SizedBox(height: 16),
        Row("""

new = """          ],
          const SizedBox(height: 16),
          Row("""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('REPLACED')
else:
    print('NOT FOUND')