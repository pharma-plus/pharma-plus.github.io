with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# The exact pattern from the file
old = """        ]),
      ),
    ),
    );
  }
}

class _AddSupplierDialog"""

new = """        ]),
      ),
    ],
    ),
    );
  }
}

class _AddSupplierDialog"""

if old in content:
    content = content.replace(old, new)
    print('Fixed!')
else:
    print('NOT FOUND')
    # Show exact bytes
    idx = content.find('class _AddSupplierDialog')
    if idx >= 0:
        context = content[idx-300:idx]
        for i, line in enumerate(context.split('\n')[-15:]):
            print(f'{i:3}: {repr(line)}')

with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')