with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the end of the file
idx = content.rfind('],')
if idx >= 0:
    print('Found ], at:', idx)
    print(content[max(0,idx-100):idx+100])

# Find the last few lines
lines = content.split('\n')
for i, line in enumerate(lines[-20:], len(lines)-19):
    print(f'{i}: {repr(line)}')