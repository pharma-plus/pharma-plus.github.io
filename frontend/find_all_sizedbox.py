with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find all occurrences
import re
for m in re.finditer(r'const SizedBox\(height: 16\)', content):
    print(f'Found at {m.start()}: {repr(content[max(0,m.start()-100):m.start()+200])}')
    print('---')