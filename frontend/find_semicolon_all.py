with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\super_admin_crm_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find all occurrences of ');\n  );'
import re
for m in re.finditer(r'\);', content):
    start = max(0, m.start()-30)
    end = min(len(content), m.end()+30)
    print(f'Found at {m.start()}: {repr(content[start:end])}')
    print('---')