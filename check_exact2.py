with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the exact bytes around the issue
idx = content.find('class _AddSupplierDialog')
if idx >= 0:
    before = content[idx-300:idx]
    print('Raw bytes:')
    for i, ch in enumerate(before[-200:]):
        if ch in '\n\r\t':
            print(f'  [{i}] = {repr(ch)}')
        else:
            print(f'  [{i}] = {ch}')

# Find the exact problematic lines
lines = content[:idx].split('\n')
for i, line in enumerate(lines[-15:], len(lines)-14):
    print(f'{i+1:4}: {repr(line)}')