with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the exact pattern
idx = content.find('class _AddSupplierDialog')
if idx >= 0:
    print('Found at:', idx)
    print(repr(content[idx-300:idx+50]))

# Fix the pattern
old = """        ]),
      ),
    ),
    );
  }
}

class _AddSupplierDialog"""

new = """        ]),
      ),
    ),
    );
  }
}

class _AddSupplierDialog"""

if old in content:
    content = content.replace(old, new)
    print('Fixed _SupplierCard closing brackets')
else:
    print('NOT FOUND - SupplierCard pattern')
    # Try alternative pattern
    old2 = """        ]),\n      ),\n    ),\n    );\n  }\n}\n\nclass _AddSupplierDialog"""
    if old2 in content:
        content = content.replace(old2, new)
        print('Fixed with alt pattern')
    else:
        print('Alt pattern also not found')

with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')