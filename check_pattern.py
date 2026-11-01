with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the exact pattern
idx = content.find('class _AddSupplierDialog')
if idx >= 0:
    print('Found at:', idx)
    context = content[idx-300:idx+50]
    print('Context:')
    for i, line in enumerate(context.split('\n')):
        print(f'{i:3}: {repr(line)}')

# Try to find the exact pattern
idx2 = content.find('        ]),\n      ),\n    )\n  );\n  }\n}\n\nclass _AddSupplierDialog')
if idx2 >= 0:
    print('Found exact pattern at:', idx2)
else:
    print('Pattern not found')
    # Search for similar
    idx3 = content.find('      ),\n    ),\n    );\n  }\n}\n\nclass _AddSupplierDialog')
    if idx3 >= 0:
        print('Found alt at:', idx3)
        print(repr(content[idx3:idx3+100]))