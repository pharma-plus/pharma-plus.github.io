with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# The issue: line 432 has `          ],` which closes Column children
# Then lines 433-441 are SizedBox and Row (now inside Column)
# Then line 442 has `        ],` which tries to close again
# We need to REMOVE the `],` at line 432

old = """            )),\n          ],\n          const SizedBox(height: 16),"""

new = """            )),\n          const SizedBox(height: 16),"""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('REPLACED')
else:
    print('NOT FOUND')