with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the exact bytes around the issue
idx = content.find('const SizedBox(height: 16)')
print('Found at:', idx)
print(repr(content[idx-50:idx+200]))