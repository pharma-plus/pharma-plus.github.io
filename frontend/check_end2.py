with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Check the exact end of the file
idx = content.rfind('        ],\n      ),\n  );\n}')
if idx >= 0:
    print('Found pattern at:', idx)
    print(repr(content[idx:idx+100]))
else:
    print('Pattern not found')
    
# Find the last few lines
lines = content.split('\n')
for i, line in enumerate(lines[-15:], len(lines)-14):
    print(f'{i}: {repr(line)}')