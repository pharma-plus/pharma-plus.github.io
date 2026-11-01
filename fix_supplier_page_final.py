with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the _SupplierCard build method closing brackets - lines 341-344
old = """        ]),
      ),
    )
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
    # Show context
    idx = content.find('class _AddSupplierDialog')
    if idx >= 0:
        print('Found at:', idx)
        print(repr(content[idx-200:idx+50]))

with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')